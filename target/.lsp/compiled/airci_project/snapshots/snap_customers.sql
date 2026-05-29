



-- Snapshot du profil client
-- SCD2 déclenché si : segment change, tier change, ville change, channel change
-- NON déclenché par : birth_date, signup_date (immuables)

SELECT
    customer_id,
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
    _source
FROM "dev"."main_staging"."stg_customers"

