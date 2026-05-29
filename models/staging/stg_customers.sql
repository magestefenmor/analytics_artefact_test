{{ config(materialized='table') }}

SELECT
    customer_id                                             AS customer_id,
    TRIM(first_name)                                        AS first_name,
    TRIM(last_name)                                         AS last_name,
    UPPER(TRIM(gender))                                     AS gender,
    CAST(birth_date         AS DATE)                        AS birth_date,
    TRIM(country)                                           AS country,
    TRIM(city)                                              AS city,
    TRIM(customer_segment)                                  AS customer_segment,
    COALESCE(TRIM(loyalty_tier), 'None')                    AS loyalty_tier,
    CAST(signup_date        AS DATE)                        AS signup_date,
    TRIM(preferred_channel)                                 AS preferred_channel,
    CURRENT_TIMESTAMP                                       AS _loaded_at,
    'seed_starter'                                          AS _source
FROM {{ ref('customers') }}
WHERE customer_id IS NOT NULL
