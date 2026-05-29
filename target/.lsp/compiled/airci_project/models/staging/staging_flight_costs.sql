-- ============================================================
-- 6. STG_FLIGHT_COSTS
-- Note : is_generated=1 pour les 208 vols générés synthétiquement
-- ============================================================

CREATE OR REPLACE TABLE stg_flight_costs AS
SELECT
    CAST(flight_id            AS VARCHAR)  AS flight_id,
    CAST(route_id             AS VARCHAR)  AS route_id,
    CAST(aircraft_type        AS VARCHAR)  AS aircraft_type,
    CAST(fuel_cost_usd        AS DOUBLE)   AS fuel_cost_usd,
    CAST(crew_cost_usd        AS DOUBLE)   AS crew_cost_usd,
    CAST(airport_handling_usd AS DOUBLE)   AS airport_handling_usd,
    CAST(maintenance_usd      AS DOUBLE)   AS maintenance_usd,
    CAST(total_cost_usd       AS DOUBLE)   AS total_cost_usd,
    CAST(cost_per_seat_usd    AS DOUBLE)   AS cost_per_seat_usd,
    CAST(is_generated         AS INTEGER)  AS is_generated,
    CURRENT_TIMESTAMP                      AS _loaded_at,
    'partie1_synth'                        AS _source
FROM raw_flight_costs
WHERE flight_id IS NOT NULL;
