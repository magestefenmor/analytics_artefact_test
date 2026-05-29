
  
    
    

    create  table
      "dev"."main_staging"."stg_flight_costs__dbt_tmp"
  
    as (
      

SELECT
    flight_id                                             AS flight_id,
    route_id                                              AS route_id,
    TRIM(aircraft_type)                                   AS aircraft_type,

    
    TRY_CAST(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(CAST(fuel_cost_usd AS VARCHAR)), '$', ''),
                ' ', ''),
            ',', '.'),
        ' ', '')
    AS DOUBLE)
                  AS fuel_cost_usd,
    
    TRY_CAST(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(CAST(crew_cost_usd AS VARCHAR)), '$', ''),
                ' ', ''),
            ',', '.'),
        ' ', '')
    AS DOUBLE)
                  AS crew_cost_usd,
    
    TRY_CAST(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(CAST(airport_handling_usd AS VARCHAR)), '$', ''),
                ' ', ''),
            ',', '.'),
        ' ', '')
    AS DOUBLE)
           AS airport_handling_usd,
    
    TRY_CAST(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(CAST(maintenance_usd AS VARCHAR)), '$', ''),
                ' ', ''),
            ',', '.'),
        ' ', '')
    AS DOUBLE)
                AS maintenance_usd,
    
    TRY_CAST(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(CAST(total_cost_usd AS VARCHAR)), '$', ''),
                ' ', ''),
            ',', '.'),
        ' ', '')
    AS DOUBLE)
                 AS total_cost_usd,
    
    TRY_CAST(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(CAST(cost_per_seat_usd AS VARCHAR)), '$', ''),
                ' ', ''),
            ',', '.'),
        ' ', '')
    AS DOUBLE)
              AS cost_per_seat_usd,

    CURRENT_TIMESTAMP                                     AS _loaded_at,
    'seed_partie1'                                        AS _source

FROM "dev"."main"."flightCosts"

WHERE flight_id IS NOT NULL
    );
  
  