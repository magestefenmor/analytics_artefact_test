



-- Snapshot des coûts par vol
-- SCD2 déclenché si les coûts sont révisés
-- is_generated tracé pour distinguer réel vs synthétique

SELECT
    flight_id,
    route_id,
    aircraft_type,
    fuel_cost_usd,
    crew_cost_usd,
    airport_handling_usd,
    maintenance_usd,
    total_cost_usd,
    cost_per_seat_usd,
    is_generated,
    _source
FROM "dev"."main_staging"."stg_flight_costs"

