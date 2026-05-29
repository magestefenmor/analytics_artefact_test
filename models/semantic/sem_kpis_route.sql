{{ config(materialized='view') }}

-- ================================================================
-- SEMANTIC — KPIs ROUTE
-- Grain   : 1 ligne par route
-- Source  : fact_flights + dim_routes
-- KPIs    : revenue total, marge, load_factor moyen, OTP, yield
-- ================================================================

WITH route_metrics AS (
    SELECT
        f.route_id,
        COUNT(*)                                        AS total_flights,
        SUM(f.seats_sold)                               AS total_seats_sold,
        SUM(f.seat_capacity)                            AS total_seats_available,
        SUM(f.total_revenue_usd)                        AS total_revenue_usd,
        SUM(f.ticket_revenue_usd)                       AS total_ticket_revenue,
        SUM(f.ancillary_revenue_usd)                    AS total_ancillary_revenue,
        SUM(f.total_cost_usd)                           AS total_cost_usd,
        SUM(f.flight_margin_usd)                        AS total_margin_usd,
        AVG(f.load_factor)                              AS avg_load_factor,
        AVG(f.yield_usd)                                AS avg_yield_usd,
        AVG(f.delay_min)                                AS avg_delay_min,
        SUM(f.is_on_time)                               AS on_time_flights,
        SUM(f.is_delayed)                               AS delayed_flights,
        SUM(f.is_cancelled)                             AS cancelled_flights
    FROM {{ ref('fact_flights') }} f
    GROUP BY f.route_id
),

-- Part de chaque route dans le réseau
network_totals AS (
    SELECT
        SUM(total_revenue_usd)                          AS network_revenue,
        SUM(total_seats_available)                      AS network_seats
    FROM route_metrics
)

SELECT
    -- Dimensions route
    r.route_id,
    r.route_label,
    r.route_type,
    r.origin_airport_code,
    r.destination_airport_code,
    r.origin_city,
    r.destination_city,
    r.distance_km,
    r.has_return_route,

    -- Métriques volume
    m.total_flights,
    m.total_seats_sold,
    m.total_seats_available,

    -- ── KPI 1 : Load Factor moyen ────────────────────────────
    ROUND(m.avg_load_factor, 4)                         AS avg_load_factor,

    -- ── KPI 2 : OTP (On-Time Performance) ────────────────────
    ROUND(m.on_time_flights::DOUBLE / NULLIF(m.total_flights, 0), 4)
                                                        AS on_time_rate,

    -- ── KPI 3 : Revenus ──────────────────────────────────────
    m.total_revenue_usd,
    m.total_ticket_revenue,
    m.total_ancillary_revenue,

    -- ── KPI 4 : Marge route ──────────────────────────────────
    m.total_cost_usd,
    m.total_margin_usd,
    ROUND(m.total_margin_usd / NULLIF(m.total_cost_usd, 0) * 100, 1)
                                                        AS margin_pct,

    -- ── KPI 5 : Yield moyen ──────────────────────────────────
    ROUND(m.avg_yield_usd, 2)                           AS avg_yield_usd,

    -- ── KPI 6 : RASK route ───────────────────────────────────
    ROUND(m.total_revenue_usd / NULLIF(m.total_seats_available, 0), 2)
                                                        AS rask_usd,

    -- ── KPI 7 : CASK route ───────────────────────────────────
    ROUND(m.total_cost_usd / NULLIF(m.total_seats_available, 0), 2)
                                                        AS cask_usd,

    -- ── KPI 8 : Part du réseau ───────────────────────────────
    ROUND(m.total_revenue_usd / NULLIF(n.network_revenue, 0), 4)
                                                        AS revenue_share_network,

    -- Opérationnel
    ROUND(m.avg_delay_min, 1)                           AS avg_delay_min,
    m.delayed_flights,
    m.cancelled_flights

FROM {{ ref('dim_routes') }}    r
LEFT JOIN route_metrics         m ON m.route_id = r.route_id
CROSS JOIN network_totals       n
