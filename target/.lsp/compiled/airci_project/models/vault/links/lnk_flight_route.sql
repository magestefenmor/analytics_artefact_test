

-- LINK FLIGHT_ROUTE
-- Relation : un vol opère sur une route
-- Sources  : hub_flight + hub_route via stg_flights
-- Grain    : 1 ligne par combinaison flight + route

SELECT
    SHA256(
        UPPER(TRIM(COALESCE(CAST(f.flight_id AS VARCHAR), 'UNKNOWN')))
        || '||' ||
        UPPER(TRIM(COALESCE(CAST(f.route_id  AS VARCHAR), 'UNKNOWN')))
    )                           AS lnk_flight_route_hk,
    SHA256(UPPER(TRIM(COALESCE(CAST(f.flight_id AS VARCHAR), 'UNKNOWN'))))
                                AS flight_hk,
    SHA256(UPPER(TRIM(COALESCE(CAST(f.route_id  AS VARCHAR), 'UNKNOWN'))))
                                AS route_hk,
    CURRENT_DATE                AS load_date,
    f._source                   AS record_source
FROM "dev"."main_staging"."stg_flights" f
WHERE f.flight_id IS NOT NULL
  AND f.route_id  IS NOT NULL