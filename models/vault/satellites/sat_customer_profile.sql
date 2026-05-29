{{ config(materialized='table') }}

-- SATELLITE CUSTOMER_PROFILE
-- Source   : snap_customers (dbt snapshot)
-- SCD2     : déclenché si segment, tier, ville ou channel change

SELECT
    SHA256(UPPER(TRIM(COALESCE(CAST(customer_id AS VARCHAR), 'UNKNOWN'))))
                                        AS customer_hk,

    SHA256(
        COALESCE(first_name,        '') ||
        COALESCE(last_name,         '') ||
        COALESCE(gender,            '') ||
        COALESCE(country,           '') ||
        COALESCE(city,              '') ||
        COALESCE(customer_segment,  '') ||
        COALESCE(loyalty_tier,      '') ||
        COALESCE(preferred_channel, '')
    )                                   AS hash_diff,

    dbt_scd_id                          AS sat_customer_profile_hk,

    -- Attributs
    first_name,
    last_name,
    gender,
    birth_date,
    country,
    city,
    customer_segment,
    loyalty_tier,
    signup_date,
    preferred_channel,

    -- SCD2 metadata
    dbt_valid_from                      AS load_date,
    dbt_valid_to                        AS load_end_date,
    CASE WHEN dbt_valid_to IS NULL
         THEN 1 ELSE 0 END             AS is_current,

    _source                             AS record_source

FROM {{ ref('snap_customers') }}
