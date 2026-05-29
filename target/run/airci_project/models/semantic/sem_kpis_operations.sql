
  
  create view "dev"."main_semantic"."sem_kpis_operations__dbt_tmp" as (
    

-- ================================================================
-- SEMANTIC — KPIs OPÉRATIONNELS
-- Grain   : 1 ligne par vol
-- Source  : fact_flights + dim_routes + dim_aircraft
-- KPIs    : load_factor, on_time_rate, delay_rate, cancellation_rate
-- ================================================================

SELECT
    -- Clés de navigation
    f.flight_id,
    f.flight_date,
    f.flight_number,
    f.route_id,
    f.aircraft_type,
    f.flight_status,

    -- Dimensions analytiques
    r.route_type,
    r.route_label,
    r.origin_airport_code,
    r.destination_airport_code,
    r.distance_km,
    a.aircraft_family,
    a.is_neo_engine,

    -- ── KPI 1 : Load Factor ──────────────────────────────────
    -- Définition : seats_sold / seat_capacity
    -- Seuil alerte : < 0.60 | Cible : >= 0.75
    f.seat_capacity,
    f.seats_sold,
    f.load_factor,
    CASE
        WHEN f.load_factor >= 0.75 THEN 'Optimal'
        WHEN f.load_factor >= 0.60 THEN 'Acceptable'
        WHEN f.load_factor >= 0.40 THEN 'Sous-rempli'
        ELSE                            'Critique'
    END                                                 AS load_factor_label,

    -- ── KPI 2 : On-Time Performance ──────────────────────────
    -- Définition : 1 si statut ON TIME, 0 sinon
    -- Standard IATA : retard < 15 min
    CASE WHEN f.flight_status = 'ON TIME' THEN 1 ELSE 0 END
                                                        AS is_on_time,

    -- ── KPI 3 : Retard ───────────────────────────────────────
    -- Définition : delay_min > 0
    f.is_delayed,
    f.delay_min,
    CASE
        WHEN f.delay_min IS NULL    THEN 'N/A'
        WHEN f.delay_min = 0        THEN 'Aucun retard'
        WHEN f.delay_min <= 30      THEN 'Retard léger (< 30min)'
        WHEN f.delay_min <= 60      THEN 'Retard modéré (30-60min)'
        ELSE                             'Retard sévère (> 60min)'
    END                                                 AS delay_bucket,

    -- ── KPI 4 : Annulation ───────────────────────────────────
    f.is_cancelled,

    -- ── KPI 5 : Retard sévère ────────────────────────────────
    f.is_severely_delayed

FROM "dev"."main_marts"."fact_flights"      f
LEFT JOIN "dev"."main_marts"."dim_routes"   r ON r.route_id     = f.route_id
LEFT JOIN "dev"."main_marts"."dim_aircraft" a ON a.aircraft_type = f.aircraft_type
  );
