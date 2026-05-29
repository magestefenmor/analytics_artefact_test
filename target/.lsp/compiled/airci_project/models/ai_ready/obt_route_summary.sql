

-- ================================================================
-- OBT_ROUTE_SUMMARY — Synthèse réseau par route
-- Source  : dim_routes + fact_flights (agrégé)
-- Grain   : 1 ligne par route — tout agrégé
-- Usage   : optimisation réseau, ML pricing, LLM network analysis
-- ================================================================

WITH route_agg AS (
    SELECT
        ff.route_id,
        COUNT(*)                                            AS total_flights,
        SUM(ff.seats_sold)                                  AS total_seats_sold,
        SUM(ff.seat_capacity)                               AS total_seats_available,
        SUM(ff.total_revenue_usd)                           AS total_revenue_usd,
        SUM(ff.ticket_revenue_usd)                          AS total_ticket_revenue,
        SUM(ff.ancillary_revenue_usd)                       AS total_ancillary_revenue,
        SUM(ff.total_cost_usd)                              AS total_cost_usd,
        SUM(ff.flight_margin_usd)                           AS total_margin_usd,
        AVG(ff.load_factor)                                 AS avg_load_factor,
        AVG(ff.yield_usd)                                   AS avg_yield_usd,
        AVG(ff.delay_min)                                   AS avg_delay_min,
        SUM(ff.is_on_time)                                  AS on_time_flights,
        SUM(ff.is_delayed)                                  AS delayed_flights,
        SUM(ff.is_cancelled)                                AS cancelled_flights,
        SUM(ff.is_severely_delayed)                         AS severely_delayed_flights,
        AVG(ff.avg_sentiment_score)                         AS avg_sentiment_score,
        AVG(ff.avg_rating)                                  AS avg_rating
    FROM "dev"."main_marts"."fact_flights" ff
    GROUP BY ff.route_id
),

network AS (
    SELECT
        SUM(total_revenue_usd)                              AS network_revenue,
        SUM(total_seats_available)                          AS network_seats,
        SUM(total_cost_usd)                                 AS network_cost
    FROM route_agg
)

SELECT
    -- ── IDENTITÉ ROUTE ────────────────────────────────────────
    dr.route_id,
    dr.route_label,
    dr.route_type,
    dr.origin_airport_code,
    dr.destination_airport_code,
    dr.origin_city,
    dr.origin_country,
    dr.destination_city,
    dr.destination_country,
    dr.distance_km,
    dr.block_time_min,
    dr.has_return_route,

    -- ── VOLUME ───────────────────────────────────────────────
    COALESCE(ra.total_flights, 0)                           AS total_flights,
    COALESCE(ra.total_seats_sold, 0)                        AS total_seats_sold,
    COALESCE(ra.total_seats_available, 0)                   AS total_seats_available,

    -- ── KPIs OPÉRATIONNELS ────────────────────────────────────
    ROUND(COALESCE(ra.avg_load_factor, 0), 4)               AS avg_load_factor,
    ROUND(ra.on_time_flights::DOUBLE
        / NULLIF(ra.total_flights, 0), 4)                   AS on_time_rate,
    ROUND(ra.avg_delay_min, 1)                              AS avg_delay_min,
    ra.delayed_flights,
    ra.cancelled_flights,
    ra.severely_delayed_flights,

    -- ── KPIs FINANCIERS ──────────────────────────────────────
    COALESCE(ra.total_revenue_usd, 0)                       AS total_revenue_usd,
    COALESCE(ra.total_ticket_revenue, 0)                    AS total_ticket_revenue,
    COALESCE(ra.total_ancillary_revenue, 0)                 AS total_ancillary_revenue,
    COALESCE(ra.total_cost_usd, 0)                          AS total_cost_usd,
    COALESCE(ra.total_margin_usd, 0)                        AS total_margin_usd,
    ROUND(ra.avg_yield_usd, 2)                              AS avg_yield_usd,

    -- RASK / CASK
    ROUND(ra.total_revenue_usd
        / NULLIF(ra.total_seats_available, 0), 2)           AS rask_usd,
    ROUND(ra.total_cost_usd
        / NULLIF(ra.total_seats_available, 0), 2)           AS cask_usd,

    -- Marge %
    ROUND(ra.total_margin_usd
        / NULLIF(ra.total_cost_usd, 0) * 100, 1)            AS margin_pct,

    -- Part du réseau
    ROUND(ra.total_revenue_usd
        / NULLIF(n.network_revenue, 0), 4)                  AS revenue_share_network,
    ROUND(ra.total_seats_available
        / NULLIF(n.network_seats, 0), 4)                    AS capacity_share_network,

    -- ── SENTIMENT ────────────────────────────────────────────
    ROUND(ra.avg_sentiment_score, 3)                        AS avg_sentiment_score,
    ROUND(ra.avg_rating, 2)                                 AS avg_rating,

    -- ── LABELS ML ────────────────────────────────────────────
    CASE
        WHEN ra.total_margin_usd >= 50000
         AND ra.avg_load_factor >= 0.70  THEN 'Cash Cow'
        WHEN ra.total_margin_usd < 0
         AND ra.avg_load_factor >= 0.55  THEN 'Strategic Underperformer'
        WHEN ra.total_margin_usd < 0
         AND ra.avg_load_factor < 0.55   THEN 'Loss Maker'
        WHEN ra.avg_load_factor BETWEEN 0.40 AND 0.65
         AND ra.total_margin_usd >= -20000 THEN 'Emerging'
        ELSE 'Standard'
    END                                                     AS route_label_ontology,

    CASE
        WHEN ra.total_revenue_usd
           / NULLIF(n.network_revenue, 0) >= 0.25           THEN 'High Concentration Risk'
        ELSE 'Normal'
    END                                                     AS concentration_label,

    -- ── METADATA ─────────────────────────────────────────────
    CURRENT_TIMESTAMP                                       AS _obt_loaded_at

FROM "dev"."main_marts"."dim_routes"                dr
LEFT JOIN route_agg                         ra ON ra.route_id = dr.route_id
CROSS JOIN network                          n