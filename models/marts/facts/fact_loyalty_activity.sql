{{ config(materialized='table') }}

-- ================================================================
-- FACT_LOYALTY_ACTIVITY
-- Source  : Business Vault
--   lnk_loyalty_event → hub_customer
--   pit_customer      → sat_customer_loyalty (version active)
--   sat_customer_profile → segment au moment de l'événement
-- Grain   : 1 ligne par événement loyalty
-- ================================================================

SELECT
    -- Clés
    scl.activity_id,
    hc.customer_bk                                          AS customer_id,
    hc.customer_hk,

    -- Attributs événement (sat_customer_loyalty)
    scl.activity_date,
    scl.event_type,
    scl.loyalty_tier,
    scl.points_earned,
    scl.points_redeemed,
    scl.balance_after,
    scl.balance_after
        - scl.points_earned
        + scl.points_redeemed                              AS balance_before,

    -- Profil client au moment de l'événement (pit_customer)
    scp.customer_segment,
    scp.preferred_channel,

    -- Flags événement
    CASE WHEN scl.event_type ILIKE '%upgrade%'   THEN 1 ELSE 0 END AS is_upgrade,
    CASE WHEN scl.event_type ILIKE '%downgrade%' THEN 1 ELSE 0 END AS is_downgrade,
    CASE WHEN scl.event_type ILIKE '%expir%'     THEN 1 ELSE 0 END AS is_expiry,
    CASE WHEN scl.points_earned > 0              THEN 1 ELSE 0 END AS is_earn,
    CASE WHEN scl.points_redeemed > 0            THEN 1 ELSE 0 END AS is_redeem,

    pit_c.snapshot_date                                     AS customer_snapshot_date

FROM {{ ref('lnk_loyalty_event') }}             le
JOIN {{ ref('hub_customer') }}                  hc
    ON  hc.customer_hk  = le.customer_hk

-- Satellite loyalty via PIT
JOIN {{ ref('pit_customer') }}                  pit_c
    ON  pit_c.customer_hk   = hc.customer_hk
    AND pit_c.snapshot_date = (
        SELECT MAX(p.snapshot_date)
        FROM {{ ref('pit_customer') }} p
        WHERE p.customer_hk = hc.customer_hk
    )
JOIN {{ ref('sat_customer_loyalty') }}          scl
    ON  scl.sat_customer_loyalty_hk = pit_c.sat_customer_loyalty_hk
    AND pit_c.sat_customer_loyalty_hk != 'GHOST'
    AND scl.activity_id = le.activity_bk

-- Profil client via PIT (pour segment au moment de l'événement)
LEFT JOIN {{ ref('sat_customer_profile') }}     scp
    ON  scp.sat_customer_profile_hk = pit_c.sat_customer_profile_hk
    AND pit_c.sat_customer_profile_hk != 'GHOST'
