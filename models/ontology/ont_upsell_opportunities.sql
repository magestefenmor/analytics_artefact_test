{{ config(materialized='table') }}

-- ================================================================
-- ONTOLOGIE — OPPORTUNITÉS UPSELL / CROSS-SELL
-- Source  : sem_kpis_customer + fact_bookings + fact_flights
-- Grain   : 1 ligne par client
-- Theme   : Upsell / Cross-sell (Business Theme 3)
--
-- Basé sur l'analyse des données réelles :
--   - 24.8% des réservations sans bagage (opportunité bagage)
--   - 50.2% sans sélection de siège (opportunité seat)
--   - 116 clients LTV > 500$ avec ancillaire moyen < 20$
--   - 42 Gold + 48 Silver qui volent en Economy
--   - 269 clients sans siège sur vols internationaux
--
-- Labels upsell (non exclusifs — un client peut avoir plusieurs)
-- Score global 0-100 pour prioriser les actions commerciales
-- ================================================================

WITH customer_booking_profile AS (
    -- Profil détaillé des habitudes d'achat par client
    SELECT
        b.customer_id,

        -- Volume et valeur
        COUNT(*)                                            AS total_bookings,
        SUM(b.ticket_price_usd)                            AS total_ticket_rev,
        SUM(b.ancillary_revenue_usd)                       AS total_ancillary_rev,
        AVG(b.ticket_price_usd)                            AS avg_ticket_price,
        AVG(b.ancillary_revenue_usd)                       AS avg_ancillary,

        -- Habitudes bagages
        SUM(CASE WHEN b.bags_count = 0 THEN 1 ELSE 0 END) AS bookings_no_bag,
        SUM(CASE WHEN b.bags_count = 1 THEN 1 ELSE 0 END) AS bookings_one_bag,
        SUM(CASE WHEN b.bags_count >= 2 THEN 1 ELSE 0 END) AS bookings_multi_bag,
        AVG(b.bags_count)                                  AS avg_bags,

        -- Habitudes siège
        SUM(CASE WHEN b.seat_selection_flag = 0 THEN 1 ELSE 0 END)
                                                           AS bookings_no_seat,
        SUM(CASE WHEN b.seat_selection_flag = 1 THEN 1 ELSE 0 END)
                                                           AS bookings_with_seat,

        -- Distribution classes
        SUM(CASE WHEN b.fare_class = 'ECONOMY' THEN 1 ELSE 0 END)
                                                           AS economy_bookings,
        SUM(CASE WHEN b.fare_class = 'PREMIUM ECONOMY' THEN 1 ELSE 0 END)
                                                           AS premium_economy_bookings,
        SUM(CASE WHEN b.fare_class = 'BUSINESS' THEN 1 ELSE 0 END)
                                                           AS business_bookings,

        -- Famille tarifaire
        SUM(CASE WHEN b.fare_family = 'Basic' THEN 1 ELSE 0 END)
                                                           AS basic_bookings,
        SUM(CASE WHEN b.fare_family = 'Standard' THEN 1 ELSE 0 END)
                                                           AS standard_bookings,
        SUM(CASE WHEN b.fare_family = 'Flex' THEN 1 ELSE 0 END)
                                                           AS flex_bookings,

        -- Vols internationaux (siège critique sur long courrier)
        SUM(CASE WHEN r.route_type = 'International'
                  AND b.seat_selection_flag = 0 THEN 1 ELSE 0 END)
                                                           AS intl_no_seat,
        SUM(CASE WHEN r.route_type = 'International' THEN 1 ELSE 0 END)
                                                           AS intl_bookings,

        -- Dernier vol
        MAX(f.flight_date)                                 AS last_flight_date

    FROM {{ ref('fact_bookings') }}     b
    LEFT JOIN {{ ref('fact_flights') }} f ON f.flight_id = b.flight_id
    LEFT JOIN {{ ref('dim_routes') }}   r ON r.route_id  = f.route_id
    WHERE b.is_active_booking = 1
    GROUP BY b.customer_id
),

customer_base AS (
    -- Jointure avec le profil client pour loyalty_tier et segment
    SELECT
        p.*,
        c.customer_segment,
        c.loyalty_tier,
        c.preferred_channel,
        c.full_name,
        c.country,
        c.age_group
    FROM customer_booking_profile       p
    LEFT JOIN {{ ref('dim_customers') }} c ON c.customer_id = p.customer_id
),

