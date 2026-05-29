
  
    
    

    create  table
      "dev"."main_ontology"."ont_flight_labels__dbt_tmp"
  
    as (
      

-- ================================================================
-- ONTOLOGIE — CLASSIFICATION DES VOLS
-- Source  : sem_kpis_operations + sem_kpis_revenue (KPIs vol)
-- Grain   : 1 ligne par vol
-- Labels  : High-Yield | Chronically Delayed |
--           Loss-Making | Underutilized | Standard
-- ================================================================

WITH flight_kpis AS (
    SELECT
        o.flight_id,
        o.flight_date,
        o.flight_number,
        o.route_id,
        o.route_label,
        o.route_type,
        o.aircraft_type,
        o.flight_status,
        o.load_factor,
        o.load_factor_label,
        o.is_on_time,
        o.is_delayed,
        o.is_cancelled,
        o.delay_min,
        o.delay_bucket,
        o.is_severely_delayed,
        r.yield_usd,
        r.yield_label,
        r.rask_usd,
        r.cask_usd,
        r.flight_margin_usd,
        r.margin_label,
        r.ancillary_attach_rate,
        r.ancillary_revenue_share,
        r.total_revenue_usd,
        r.total_cost_usd
    FROM "dev"."main_semantic"."sem_kpis_operations" o
    LEFT JOIN "dev"."main_semantic"."sem_kpis_revenue" r
        ON r.flight_id = o.flight_id
),

-- Nombre de retards par route (sur la période) pour détecter
-- les routes chroniquement en retard
delay_by_route AS (
    SELECT
        route_id,
        COUNT(CASE WHEN is_delayed = 1 THEN 1 END)  AS delayed_count,
        COUNT(*)                                      AS total_flights,
        AVG(delay_min)                                AS avg_delay_min
    FROM flight_kpis
    GROUP BY route_id
),

labeled AS (
    SELECT
        f.*,
        d.delayed_count                               AS route_delayed_count,
        d.total_flights                               AS route_total_flights,
        d.avg_delay_min                               AS route_avg_delay,

        -- ── LABEL PRINCIPAL ───────────────────────────────────
        CASE
            -- 1. Vol annulé — traitement prioritaire
            WHEN f.is_cancelled = 1
                THEN 'Cancelled'

            -- 2. High-Yield : fort revenu/siège + bon remplissage
            --    Référence pour politique tarifaire
            WHEN f.yield_usd    >= 180
             AND f.load_factor  >= 0.65
             AND f.is_cancelled  = 0
                THEN 'High-Yield'

            -- 3. Chronically Delayed : route avec > 40% de vols en retard
            --    Investigation opérationnelle requise
            WHEN f.is_delayed   = 1
             AND d.delayed_count::DOUBLE / NULLIF(d.total_flights, 0) >= 0.40
             AND f.delay_min    > 30
                THEN 'Chronically Delayed'

            -- 4. Loss-Making : revenu < coût opérationnel
            --    Décision commerciale urgente
            WHEN f.flight_margin_usd < 0
             AND f.is_cancelled = 0
                THEN 'Loss-Making'

            -- 5. Underutilized : < 50% de remplissage
            --    Yield management dynamique ou promo last-minute
            WHEN f.load_factor < 0.50
             AND f.is_cancelled = 0
                THEN 'Underutilized'

            -- 6. Standard : vol normal
            ELSE 'Standard'
        END                                             AS flight_label_ont,

        -- ── PRIORITÉ D'ACTION ─────────────────────────────────
        CASE
            WHEN f.is_cancelled = 1                      THEN 1
            WHEN f.flight_margin_usd < -10000            THEN 2
            WHEN d.delayed_count::DOUBLE
                 / NULLIF(d.total_flights,0) >= 0.40
             AND f.delay_min > 30                        THEN 3
            WHEN f.load_factor < 0.50                    THEN 4
            WHEN f.yield_usd >= 180
             AND f.load_factor >= 0.65                   THEN 5
            ELSE                                              6
        END                                             AS action_priority,

        -- ── SIGNAL PERFORMANCE ────────────────────────────────
        CASE
            WHEN f.rask_usd > f.cask_usd
             AND f.load_factor >= 0.65  THEN 'Performant'
            WHEN f.rask_usd > f.cask_usd THEN 'Rentable — load factor à améliorer'
            WHEN f.rask_usd <= f.cask_usd THEN 'Déficitaire — action requise'
            ELSE 'Données insuffisantes'
        END                                             AS performance_signal,

        -- ── ACTION RECOMMANDÉE ────────────────────────────────
        CASE
            WHEN f.is_cancelled = 1
                THEN 'Analyser cause annulation — reroutage passagers'
            WHEN f.yield_usd >= 180 AND f.load_factor >= 0.65
                THEN 'Référence tarifaire — appliquer ce pricing aux vols similaires'
            WHEN d.delayed_count::DOUBLE
                 / NULLIF(d.total_flights,0) >= 0.40
             AND f.delay_min > 30
                THEN 'Investigation opérationnelle — créneaux ou maintenance'
            WHEN f.flight_margin_usd < 0
                THEN 'Revoir pricing ou réduire la capacité offerte'
            WHEN f.load_factor < 0.50
                THEN 'Promo last-minute ou overbooking contrôlé'
            ELSE 'Suivi standard'
        END                                             AS recommended_action

    FROM flight_kpis f
    LEFT JOIN delay_by_route d ON d.route_id = f.route_id
)

SELECT * FROM labeled
ORDER BY action_priority, flight_margin_usd ASC
    );
  
  