{{ config(materialized='view') }}

-- ================================================================
-- SEMANTIC — KPIs CLIENT & FIDÉLITÉ
-- Grain   : 1 ligne par client
-- Source  : dim_customers + fact_bookings + fact_loyalty_activity
-- KPIs    : LTV, repeat_rate, no_show_rate, loyalty_redemption_rate
-- ================================================================

WITH customer_bookings AS (
    SELECT
        b.customer_id,
        COUNT(*)                                        AS total_bookings,
        COUNT(CASE WHEN b.is_flown = 1
                   THEN 1 END)                         AS flown_bookings,
        COUNT(CASE WHEN b.is_no_show = 1
                   THEN 1 END)                         AS no_show_bookings,
        COUNT(CASE WHEN b.is_changed = 1
                   THEN 1 END)                         AS changed_bookings,
        SUM(b.ticket_price_usd)                        AS total_ticket_revenue,
        SUM(b.ancillary_revenue_usd)                   AS total_ancillary_revenue,
        SUM(b.ticket_price_usd
            + b.ancillary_revenue_usd)                 AS total_revenue,
        AVG(b.ticket_price_usd)                        AS avg_ticket_price,
        AVG(b.ancillary_revenue_usd)                   AS avg_ancillary,
        MIN(b.booking_date)                            AS first_booking_date,
        MAX(b.booking_date)                            AS last_booking_date,
        AVG(b.booking_lead_time_days)                  AS avg_lead_time_days,
        SUM(b.has_ancillary)                           AS bookings_with_ancillary
    FROM {{ ref('fact_bookings') }} b
    GROUP BY b.customer_id
),

customer_loyalty AS (
    SELECT
        la.customer_id,
        SUM(la.points_earned)                          AS total_points_earned,
        SUM(la.points_redeemed)                        AS total_points_redeemed,
        MAX(la.balance_after)                          AS current_balance,
        SUM(la.is_upgrade)                             AS tier_upgrades,
        SUM(la.is_downgrade)                           AS tier_downgrades,
        SUM(la.is_expiry)                              AS points_expiry_events,
        MAX(la.activity_date)                          AS last_loyalty_event_date
    FROM {{ ref('fact_loyalty_activity') }} la
    GROUP BY la.customer_id
)

SELECT
    -- Profil client
    c.customer_id,
    c.full_name,
    c.customer_segment,
    c.loyalty_tier,
    c.age_group,
    c.country,
    c.preferred_channel,
    c.signup_date,
    c.days_since_signup,

    -- ── KPI 1 : Customer LTV ─────────────────────────────────
    -- Définition : revenu total généré par le client (lifetime)
    COALESCE(b.total_revenue, 0)                        AS customer_ltv_usd,

    -- ── KPI 2 : Fréquence de réservation ─────────────────────
    COALESCE(b.total_bookings, 0)                       AS total_bookings,
    COALESCE(b.flown_bookings, 0)                       AS flown_bookings,
    CASE WHEN COALESCE(b.total_bookings, 0) > 1
         THEN 1 ELSE 0 END                              AS is_repeat_customer,

    -- ── KPI 3 : Taux de no-show ──────────────────────────────
    -- Seuil alerte : > 10% par client = risque yield management
    CASE WHEN COALESCE(b.total_bookings, 0) > 0
         THEN ROUND(COALESCE(b.no_show_bookings, 0)::DOUBLE
                  / b.total_bookings, 4)
         ELSE NULL
    END                                                 AS no_show_rate,

    -- ── KPI 4 : Ancillary Attach Rate client ─────────────────
    CASE WHEN COALESCE(b.total_bookings, 0) > 0
         THEN ROUND(COALESCE(b.bookings_with_ancillary, 0)::DOUBLE
                  / b.total_bookings, 4)
         ELSE NULL
    END                                                 AS ancillary_attach_rate,

    -- ── KPI 5 : Revenus moyens ───────────────────────────────
    COALESCE(b.avg_ticket_price, 0)                     AS avg_ticket_price_usd,
    COALESCE(b.avg_ancillary, 0)                        AS avg_ancillary_usd,
    COALESCE(b.avg_lead_time_days, 0)                   AS avg_lead_time_days,

    -- ── KPI 6 : Loyalty redemption rate ──────────────────────
    -- Définition : points_redeemed / points_earned
    -- Faible = programme peu attractif ou client qui décroche
    COALESCE(l.total_points_earned, 0)                  AS total_points_earned,
    COALESCE(l.total_points_redeemed, 0)                AS total_points_redeemed,
    COALESCE(l.current_balance, 0)                      AS loyalty_balance,
    CASE WHEN COALESCE(l.total_points_earned, 0) > 0
         THEN ROUND(COALESCE(l.total_points_redeemed, 0)::DOUBLE
                  / l.total_points_earned, 4)
         ELSE NULL
    END                                                 AS loyalty_redemption_rate,

    -- ── KPI 7 : Tier churn ───────────────────────────────────
    COALESCE(l.tier_upgrades, 0)                        AS tier_upgrades,
    COALESCE(l.tier_downgrades, 0)                      AS tier_downgrades,
    COALESCE(l.points_expiry_events, 0)                 AS points_expiry_events,

    -- ── KPI 8 : Inactivité ───────────────────────────────────
    b.last_booking_date,
    b.first_booking_date,
    DATEDIFF('day', b.last_booking_date,
        DATE '2025-12-31')                              AS days_since_last_booking,
    l.last_loyalty_event_date

FROM {{ ref('dim_customers') }}          c
LEFT JOIN customer_bookings              b ON b.customer_id = c.customer_id
LEFT JOIN customer_loyalty               l ON l.customer_id = c.customer_id
