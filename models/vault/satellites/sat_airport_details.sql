{{ config(materialized='table') }}

-- SATELLITE AIRPORT_DETAILS
-- Source   : snap_airports (dbt snapshot)
-- SCD2     : géré nativement par dbt snapshot
-- Colonnes : dbt_valid_from → load_date
--            dbt_valid_to   → load_end_date (NULL = actif)

SELECT
    SHA256(UPPER(TRIM(COALESCE(CAST(airport_code AS VARCHAR), 'UNKNOWN'))))
                                        AS airport_hk,

    -- hash_diff pour traçabilité
    SHA256(
        COALESCE(airport_name, '') ||
        COALESCE(city,         '') ||
        COALESCE(country,      '') ||
        COALESCE(timezone,     '') ||
        COALESCE(CAST(latitude  AS VARCHAR), '') ||
        COALESCE(CAST(longitude AS VARCHAR), '')
    )                                   AS hash_diff,

    -- Identifiant unique de version (généré par dbt snapshot)
    dbt_scd_id                          AS sat_airport_details_hk,

    -- Attributs
    airport_name,
    city,
    country,
    timezone,
    latitude,
    longitude,

    -- SCD2 metadata (depuis dbt snapshot)
    dbt_valid_from                      AS load_date,
    dbt_valid_to                        AS load_end_date,
    CASE WHEN dbt_valid_to IS NULL
         THEN 1 ELSE 0 END             AS is_current,

    _source                             AS record_source

FROM {{ ref('snap_airports') }}
