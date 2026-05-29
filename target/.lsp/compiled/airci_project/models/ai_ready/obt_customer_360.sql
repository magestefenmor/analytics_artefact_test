

-- ================================================================
-- OBT_CUSTOMER_360 — Vue 360° client
-- Source  : dim_customers + fact_bookings + fact_loyalty_activity
--           + sentiment agrégé par client
-- Grain   : 1 ligne par client — tout agrégé
-- Usage   : segmentation ML, scoring rétention, LLM profiling,
--           Claude API (recommandations personnalisées)
-- ================================================================
WITH most_used_channel AS (
    SELECT
        customer_id,
        booking_channel
    FROM (
        SELECT
            customer_id,
            booking_channel,
            ROW_NUMBER() OVER (
                PARTITION BY customer_id
                ORDER BY COUNT(*) DESC
            ) AS rn
        FROM "dev"."main_marts"."fact_bookings"
        GROUP BY customer_id, booking_channel
    ) t
    WHERE rn = 1
),

most_used_fare AS (
    SELECT
        customer_id,
        fare_class
    FROM (
        SELECT
            customer_id,
            fare_class,
            ROW_NUMBER() OVER (
                PARTITION BY customer_id
                ORDER BY COUNT(*) DESC
            ) AS rn
        FROM "dev"."main_marts"."fact_bookings"
        GROUP BY customer_id, fare_class
    ) t
    WHERE rn = 1
),
booking_stats AS (
    SELECT
        fb.customer_id,
        COUNT(*)                                            AS total_bookings,
        SUM(fb.is_flown)                                    AS flown_bookings,
        SUM(fb.is_no_show)                                  AS no_show_count,
        SUM(fb.is_changed)                                  AS changed_count,
        SUM(fb.is_active_booking)                           AS active_bookings,
        SUM(fb.ticket_price_usd)                            AS total_ticket_revenue,
        SUM(fb.ancillary_revenue_usd)                       AS total_ancillary_revenue,
        SUM(fb.total_revenue_usd)                           AS total_ltv_usd,
        AVG(fb.ticket_price_usd)                            AS avg_ticket_price,
        AVG(fb.ancillary_revenue_usd)                       AS avg_ancillary,
        SUM(fb.has_ancillary)                               AS bookings_with_ancillary,
        AVG(fb.booking_lead_time_days)                      AS avg_lead_time_days,
        MIN(fb.booking_date)                                AS first_booking_date,
        MAX(fb.booking_date)                                AS last_booking_date,
  
        -- Destinations distinctes
        COUNT(DISTINCT fb.route_id)                         AS distinct_routes_flown
    FROM "dev"."main_marts"."fact_bookings" fb
    GROUP BY fb.customer_id
),

loyalty_stats AS (
    SELECT
        fla.customer_id,
        SUM(fla.points_earned)                              AS total_points_earned,
        SUM(fla.points_redeemed)                            AS total_points_redeemed,
        MAX(fla.balance_after)                              AS current_loyalty_balance,
        SUM(fla.is_upgrade)                                 AS tier_upgrades,
        SUM(fla.is_downgrade)                               AS tier_downgrades,
        SUM(fla.is_expiry)                                  AS points_expiry_events,
        MAX(fla.activity_date)                              AS last_loyalty_event_date,
        COUNT(*)                                            AS total_loyalty_events
    FROM "dev"."main_marts"."fact_loyalty_activity" fla
    GROUP BY fla.customer_id
),

sentiment_stats AS (
    -- Sentiment moyen des vols pris par ce client
    SELECT
        fb.customer_id,
        AVG(ff.avg_sentiment_score)                         AS avg_sentiment_score,
        AVG(ff.avg_rating)                                  AS avg_flight_rating,
        SUM(ff.sentiment_signal_count)                      AS total_sentiment_signals
    FROM "dev"."main_marts"."fact_bookings"     fb
    JOIN "dev"."main_ai_ready"."obt_flight_full"   ff
        ON  ff.flight_id = fb.flight_id
    WHERE fb.is_flown = 1
    GROUP BY fb.customer_id
)

