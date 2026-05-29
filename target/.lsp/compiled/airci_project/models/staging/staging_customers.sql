-- ============================================================
-- 3. STG_CUSTOMERS
-- Corrections :
--   - loyalty_tier NULL → 'None'
--   - age calculé au 01/01/2025 (date de référence du dataset)
--   - age_group buckets
-- ============================================================

CREATE OR REPLACE TABLE stg_customers AS
SELECT
    CAST(customer_id          AS VARCHAR)   AS customer_id,
    TRIM(first_name)                        AS first_name,
    TRIM(last_name)                         AS last_name,
    UPPER(TRIM(gender))                     AS gender,
    TRY_CAST(birth_date       AS DATE)      AS birth_date,
    TRIM(country)                           AS country,
    TRIM(city)                              AS city,
    TRIM(customer_segment)                  AS customer_segment,
    COALESCE(TRIM(loyalty_tier), 'None')    AS loyalty_tier,
    TRY_CAST(signup_date      AS DATE)      AS signup_date,
    TRIM(preferred_channel)                 AS preferred_channel,
    DATEDIFF('year',
        TRY_CAST(birth_date AS DATE),
        DATE '2025-01-01')                  AS age,
    CASE
        WHEN DATEDIFF('year', TRY_CAST(birth_date AS DATE), DATE '2025-01-01') < 25 THEN '<25'
        WHEN DATEDIFF('year', TRY_CAST(birth_date AS DATE), DATE '2025-01-01') < 35 THEN '25-34'
        WHEN DATEDIFF('year', TRY_CAST(birth_date AS DATE), DATE '2025-01-01') < 45 THEN '35-44'
        WHEN DATEDIFF('year', TRY_CAST(birth_date AS DATE), DATE '2025-01-01') < 55 THEN '45-54'
        ELSE '55+'
    END                                     AS age_group,
    CURRENT_TIMESTAMP                       AS _loaded_at,
    'starter_dataset'                       AS _source
FROM raw_customers
WHERE customer_id IS NOT NULL;
