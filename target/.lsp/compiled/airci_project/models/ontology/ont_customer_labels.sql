

-- ================================================================
-- ONTOLOGIE — CLASSIFICATION DES CLIENTS
-- Source  : sem_kpis_customer (KPIs déjà calculés)
-- Grain   : 1 ligne par client
-- Labels  : High-Value Active | High-Value At-Risk |
--           Corporate High-Value | Loyal Budget |
--           One-Timer | Dormant
--
-- Règle   : priorité descendante — label le plus haut gagne
-- ================================================================

WITH customer_kpis AS (
    SELECT
        customer_id,
        full_name,
        customer_segment,
        loyalty_tier,
        age_group,
        country,
        preferred_channel,
        days_since_signup,
        customer_ltv_usd,
        total_bookings,
        flown_bookings,
        is_repeat_customer,
        no_show_rate,
        ancillary_attach_rate,
        avg_ticket_price_usd,
        avg_ancillary_usd,
        loyalty_balance,
        loyalty_redemption_rate,
        tier_upgrades,
        tier_downgrades,
        points_expiry_events,
        days_since_last_booking,
        last_booking_date,
        total_points_earned,
        total_points_redeemed
    FROM "dev"."main_semantic"."sem_kpis_customer"
),

labeled AS (
    SELECT
        c.*,

        -- ── LABEL PRINCIPAL ───────────────────────────────────
        CASE
            -- 1. Corporate High-Value : segment business + canal corporate
            --    + LTV élevé → programme B2B dédié
            WHEN c.customer_segment IN ('Business', 'Premium')
             AND c.preferred_channel = 'Corporate Desk'
             AND c.customer_ltv_usd >= 1500
                THEN 'Corporate High-Value'

            -- 2. High-Value Active : fort LTV + actif récemment
            --    Priorité de rétention absolue
            WHEN c.customer_ltv_usd       >= 1200
             AND c.days_since_last_booking <= 90
             AND c.loyalty_tier IN ('Gold', 'Silver')
                THEN 'High-Value Active'

            -- 3. High-Value At-Risk : fort LTV mais inactif
            --    Points accumulés sans vol = signal de décrochage
            WHEN c.customer_ltv_usd       >= 800
             AND c.days_since_last_booking >  90
             AND c.loyalty_balance         >  300
                THEN 'High-Value At-Risk'

            -- 4. Loyal Budget : régulier mais sensible au prix
            --    Cible upsell ancillaire et upgrade
            WHEN c.total_bookings          >= 3
             AND c.avg_ticket_price_usd    <  150
             AND c.is_repeat_customer       =  1
                THEN 'Loyal Budget'

            -- 5. One-Timer : 1 seul vol, pas de signal de retour
            --    Campagne retargeting J+30 après le vol
            WHEN c.total_bookings = 1
                THEN 'One-Timer'

            -- 6. Dormant : a volé mais inactif depuis > 180 jours
            --    Campagne réactivation ou considérer comme churné
            WHEN c.days_since_last_booking > 180
             AND COALESCE(c.loyalty_balance, 0) <= 100
                THEN 'Dormant'

            -- 7. Standard : tout le reste
            ELSE 'Standard'
        END                                             AS customer_label_ont,

        -- ── SCORE DE RISQUE CHURN (0-100) ────────────────────
        -- Combinaison pondérée des signaux de désengagement
        LEAST(100, GREATEST(0,
            -- Inactivité (max 40 points)
            CASE
                WHEN c.days_since_last_booking > 180 THEN 40
                WHEN c.days_since_last_booking > 90  THEN 25
                WHEN c.days_since_last_booking > 60  THEN 10
                ELSE 0
            END
            -- Points qui expirent (max 20 points)
            + CASE WHEN c.points_expiry_events > 0 THEN 20 ELSE 0 END
            -- Tier downgrade (max 20 points)
            + CASE WHEN c.tier_downgrades > c.tier_upgrades THEN 20 ELSE 0 END
            -- No-show élevé (max 20 points)
            + CASE WHEN COALESCE(c.no_show_rate, 0) > 0.2 THEN 20 ELSE 0 END
        ))                                              AS churn_risk_score,

        -- ── SIGNAL VALEUR ─────────────────────────────────────
        CASE
            WHEN c.customer_ltv_usd >= 1500 THEN 'Premium'
            WHEN c.customer_ltv_usd >= 800  THEN 'Standard+'
            WHEN c.customer_ltv_usd >= 300  THEN 'Standard'
            ELSE                                 'Low'
        END                                             AS value_signal,

        -- ── SIGNAL LOYAUTÉ ────────────────────────────────────
        CASE
            WHEN c.loyalty_tier = 'Gold'
             AND c.loyalty_redemption_rate >= 0.3  THEN 'Engagé'
            WHEN c.loyalty_tier IN ('Gold','Silver') THEN 'Fidèle'
            WHEN c.loyalty_tier = 'Explorer'         THEN 'En développement'
            WHEN c.loyalty_tier = 'None'
             AND c.total_bookings >= 2               THEN 'Non inscrit — à recruter'
            ELSE                                          'Inactif'
        END                                             AS loyalty_signal,

        -- ── ACTION RECOMMANDÉE ────────────────────────────────
        CASE
            WHEN c.customer_segment IN ('Business','Premium')
             AND c.preferred_channel = 'Corporate Desk'
             AND c.customer_ltv_usd >= 1500
                THEN 'Offre corporate dédiée — account manager'
            WHEN c.customer_ltv_usd >= 1200
             AND c.days_since_last_booking <= 90
                THEN 'Maintenir — upgrade gratuit ou accès lounge'
            WHEN c.customer_ltv_usd >= 800
             AND c.days_since_last_booking > 90
                THEN 'Réactivation urgente — offre personnalisée sous 15j'
            WHEN c.total_bookings >= 3
             AND c.avg_ticket_price_usd < 150
                THEN 'Upsell ancillaire — proposer Flex ou bagage inclus'
            WHEN c.total_bookings = 1
                THEN 'Email J+30 — retargeting avec promo second vol'
            WHEN c.days_since_last_booking > 180
                THEN 'Campagne réactivation ou archiver si > 365j'
            ELSE 'Suivi standard'
        END                                             AS recommended_action

    FROM customer_kpis c
)

SELECT * FROM labeled
ORDER BY churn_risk_score DESC, customer_ltv_usd DESC