SELECT

    -- ── IDENTITÉ ─────────────────────────────────────────────
    dc.customer_id,
    dc.customer_hk,
    dc.full_name,
    dc.gender,
    dc.birth_date,
    dc.age,
    dc.age_group,
    dc.country,
    dc.city,
    dc.customer_segment,
    dc.loyalty_tier,
    dc.signup_date,
    dc.days_since_signup,
    dc.preferred_channel,

    -- ── COMPORTEMENT RÉSERVATION ─────────────────────────────
    COALESCE(b.total_bookings, 0)                           AS total_bookings,
    COALESCE(b.flown_bookings, 0)                           AS flown_bookings,
    COALESCE(b.no_show_count, 0)                            AS no_show_count,
    COALESCE(b.changed_count, 0)                            AS changed_count,
    COALESCE(b.distinct_routes_flown, 0)                    AS distinct_routes_flown,
    b.first_booking_date,
    b.last_booking_date,
    ch.booking_channel                                      AS preferred_booking_channel,
    fa.fare_class                                               AS preferred_fare_class,
    COALESCE(b.avg_lead_time_days, 0)                       AS avg_lead_time_days,

    -- ── VALEUR FINANCIÈRE ─────────────────────────────────────
    COALESCE(b.total_ltv_usd, 0)                            AS total_ltv_usd,
    COALESCE(b.total_ticket_revenue, 0)                     AS total_ticket_revenue,
    COALESCE(b.total_ancillary_revenue, 0)                  AS total_ancillary_revenue,
    COALESCE(b.avg_ticket_price, 0)                         AS avg_ticket_price_usd,
    COALESCE(b.avg_ancillary, 0)                            AS avg_ancillary_usd,

    -- ── KPIs CALCULÉS ────────────────────────────────────────
    CASE WHEN COALESCE(b.total_bookings, 0) > 0
         THEN ROUND(CAST(b.no_show_count AS DOUBLE) / b.total_bookings, 4)
         ELSE NULL END                                       AS no_show_rate,

    CASE WHEN COALESCE(b.total_bookings, 0) > 0
         THEN ROUND(b.bookings_with_ancillary::DOUBLE
                  / b.total_bookings, 4)
         ELSE NULL END                                       AS ancillary_attach_rate,

    CASE WHEN COALESCE(b.total_bookings, 0) > 1
         THEN 1 ELSE 0 END                                   AS is_repeat_customer,

    DATEDIFF('day', b.last_booking_date,
        DATE '2025-12-31')                                   AS days_since_last_booking,

    -- ── LOYALTY ──────────────────────────────────────────────
    COALESCE(l.total_points_earned, 0)                      AS total_points_earned,
    COALESCE(l.total_points_redeemed, 0)                    AS total_points_redeemed,
    COALESCE(l.current_loyalty_balance, 0)                  AS loyalty_balance,
    COALESCE(l.tier_upgrades, 0)                            AS tier_upgrades,
    COALESCE(l.tier_downgrades, 0)                          AS tier_downgrades,
    COALESCE(l.points_expiry_events, 0)                     AS points_expiry_events,
    l.last_loyalty_event_date,

    CASE WHEN COALESCE(l.total_points_earned, 0) > 0
         THEN ROUND(l.total_points_redeemed::DOUBLE
                  / l.total_points_earned, 4)
         ELSE NULL END                                       AS loyalty_redemption_rate,

    -- ── SENTIMENT ────────────────────────────────────────────
    s.avg_sentiment_score,
    s.avg_flight_rating,
    COALESCE(s.total_sentiment_signals, 0)                  AS sentiment_signal_count,

    -- ── LABELS ML ────────────────────────────────────────────
    CASE
        WHEN COALESCE(b.total_bookings, 0) = 0    THEN 'No booking'
        WHEN COALESCE(b.total_bookings, 0) = 1    THEN 'One-timer'
        WHEN COALESCE(b.total_bookings, 0) <= 3   THEN 'Occasionnel'
        WHEN COALESCE(b.total_bookings, 0) <= 6   THEN 'Régulier'
        ELSE 'Très fidèle'
    END                                                     AS frequency_label,

    CASE
        WHEN COALESCE(b.total_ltv_usd, 0) >= 2000 THEN 'High-value'
        WHEN COALESCE(b.total_ltv_usd, 0) >= 800  THEN 'Mid-value'
        WHEN COALESCE(b.total_ltv_usd, 0) > 0     THEN 'Low-value'
        ELSE 'No revenue'
    END                                                     AS value_label,

    CASE
        WHEN b.last_booking_date IS NULL THEN 'Jamais réservé'
        WHEN DATEDIFF('day', b.last_booking_date, DATE '2025-12-31') <= 90
             THEN 'Actif'
        WHEN DATEDIFF('day', b.last_booking_date, DATE '2025-12-31') <= 180
             THEN 'En risque'
        ELSE 'Dormant'
    END                                                     AS recency_label,

    -- ── METADATA ─────────────────────────────────────────────
    dc.snapshot_date                                        AS _vault_snapshot_date,
    CURRENT_TIMESTAMP                                       AS _obt_loaded_at

FROM "dev"."main_marts"."dim_customers"             dc
LEFT JOIN booking_stats                     b  ON b.customer_id  = dc.customer_id
LEFT JOIN loyalty_stats                     l  ON l.customer_id  = dc.customer_id

LEFT JOIN most_used_channel ch 
    ON ch.customer_id = dc.customer_id

LEFT JOIN most_used_fare fa 
    ON fa.customer_id = dc.customer_id
LEFT JOIN sentiment_stats                   s  ON s.customer_id  = dc.customer_id