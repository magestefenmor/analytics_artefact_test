
  
    
    

    create  table
      "dev"."main_marts"."fact_bookings__dbt_tmp"
  
    as (
      

-- ================================================================
-- FACT_BOOKINGS
-- Source  : Business Vault uniquement
--   bridge_flight_booking → clés
--   pit_customer          → profil client actif
--   sat_booking_details   → attributs réservation
--   sat_flight_operations → date du vol pour lead time
-- Grain   : 1 ligne par réservation
-- ================================================================

SELECT
    -- Clés métier (depuis bridge)
    bfb.booking_id,
    bfb.booking_hk,
    bfb.customer_id,
    bfb.customer_hk,
    bfb.flight_id,
    bfb.flight_hk,
    bfb.route_id,
    bfb.route_hk,

    -- Attributs réservation (sat_booking_details via bridge)
    sb.booking_date,
    sb.booking_channel,
    sb.fare_class,
    sb.fare_family,
    sb.ticket_price_usd,
    sb.ancillary_revenue_usd,
    sb.ticket_price_usd
        + sb.ancillary_revenue_usd                         AS total_revenue_usd,
    sb.bags_count,
    sb.seat_selection_flag,
    sb.booking_status,

    -- Profil client au moment de la réservation (pit_customer)
    scp.customer_segment,
    scp.loyalty_tier,
    scp.preferred_channel,
    scp.country                                             AS customer_country,

    -- Flags
    CASE WHEN UPPER(sb.booking_status) IN ('CONFIRMED','FLOWN')
         THEN 1 ELSE 0 END                                  AS is_active_booking,
    CASE WHEN UPPER(sb.booking_status) = 'NO SHOW'
         THEN 1 ELSE 0 END                                  AS is_no_show,
    CASE WHEN UPPER(sb.booking_status) = 'CHANGED'
         THEN 1 ELSE 0 END                                  AS is_changed,
    CASE WHEN UPPER(sb.booking_status) = 'FLOWN'
         THEN 1 ELSE 0 END                                  AS is_flown,
    CASE WHEN sb.ancillary_revenue_usd > 0
         THEN 1 ELSE 0 END                                  AS has_ancillary,

    -- Lead time (jours entre réservation et vol)
    DATEDIFF('day',
        sb.booking_date,
        CAST(sfo.scheduled_departure AS DATE))              AS booking_lead_time_days,

    -- SCD2 : version du profil client utilisée
    pit_c.snapshot_date                                     AS customer_snapshot_date

FROM "dev"."main_vault"."bridge_flight_booking"         bfb

-- Satellite booking (direct — pas de PIT sur hub_booking)
JOIN "dev"."main_vault"."sat_booking_details"           sb
    ON  sb.booking_hk  = bfb.booking_hk
    AND sb.is_current  = 1

-- PIT customer : version active du profil au dernier snapshot
LEFT JOIN "dev"."main_vault"."pit_customer"             pit_c
    ON  pit_c.customer_hk    = bfb.customer_hk
    AND pit_c.snapshot_date  = (
        SELECT MAX(p.snapshot_date)
        FROM "dev"."main_vault"."pit_customer" p
        WHERE p.customer_hk = bfb.customer_hk
    )

-- Profil client via PIT
LEFT JOIN "dev"."main_vault"."sat_customer_profile"     scp
    ON  scp.sat_customer_profile_hk = pit_c.sat_customer_profile_hk
    AND pit_c.sat_customer_profile_hk != 'GHOST'

-- Date du vol pour lead time (via PIT flight)
LEFT JOIN "dev"."main_vault"."pit_flight"               pit_f
    ON  pit_f.flight_hk     = bfb.flight_hk
    AND pit_f.snapshot_date = (
        SELECT MAX(p2.snapshot_date)
        FROM "dev"."main_vault"."pit_flight" p2
        WHERE p2.flight_hk = bfb.flight_hk
    )
LEFT JOIN "dev"."main_vault"."sat_flight_operations"    sfo
    ON  sfo.sat_flight_operations_hk = pit_f.sat_flight_operations_hk
    AND pit_f.sat_flight_operations_hk != 'GHOST'

WHERE bfb.booking_id IS NOT NULL
    );
  
  