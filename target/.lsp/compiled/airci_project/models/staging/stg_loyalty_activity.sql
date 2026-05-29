

SELECT
    loyalty_id                                              AS activity_id,
    customer_id                                             AS customer_id,
    TRY_CAST(event_date     AS DATE)                        AS activity_date,
    TRIM(event_type)                                        AS event_type,
    TRIM(loyalty_tier)                                      AS loyalty_tier,
    CAST(points_earned      AS INTEGER)                     AS points_earned,
    CAST(points_redeemed    AS INTEGER)                     AS points_redeemed,
    CAST(balance_after      AS INTEGER)                     AS balance_after,
    CURRENT_TIMESTAMP                                       AS _loaded_at,
    'seed_partie1'                                          AS _source
FROM "dev"."main"."loyaltyActivity"
WHERE loyalty_id IS NOT NULL