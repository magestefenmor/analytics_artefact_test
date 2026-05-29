

-- ================================================================
-- OBT_FLIGHT_FULL — One Big Table Vols
-- Source  : fact_flights + toutes les dims + sentiment
-- Grain   : 1 ligne par vol — tout dénormalisé
-- Usage   : ML (prédiction retard, yield), LLM (contexte vol),
--           Claude API (analyse fleet performance)
-- ================================================================

SELECT

    -- ── IDENTIFIANTS ─────────────────────────────────────────
    ff.flight_id,
    ff.flight_hk,
    ff.route_id,
    ff.flight_date,

    -- ── OPÉRATIONS ───────────────────────────────────────────
    ff.flight_status,
    ff.delay_min,
    ff.seat_capacity,
    ff.is_delayed,
    ff.is_cancelled,
    ff.is_on_time,
    ff.is_severely_delayed,

    -- ── ROUTE ────────────────────────────────────────────────
    ff.route_label,
    ff.route_type,
    ff.origin_airport_code,
    ff.destination_airport_code,
    ff.distance_km,
    dr.origin_city,
    dr.origin_country,
    dr.destination_city,
    dr.destination_country,
    dr.has_return_route,

    -- ── AÉROPORTS ────────────────────────────────────────────
    ao.airport_name                                         AS origin_airport_name,
    ao.region                                               AS origin_region,
    ad.airport_name                                         AS destination_airport_name,
    ad.region                                               AS destination_region,

    -- ── FLOTTE ───────────────────────────────────────────────
    ff.aircraft_type,
    da.aircraft_family,
    da.typical_seat_capacity,
    da.is_neo_engine,
    da.range_category,

    -- ── CALENDRIER ───────────────────────────────────────────
    dd.year,
    dd.month,
    dd.month_name,
    dd.day_of_week,
    dd.is_weekend,
    dd.is_holiday,
    dd.season,
    dd.quarter,

    -- ── REVENUS ──────────────────────────────────────────────
    ff.seats_sold,
    ff.ticket_revenue_usd,
    ff.ancillary_revenue_usd,
    ff.total_revenue_usd,
    ff.bookings_with_ancillary,
    ff.no_show_count,
    ff.load_factor,
    ff.yield_usd,

    -- ── COÛTS ────────────────────────────────────────────────
    ff.total_cost_usd,
    ff.fuel_cost_usd,
    ff.crew_cost_usd,
    ff.airport_handling_usd,
    ff.maintenance_usd,
    ff.cost_per_seat_usd,

    -- ── RENTABILITÉ ──────────────────────────────────────────
    ff.flight_margin_usd,
    CASE WHEN ff.seat_capacity > 0
         THEN ROUND(ff.total_revenue_usd / ff.seat_capacity, 2)
         ELSE NULL END                                      AS rask_usd,
    CASE WHEN ff.seat_capacity > 0
         THEN ROUND(ff.total_cost_usd / ff.seat_capacity, 2)
         ELSE NULL END                                      AS cask_usd,
    CASE WHEN ff.total_cost_usd > 0
         THEN ROUND(ff.flight_margin_usd / ff.total_cost_usd * 100, 1)
         ELSE NULL END                                      AS margin_pct,
    CASE WHEN ff.bookings_with_ancillary > 0 AND ff.seats_sold > 0
         THEN ROUND(ff.bookings_with_ancillary::DOUBLE
                  / ff.seats_sold, 4)
         ELSE NULL END                                      AS ancillary_attach_rate,

    -- ── SENTIMENT ────────────────────────────────────────────
    ff.avg_sentiment_score,
    ff.avg_rating,
    ff.total_signals                                        AS sentiment_signal_count,

    -- ── LABELS ANALYTIQUES (buckets pour ML) ─────────────────
    CASE
        WHEN ff.load_factor >= 0.75 THEN 'Optimal'
        WHEN ff.load_factor >= 0.60 THEN 'Acceptable'
        WHEN ff.load_factor >= 0.40 THEN 'Sous-rempli'
        ELSE 'Critique'
    END                                                     AS load_factor_label,
    CASE
        WHEN ff.flight_margin_usd >= 10000 THEN 'Très rentable'
        WHEN ff.flight_margin_usd >= 0     THEN 'Rentable'
        WHEN ff.flight_margin_usd >= -5000 THEN 'Légèrement déficitaire'
        ELSE 'Fortement déficitaire'
    END                                                     AS margin_label,
    CASE
        WHEN ff.delay_min IS NULL   THEN 'N/A'
        WHEN ff.delay_min = 0       THEN 'Aucun retard'
        WHEN ff.delay_min <= 30     THEN 'Léger'
        WHEN ff.delay_min <= 60     THEN 'Modéré'
        ELSE 'Sévère'
    END                                                     AS delay_label,

    -- ── METADATA ─────────────────────────────────────────────
    ff.snapshot_date                                        AS _vault_snapshot_date,
    CURRENT_TIMESTAMP                                       AS _obt_loaded_at

FROM "dev"."main_marts"."fact_flights"              ff

-- Dimension route
LEFT JOIN "dev"."main_marts"."dim_routes"           dr
    ON  dr.route_id      = ff.route_id

-- Dimension aéroport origine
LEFT JOIN "dev"."main_marts"."dim_airports"         ao
    ON  ao.airport_code  = ff.origin_airport_code

-- Dimension aéroport destination
LEFT JOIN "dev"."main_marts"."dim_airports"         ad
    ON  ad.airport_code  = ff.destination_airport_code

-- Dimension flotte
LEFT JOIN "dev"."main_marts"."dim_aircraft"         da
    ON  da.aircraft_type = ff.aircraft_type

-- Dimension calendrier
LEFT JOIN "dev"."main_marts"."dim_dates"            dd
    ON  dd.date_id       = ff.flight_date