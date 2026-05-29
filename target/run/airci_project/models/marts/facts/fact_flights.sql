
  
    
    

    create  table
      "dev"."main_marts"."fact_flights__dbt_tmp"
  
    as (
      

-- ================================================================
-- FACT_FLIGHTS
-- Source  : Business Vault uniquement
--   bridge_flight_booking → clés pré-calculées
--   pit_flight            → hash keys actifs par snapshot
--   satellites            → attributs via hash keys du PIT
-- Grain   : 1 ligne par vol
-- ================================================================

WITH revenue_per_flight AS (
    SELECT
        bfb.flight_hk,
        COUNT(*)                                            AS seats_sold,
        SUM(sb.ticket_price_usd)                           AS ticket_revenue_usd,
        SUM(sb.ancillary_revenue_usd)                      AS ancillary_revenue_usd,
        SUM(sb.ticket_price_usd
            + sb.ancillary_revenue_usd)                    AS total_revenue_usd,
        SUM(CASE WHEN sb.ancillary_revenue_usd > 0
                 THEN 1 ELSE 0 END)                        AS bookings_with_ancillary,
        SUM(CASE WHEN UPPER(sb.booking_status) = 'NO SHOW'
                 THEN 1 ELSE 0 END)                        AS no_show_count
    FROM "dev"."main_vault"."bridge_flight_booking"     bfb
    -- Satellite booking via son hash key direct (pas de PIT sur hub_booking)
    JOIN "dev"."main_vault"."sat_booking_details"       sb
        ON  sb.booking_hk  = bfb.booking_hk
        AND sb.is_current  = 1
    WHERE UPPER(sb.booking_status) IN ('CONFIRMED', 'FLOWN')
      AND bfb.booking_hk IS NOT NULL
    GROUP BY bfb.flight_hk
)

SELECT
    -- Clés métier (depuis bridge)
    bfb.flight_id,
    bfb.flight_hk,
    bfb.route_id,
    bfb.route_hk,

    -- Attributs opérationnels (via PIT → sat_flight_operations)
    sfo.aircraft_type,
    sfo.flight_number,
    sfo.flight_status,
    sfo.delay_min,
    sfo.seat_capacity,
    sfo.scheduled_departure,
    sfo.actual_departure,
    sfo.scheduled_arrival,
    sfo.actual_arrival,
    CAST(sfo.scheduled_departure AS DATE)                   AS flight_date,

    -- Attributs route (via PIT → sat_route_details)
    srd.route_label,
    srd.route_type,
    srd.origin_airport_code,
    srd.destination_airport_code,
    srd.distance_km,

    -- Métriques commerciales
    COALESCE(r.seats_sold, 0)                               AS seats_sold,
    COALESCE(r.ticket_revenue_usd, 0)                       AS ticket_revenue_usd,
    COALESCE(r.ancillary_revenue_usd, 0)                    AS ancillary_revenue_usd,
    COALESCE(r.total_revenue_usd, 0)                        AS total_revenue_usd,
    COALESCE(r.bookings_with_ancillary, 0)                  AS bookings_with_ancillary,
    COALESCE(r.no_show_count, 0)                            AS no_show_count,

    -- Load factor
    CASE WHEN sfo.seat_capacity > 0
         THEN ROUND(COALESCE(r.seats_sold, 0)::DOUBLE
                  / sfo.seat_capacity, 4)
         ELSE NULL
    END                                                     AS load_factor,

    -- Coûts (via PIT → sat_flight_costs)
    COALESCE(sfc.total_cost_usd, 0)                         AS total_cost_usd,
    sfc.fuel_cost_usd,
    sfc.crew_cost_usd,
    sfc.airport_handling_usd,
    sfc.maintenance_usd,
    sfc.cost_per_seat_usd,
    

    -- Marge
    COALESCE(r.total_revenue_usd, 0)
        - COALESCE(sfc.total_cost_usd, 0)                  AS flight_margin_usd,

    -- Yield
    CASE WHEN COALESCE(r.seats_sold, 0) > 0
         THEN ROUND(COALESCE(r.ticket_revenue_usd, 0)
                  / r.seats_sold, 2)
         ELSE NULL
    END                                                     AS yield_usd,

    -- Sentiment agrégé (via PIT → sat_flight_sentiment)
    sfs.avg_sentiment_score,
    sfs.avg_rating,
    sfs.total_signals,

    -- Flags
    CASE WHEN sfo.flight_status = 'DELAYED'   THEN 1 ELSE 0 END AS is_delayed,
    CASE WHEN sfo.flight_status = 'CANCELLED' THEN 1 ELSE 0 END AS is_cancelled,
    CASE WHEN sfo.flight_status = 'ON TIME'   THEN 1 ELSE 0 END AS is_on_time,
    CASE WHEN sfo.delay_min > 60              THEN 1 ELSE 0 END AS is_severely_delayed,

    -- PIT snapshot date (traçabilité)
    pit.snapshot_date

FROM (
    -- Dédupliqué : 1 ligne par vol dans le bridge
    SELECT DISTINCT
        flight_id, flight_hk, route_id, route_hk
    FROM "dev"."main_vault"."bridge_flight_booking"
) bfb

-- PIT flight : hash keys actifs au dernier snapshot
JOIN "dev"."main_vault"."pit_flight"                pit
    ON  pit.flight_hk     = bfb.flight_hk
    AND pit.snapshot_date = (
        SELECT MAX(p2.snapshot_date)
        FROM "dev"."main_vault"."pit_flight" p2
        WHERE p2.flight_hk = bfb.flight_hk
    )

-- Satellite opérations via PIT
LEFT JOIN "dev"."main_vault"."sat_flight_operations" sfo
    ON  sfo.sat_flight_operations_hk = pit.sat_flight_operations_hk
    AND pit.sat_flight_operations_hk != 'GHOST'

-- Satellite coûts via PIT
LEFT JOIN "dev"."main_vault"."sat_flight_costs"      sfc
    ON  sfc.sat_flight_costs_hk = pit.sat_flight_costs_hk
    AND pit.sat_flight_costs_hk != 'GHOST'

-- Satellite route via PIT route
LEFT JOIN "dev"."main_vault"."pit_route"             pit_r
    ON  pit_r.route_hk    = bfb.route_hk
    AND pit_r.snapshot_date = (
        SELECT MAX(p3.snapshot_date)
        FROM "dev"."main_vault"."pit_route" p3
        WHERE p3.route_hk = bfb.route_hk
    )
LEFT JOIN "dev"."main_vault"."sat_route_details"     srd
    ON  srd.sat_route_details_hk = pit_r.sat_route_details_hk
    AND pit_r.sat_route_details_hk != 'GHOST'

-- Sentiment agrégé par vol (depuis sat_flight_sentiment via PIT)
LEFT JOIN (
    SELECT
        flight_hk,
        ROUND(AVG(sentiment_score), 3)  AS avg_sentiment_score,
        ROUND(AVG(rating), 2)           AS avg_rating,
        COUNT(*)                        AS total_signals
    FROM "dev"."main_vault"."sat_flight_sentiment"
    WHERE is_current = 1
    GROUP BY flight_hk
) sfs ON sfs.flight_hk = bfb.flight_hk

-- Revenus agrégés
LEFT JOIN revenue_per_flight r ON r.flight_hk = bfb.flight_hk
    );
  
  