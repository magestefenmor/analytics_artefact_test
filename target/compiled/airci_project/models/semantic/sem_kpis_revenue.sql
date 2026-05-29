

-- ================================================================
-- SEMANTIC — KPIs REVENUS & RENTABILITÉ
-- Grain   : 1 ligne par vol
-- Source  : fact_flights + fact_flight_costs + dim_routes
-- KPIs    : yield, RASK, CASK, marge, ancillary_attach_rate
-- ================================================================

SELECT
    -- Clés de navigation
    f.flight_id,
    f.flight_date,
    f.route_id,
    f.aircraft_type,
    r.route_type,
    r.route_label,
    r.distance_km,

    -- Revenus
    f.seats_sold,
    f.seat_capacity,
    f.ticket_revenue_usd,
    f.ancillary_revenue_usd,
    f.total_revenue_usd,
    f.bookings_with_ancillary,

    -- ── KPI 1 : Yield ────────────────────────────────────────
    -- Définition : ticket_revenue / seats_sold
    -- Mesure le revenu moyen par siège vendu (pricing power)
    f.yield_usd,
    CASE
        WHEN f.yield_usd >= 200 THEN 'Premium'
        WHEN f.yield_usd >= 120 THEN 'Standard'
        WHEN f.yield_usd >= 80  THEN 'Low-yield'
        ELSE                         'Très bas'
    END                                                 AS yield_label,

    -- ── KPI 2 : RASK ─────────────────────────────────────────
    -- Définition : total_revenue / seat_capacity (offre)
    -- Combine load factor + yield en 1 indicateur
    CASE WHEN f.seat_capacity > 0
         THEN ROUND(f.total_revenue_usd / f.seat_capacity, 2)
         ELSE NULL
    END                                                 AS rask_usd,

    -- ── KPI 3 : CASK ─────────────────────────────────────────
    -- Définition : total_cost / seat_capacity
    -- Benchmark d'efficience coût
    c.cost_per_seat_usd                                 AS cask_usd,
    c.fuel_cost_usd,
    c.crew_cost_usd,
    c.airport_handling_usd,
    c.maintenance_usd,
    c.total_cost_usd,
    c.fuel_cost_pct,
    c.crew_cost_pct,

    -- ── KPI 4 : Marge vol ────────────────────────────────────
    -- Définition : total_revenue - total_cost
    -- Valeur négative = vol déficitaire
    f.flight_margin_usd,
    CASE
        WHEN f.flight_margin_usd >= 10000 THEN 'Très rentable'
        WHEN f.flight_margin_usd >= 0     THEN 'Rentable'
        WHEN f.flight_margin_usd >= -5000 THEN 'Légèrement déficitaire'
        ELSE                                   'Fortement déficitaire'
    END                                                 AS margin_label,

    -- ── KPI 5 : Ancillary Attach Rate ────────────────────────
    -- Définition : bookings_with_ancillary / seats_sold
    -- Cible : >= 70% | Actuel dataset : 82.6%
    CASE WHEN f.seats_sold > 0
         THEN ROUND(f.bookings_with_ancillary::DOUBLE / f.seats_sold, 4)
         ELSE NULL
    END                                                 AS ancillary_attach_rate,

    -- ── KPI 6 : Ancillary Revenue Share ──────────────────────
    -- Définition : ancillary_revenue / total_revenue
    -- Objectif : > 15% | Actuel : 5.4%
    CASE WHEN f.total_revenue_usd > 0
         THEN ROUND(f.ancillary_revenue_usd / f.total_revenue_usd, 4)
         ELSE NULL
    END                                                 AS ancillary_revenue_share

FROM "dev"."main_marts"."fact_flights"          f
LEFT JOIN "dev"."main_marts"."fact_flight_costs" c ON c.flight_id = f.flight_id
LEFT JOIN "dev"."main_marts"."dim_routes"        r ON r.route_id   = f.route_id