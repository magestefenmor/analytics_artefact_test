



-- Snapshot des routes
-- SCD2 déclenché si : type de route change, durée de bloc change

SELECT
    route_id,
    origin_airport_code,
    destination_airport_code,
    route_type,
    distance_km,
    block_time_min,
    _source
FROM "dev"."main_staging"."stg_routes"