opportunities AS (
    SELECT
        cb.*,

        -- ── OPPORTUNITÉ 1 : UPGRADE CLASSE ───────────────────
        -- Clients Economy récurrents éligibles à Premium Economy ou Business
        -- Signal fort : Gold/Silver qui n'ont jamais pris Business
        CASE
            WHEN cb.economy_bookings >= 3
             AND cb.business_bookings = 0
             AND cb.loyalty_tier IN ('Gold', 'Silver')
                THEN 'Upgrade Business — fidèle Economy haut tier'
            WHEN cb.economy_bookings >= 5
             AND cb.business_bookings = 0
             AND cb.avg_ticket_price >= 150
                THEN 'Upgrade Premium Economy — volume Economy élevé'
            WHEN cb.premium_economy_bookings >= 2
             AND cb.business_bookings = 0
                THEN 'Upgrade Business — déjà Premium Economy'
            ELSE NULL
        END                                                 AS upsell_class,

        -- ── OPPORTUNITÉ 2 : BAGAGE SUPPLÉMENTAIRE ────────────
        -- 24.8% des réservations sans bagage → opportunité directe
        CASE
            WHEN cb.bookings_no_bag::DOUBLE
                 / NULLIF(cb.total_bookings, 0) >= 0.60
             AND cb.total_bookings >= 2
                THEN 'Bagage soute — voyage souvent sans bagage'
            WHEN cb.avg_bags >= 1
             AND cb.avg_bags < 1.5
             AND cb.intl_bookings >= 1
                THEN 'Bagage supplémentaire — vols internationaux'
            ELSE NULL
        END                                                 AS upsell_baggage,

        -- ── OPPORTUNITÉ 3 : SÉLECTION SIÈGE ──────────────────
        -- 50.2% sans sélection — 269 sur vols internationaux
        CASE
            WHEN cb.intl_no_seat >= 1
             AND cb.intl_bookings >= 1
                THEN 'Siège prioritaire — vols internationaux non sélectionnés'
            WHEN cb.bookings_no_seat::DOUBLE
                 / NULLIF(cb.total_bookings, 0) >= 0.70
             AND cb.total_bookings >= 3
                THEN 'Sélection siège — habitude systématique sans choix'
            ELSE NULL
        END                                                 AS upsell_seat,

        -- ── OPPORTUNITÉ 4 : UPGRADE FARE FAMILY ──────────────
        -- Clients Basic récurrents → Standard ou Flex (flexibilité)
        CASE
            WHEN cb.basic_bookings::DOUBLE
                 / NULLIF(cb.total_bookings, 0) >= 0.70
             AND cb.total_bookings >= 3
             AND cb.avg_ticket_price >= 100
                THEN 'Flex — voyage souvent en Basic, risque annulation'
            WHEN cb.standard_bookings >= 3
             AND cb.flex_bookings = 0
                THEN 'Flex — volume Standard, éligible flexibilité'
            ELSE NULL
        END                                                 AS upsell_fare_family,

        -- ── OPPORTUNITÉ 5 : ANCILLAIRE GÉNÉRAL ───────────────
        -- 116 clients LTV > 500$ avec ancillaire moyen < 20$
        CASE
            WHEN cb.avg_ancillary < 20
             AND cb.total_ticket_rev > 500
             AND cb.total_bookings >= 2
                THEN 'Bundle ancillaire — fort LTV mais peu d''ancillaires'
            WHEN cb.avg_ancillary = 0
             AND cb.total_bookings >= 1
                THEN 'Premier ancillaire — aucun achat additionnel'
            ELSE NULL
        END                                                 AS upsell_ancillary,

        -- ── OPPORTUNITÉ 6 : CROSS-SELL PROGRAMME LOYALTY ─────
        -- Clients récurrents non inscrits au programme
        CASE
            WHEN cb.loyalty_tier = 'None'
             AND cb.total_bookings >= 2
                THEN 'Inscription loyalty — vole régulièrement sans programme'
            WHEN cb.loyalty_tier = 'Explorer'
             AND cb.total_bookings >= 3
                THEN 'Activation Silver — proche du seuil tier'
            ELSE NULL
        END                                                 AS crosssell_loyalty

    FROM customer_base cb
),

