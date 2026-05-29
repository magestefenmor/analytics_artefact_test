
  
    
    

    create  table
      "dev"."main_staging"."stg_airports__dbt_tmp"
  
    as (
      

SELECT
    UPPER(TRIM(airport_code))                               AS airport_code,
    TRIM(airport_name)                                      AS airport_name,
    TRIM(city)                                              AS city,
    TRIM(country)                                           AS country,
    TRIM(timezone)                                          AS timezone,
    
    TRY_CAST(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(CAST(latitude AS VARCHAR)), '$', ''),
                ' ', ''),
            ',', '.'),
        ' ', '')
    AS DOUBLE)
                         AS latitude,
    
    TRY_CAST(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(CAST(longitude AS VARCHAR)), '$', ''),
                ' ', ''),
            ',', '.'),
        ' ', '')
    AS DOUBLE)
                        AS longitude,
    CURRENT_TIMESTAMP                                       AS _loaded_at,
    'seed_starter'                                          AS _source
FROM "dev"."main"."airport"
WHERE airport_code IS NOT NULL
    );
  
  