-- ============================================================
-- 5. STG_AIRPORTS
-- Ajout : is_hub (ABJ = hub principal Air CI)
-- ============================================================

CREATE OR REPLACE TABLE stg_airports AS
SELECT
    UPPER(TRIM(airport_code))   AS airport_code,
    TRIM(airport_name)          AS airport_name,
    TRIM(city)                  AS city,
    TRIM(country)               AS country,
    TRIM(timezone)              AS timezone,
    CAST(latitude  AS DOUBLE)   AS latitude,
    CAST(longitude AS DOUBLE)   AS longitude,
    CASE WHEN UPPER(TRIM(airport_code)) = 'ABJ'
         THEN 1 ELSE 0 END      AS is_hub,
    CURRENT_TIMESTAMP           AS _loaded_at,
    'starter_dataset'           AS _source
FROM raw_airports
WHERE airport_code IS NOT NULL;