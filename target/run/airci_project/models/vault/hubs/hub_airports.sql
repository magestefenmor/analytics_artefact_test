
  
    
    

    create  table
      "dev"."main_vault"."hub_airports__dbt_tmp"
  
    as (
      

-- HUB AIRPORT
-- Clé métier : airport_code (IATA)
-- Source     : stg_airports
-- Grain      : 1 ligne par aéroport unique

SELECT
    SHA256(UPPER(TRIM(COALESCE(CAST(airport_code AS VARCHAR), 'UNKNOWN'))))
                            AS airport_hk,
    airport_code            AS airport_bk,
    CURRENT_DATE            AS load_date,
    _source                 AS record_source
FROM "dev"."main_staging"."stg_airports"
WHERE airport_code IS NOT NULL
    );
  
  