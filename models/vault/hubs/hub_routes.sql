{{ config(materialized='table') }}

-- HUB ROUTE
-- Clé métier : route_id
-- Source     : stg_routes
-- Grain      : 1 ligne par route unique

SELECT
    SHA256(UPPER(TRIM(COALESCE(CAST(route_id AS VARCHAR), 'UNKNOWN'))))
                            AS route_hk,
    route_id                AS route_bk,
    CURRENT_DATE            AS load_date,
    _source                 AS record_source
FROM {{ ref('stg_routes') }}
WHERE route_id IS NOT NULL
