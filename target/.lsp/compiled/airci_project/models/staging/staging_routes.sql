-- ============================================================
-- 4. STG_ROUTES
-- Ajout : route_label (ex : ABJ-CDG)
-- ============================================================

CREATE OR REPLACE TABLE stg_routes AS
SELECT
    CAST(route_id                 AS VARCHAR)  AS route_id,
    CAST(origin_airport_code      AS VARCHAR)  AS origin_airport_code,
    CAST(destination_airport_code AS VARCHAR)  AS destination_airport_code,
    TRIM(route_type)                           AS route_type,
    CAST(distance_km              AS INTEGER)  AS distance_km,
    CAST(block_time_min           AS INTEGER)  AS block_time_min,
    origin_airport_code || '-' || destination_airport_code
                                               AS route_label,
    CURRENT_TIMESTAMP                          AS _loaded_at,
    'starter_dataset'                          AS _source
FROM raw_routes
WHERE route_id IS NOT NULL;