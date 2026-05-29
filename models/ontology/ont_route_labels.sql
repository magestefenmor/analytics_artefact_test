{{ config(materialized='table') }}

-- ================================================================
-- ONTOLOGIE — CLASSIFICATION DES ROUTES
-- Source  : sem_kpis_route (KPIs déjà calculés)
-- Grain   : 1 ligne par route
-- Labels  : Cash Cow | Strategic Underperformer | Loss Maker |
--           Emerging | High Concentration Risk
--
-- Règle   : priorité descendante — si une route vérifie plusieurs
--           conditions, le label le plus haut dans le CASE gagne.
-- ================================================================

WITH route_kpis AS (
    SELECT
        route_id,
        route_label,
        route_type,
        origin_city,
        destination_city,
        total_revenue_usd,
        total_cost_usd,
        total_margin_usd,
        margin_pct,
        avg_load_factor,
        on_time_rate,
        avg_yield_usd,
        rask_usd,
        cask_usd,
        revenue_share_network,
        total_flights,
        cancelled_flights,
        delayed_flights
    FROM {{ ref('sem_kpis_route') }}
),

labeled AS (
    SELECT
        r.*,

        -- ── LABEL PRINCIPAL ───────────────────────────────────
        -- Priorité : Concentration Risk > Cash Cow > Emerging
        --            > Strategic Underperformer > Loss Maker
        CASE
            -- 1. High Concentration Risk : > 25% du CA réseau
            --    Signal indépendant de la marge
            WHEN r.revenue_share_network >= 0.25
                THEN 'High Concentration Risk'

            -- 2. Cash Cow : rentable + bien rempli + ponctuel
            WHEN r.total_margin_usd >= 50000
             AND r.avg_load_factor  >= 0.65
             AND r.on_time_rate     >= 0.70
                THEN 'Cash Cow'

            -- 3. Emerging : en croissance, pas encore rentable
            --    mais trajectoire positive (load factor décent)
            WHEN r.total_margin_usd >= -20000
             AND r.avg_load_factor  BETWEEN 0.40 AND 0.65
                THEN 'Emerging'

            -- 4. Strategic Underperformer : déficitaire mais rempli
            --    Trop de demande pour fermer → revoir le pricing
            WHEN r.total_margin_usd < 0
             AND r.avg_load_factor  >= 0.55
                THEN 'Strategic Underperformer'

            -- 5. Loss Maker : déficitaire ET sous-rempli
            --    Candidat à la suspension ou restructuration
            ELSE 'Loss Maker'
        END                                             AS route_label_ont,

        -- ── SIGNAL DE RENTABILITÉ ─────────────────────────────
        CASE
            WHEN r.total_margin_usd >= 100000 THEN '🟢 Très rentable'
            WHEN r.total_margin_usd >= 0      THEN '🟡 Rentable'
            WHEN r.total_margin_usd >= -50000 THEN '🟠 Légèrement déficitaire'
            ELSE                                   '🔴 Fortement déficitaire'
        END                                             AS profitability_signal,

        -- ── SIGNAL OPÉRATIONNEL ───────────────────────────────
        CASE
            WHEN r.on_time_rate >= 0.85 THEN 'Excellent'
            WHEN r.on_time_rate >= 0.75 THEN 'Bon'
            WHEN r.on_time_rate >= 0.60 THEN 'Dégradé'
            ELSE                             'Critique'
        END                                             AS otp_signal,

        -- ── SIGNAL CAPACITÉ ───────────────────────────────────
        CASE
            WHEN r.avg_load_factor >= 0.80 THEN 'Sur-demande'
            WHEN r.avg_load_factor >= 0.65 THEN 'Optimal'
            WHEN r.avg_load_factor >= 0.50 THEN 'Sous-utilisé'
            ELSE                                'Critique'
        END                                             AS capacity_signal,

        -- ── ACTION RECOMMANDÉE ────────────────────────────────
        CASE
            WHEN r.revenue_share_network >= 0.25
                THEN 'Diversifier le réseau — exposition excessive'
            WHEN r.total_margin_usd >= 50000 AND r.avg_load_factor >= 0.65
                THEN 'Maintenir — envisager augmentation fréquence'
            WHEN r.total_margin_usd >= -20000 AND r.avg_load_factor BETWEEN 0.40 AND 0.65
                THEN 'Optimiser pricing — potentiel à développer'
            WHEN r.total_margin_usd < 0 AND r.avg_load_factor >= 0.55
                THEN 'Réviser tarification — load factor OK mais déficitaire'
            ELSE
                'Évaluer suspension ou réduction fréquence'
        END                                             AS recommended_action

    FROM route_kpis r
)

SELECT * FROM labeled
ORDER BY total_margin_usd DESC
