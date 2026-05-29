
  
    
    

    create  table
      "dev"."main_staging"."stg_routes__dbt_tmp"
  
    as (
      

SELECT
    route_id                                                AS route_id,
    TRIM(origin_airport_code)                               AS origin_airport_code,
    TRIM(destination_airport_code)                          AS destination_airport_code,
    TRIM(route_type)                                        AS route_type,
    CAST(distance_km        AS INTEGER)                     AS distance_km,
    CAST(block_time_min     AS INTEGER)                     AS block_time_min,
    CURRENT_TIMESTAMP                                       AS _loaded_at,
    'seed_starter'                                          AS _source
FROM "dev"."main"."routes"
WHERE route_id IS NOT NULL
    );
  
  