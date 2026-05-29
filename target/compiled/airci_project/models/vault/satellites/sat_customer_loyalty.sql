

-- SATELLITE CUSTOMER_LOYALTY
-- Source   : snap_loyalty_activity (dbt snapshot)
-- Grain    : événement loyalty (immuable en principe)
-- SCD2     : déclenché si points corrigés

SELECT
    SHA256(UPPER(TRIM(COALESCE(CAST(customer_id AS VARCHAR), 'UNKNOWN'))))
                                        AS customer_hk,

    SHA256(
        COALESCE(CAST(activity_id    AS VARCHAR), '') ||
        COALESCE(CAST(points_earned   AS VARCHAR), '') ||
        COALESCE(CAST(points_redeemed AS VARCHAR), '') ||
        COALESCE(CAST(balance_after   AS VARCHAR), '') ||
        COALESCE(loyalty_tier,        '')
    )                                   AS hash_diff,

    dbt_scd_id                          AS sat_customer_loyalty_hk,

    -- Attributs
    activity_id,
    activity_date,
    event_type,
    loyalty_tier,
    points_earned,
    points_redeemed,
    balance_after,

    -- SCD2 metadata
    dbt_valid_from                      AS load_date,
    dbt_valid_to                        AS load_end_date,
    CASE WHEN dbt_valid_to IS NULL
         THEN 1 ELSE 0 END             AS is_current,

    _source                             AS record_source

FROM "dev"."snapshots"."snap_loyalty_activity"