scored AS (
    SELECT
        o.*,

        -- ── SCORE UPSELL GLOBAL (0-100) ───────────────────────
        -- Somme pondérée des opportunités détectées
        LEAST(100,
            -- Upgrade classe = fort potentiel revenue (30 pts max)
            CASE WHEN o.upsell_class IS NOT NULL THEN 30 ELSE 0 END
            -- Ancillaire général (25 pts)
            + CASE WHEN o.upsell_ancillary IS NOT NULL THEN 25 ELSE 0 END
            -- Fare family (20 pts)
            + CASE WHEN o.upsell_fare_family IS NOT NULL THEN 20 ELSE 0 END
            -- Bagage (15 pts)
            + CASE WHEN o.upsell_baggage IS NOT NULL THEN 15 ELSE 0 END
            -- Siège (10 pts)
            + CASE WHEN o.upsell_seat IS NOT NULL THEN 10 ELSE 0 END
            -- Loyalty cross-sell (bonus 10 pts)
            + CASE WHEN o.crosssell_loyalty IS NOT NULL THEN 10 ELSE 0 END
        )                                                   AS upsell_score,

        -- ── NOMBRE D'OPPORTUNITÉS DÉTECTÉES ──────────────────
        (CASE WHEN o.upsell_class IS NOT NULL        THEN 1 ELSE 0 END
         + CASE WHEN o.upsell_baggage IS NOT NULL    THEN 1 ELSE 0 END
         + CASE WHEN o.upsell_seat IS NOT NULL       THEN 1 ELSE 0 END
         + CASE WHEN o.upsell_fare_family IS NOT NULL THEN 1 ELSE 0 END
         + CASE WHEN o.upsell_ancillary IS NOT NULL  THEN 1 ELSE 0 END
         + CASE WHEN o.crosssell_loyalty IS NOT NULL THEN 1 ELSE 0 END)
                                                            AS opportunity_count,

        -- ── SEGMENT D'ACTION ──────────────────────────────────
        CASE
            WHEN LEAST(100,
                CASE WHEN o.upsell_class IS NOT NULL THEN 30 ELSE 0 END
                + CASE WHEN o.upsell_ancillary IS NOT NULL THEN 25 ELSE 0 END
                + CASE WHEN o.upsell_fare_family IS NOT NULL THEN 20 ELSE 0 END
                + CASE WHEN o.upsell_baggage IS NOT NULL THEN 15 ELSE 0 END
                + CASE WHEN o.upsell_seat IS NOT NULL THEN 10 ELSE 0 END
                + CASE WHEN o.crosssell_loyalty IS NOT NULL THEN 10 ELSE 0 END
            ) >= 50 THEN 'Priorité haute — action immédiate'
            WHEN LEAST(100,
                CASE WHEN o.upsell_class IS NOT NULL THEN 30 ELSE 0 END
                + CASE WHEN o.upsell_ancillary IS NOT NULL THEN 25 ELSE 0 END
                + CASE WHEN o.upsell_fare_family IS NOT NULL THEN 20 ELSE 0 END
                + CASE WHEN o.upsell_baggage IS NOT NULL THEN 15 ELSE 0 END
                + CASE WHEN o.upsell_seat IS NOT NULL THEN 10 ELSE 0 END
                + CASE WHEN o.crosssell_loyalty IS NOT NULL THEN 10 ELSE 0 END
            ) >= 25 THEN 'Priorité moyenne — campagne ciblée'
            ELSE             'Priorité basse — communication standard'
        END                                                 AS action_segment,

        -- ── ACTION PRIMAIRE RECOMMANDÉE ───────────────────────
        -- L'opportunité à plus fort potentiel revenue
        CASE
            WHEN o.upsell_class IS NOT NULL
                THEN o.upsell_class
            WHEN o.upsell_ancillary IS NOT NULL
                THEN o.upsell_ancillary
            WHEN o.upsell_fare_family IS NOT NULL
                THEN o.upsell_fare_family
            WHEN o.upsell_baggage IS NOT NULL
                THEN o.upsell_baggage
            WHEN o.upsell_seat IS NOT NULL
                THEN o.upsell_seat
            WHEN o.crosssell_loyalty IS NOT NULL
                THEN o.crosssell_loyalty
            ELSE 'Aucune opportunité détectée'
        END                                                 AS primary_action

    FROM opportunities o
)

SELECT
    customer_id,
    full_name,
    customer_segment,
    loyalty_tier,
    preferred_channel,
    country,
    age_group,
    total_bookings,
    avg_ticket_price,
    avg_ancillary,
    total_ticket_rev,
    total_ancillary_rev,
    economy_bookings,
    business_bookings,
    avg_bags,
    bookings_no_seat,
    intl_bookings,
    intl_no_seat,
    -- Opportunités détectées
    upsell_class,
    upsell_baggage,
    upsell_seat,
    upsell_fare_family,
    upsell_ancillary,
    crosssell_loyalty,
    -- Scoring
    upsell_score,
    opportunity_count,
    action_segment,
    primary_action
FROM scored
WHERE opportunity_count > 0          -- ne garder que les clients avec au moins 1 opportunité
ORDER BY upsell_score DESC, total_ticket_rev DESC
