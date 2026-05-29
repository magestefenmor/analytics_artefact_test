

-- SATELLITE ROUTE_DETAILS
-- Source   : snap_routes (dbt snapshot)

SELECT
    SHA256(UPPER(TRIM(COALESCE(CAST(route_id AS VARCHAR), 'UNKNOWN'))))
                                        AS route_hk,

    SHA256(
        COALESCE(origin_airport_code,      '') ||
        COALESCE(destination_airport_code, '') ||
        COALESCE(route_type,               '') ||
        COALESCE(CAST(distance_km    AS VARCHAR), '') ||
        COALESCE(CAST(block_time_min AS VARCHAR), '')
    )                                   AS hash_diff,

    dbt_scd_id                          AS sat_route_details_hk,

    -- Attributs
    origin_airport_code,
    destination_airport_code,
    origin_airport_code || '-' || destination_airport_code
                                        AS route_label,
    route_type,
    distance_km,
    block_time_min,

    -- SCD2 metadata
    dbt_valid_from                      AS load_date,
    dbt_valid_to                        AS load_end_date,
    CASE WHEN dbt_valid_to IS NULL
         THEN 1 ELSE 0 END             AS is_current,

    _source                             AS record_source

FROM "dev"."snapshots"."snap_routes"