



-- Snapshot des événements loyalty
-- Grain événement — chaque activité est immuable en principe
-- SCD2 déclenché si un événement est corrigé (ex: points ajustés)

SELECT
    activity_id,
    customer_id,
    activity_date,
    event_type,
    loyalty_tier,
    points_earned,
    points_redeemed,
    balance_after,
    _source
FROM "dev"."main_staging"."stg_loyalty_activity"

