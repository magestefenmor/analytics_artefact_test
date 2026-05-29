 ========================================================
-- 7. STG_LOYALTY_ACTIVITY
-- Corrections :
--   - loyalty_id renommé activity_id (alignement modèle)
--   - event_date renommé activity_date
-- ============================================================

CREATE OR REPLACE TABLE stg_loyalty_activity AS
SELECT
    CAST(loyalty_id      AS VARCHAR)  AS activity_id,
    CAST(customer_id     AS VARCHAR)  AS customer_id,
    TRY_CAST(event_date  AS DATE)     AS activity_date,
    TRIM(event_type)                  AS event_type,
    TRIM(loyalty_tier)                AS loyalty_tier,
    CAST(points_earned   AS INTEGER)  AS points_earned,
    CAST(points_redeemed AS INTEGER)  AS points_redeemed,
    CAST(balance_after   AS INTEGER)  AS balance_after,
    CURRENT_TIMESTAMP                 AS _loaded_at,
    'partie1_synth'                   AS _source
FROM raw_loyalty_activity
WHERE loyalty_id IS NOT NULL;
