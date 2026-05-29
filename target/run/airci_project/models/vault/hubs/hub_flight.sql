
  
    
    

    create  table
      "dev"."main_vault"."hub_flight__dbt_tmp"
  
    as (
      

-- HUB FLIGHT
-- Clé métier : flight_id
-- Source     : stg_flights
-- Grain      : 1 ligne par vol unique

SELECT
    SHA256(UPPER(TRIM(COALESCE(CAST(flight_id AS VARCHAR), 'UNKNOWN'))))
                            AS flight_hk,
    flight_id               AS flight_bk,
    CURRENT_DATE            AS load_date,
    _source                 AS record_source
FROM "dev"."main_staging"."stg_flights"
WHERE flight_id IS NOT NULL
    );
  
  