{{ config(materialized='table') }}

SELECT
    UPPER(TRIM(airport_code))                               AS airport_code,
    TRIM(airport_name)                                      AS airport_name,
    TRIM(city)                                              AS city,
    TRIM(country)                                           AS country,
    TRIM(timezone)                                          AS timezone,
    {{ clean_numeric('latitude') }}                         AS latitude,
    {{ clean_numeric('longitude') }}                        AS longitude,
    CURRENT_TIMESTAMP                                       AS _loaded_at,
    'seed_starter'                                          AS _source
FROM {{ ref('airport') }}
WHERE airport_code IS NOT NULL
