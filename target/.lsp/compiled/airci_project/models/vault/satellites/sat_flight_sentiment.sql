

-- SATELLITE FLIGHT_SENTIMENT
-- Source   : stg_reviews + stg_complaint_logs
-- Pas de snapshot : données non-structurées immuables (avis = événement)
-- Incremental sur sat_flight_sentiment_hk (insert-only)



WITH reviews AS (
    SELECT
        flight_id,
        review_date             AS event_date,
        rating,
        nlp_sentiment,
        CASE UPPER(TRIM(nlp_sentiment))
            WHEN 'POSITIF'  THEN  1
            WHEN 'NEUTRE'   THEN  0
            WHEN 'NÉGATIF'  THEN -1
            WHEN 'NEGATIF'  THEN -1
            ELSE NULL
        END                     AS sentiment_score,
        complaint_category,
        'review'                AS signal_type,
        _source
    FROM "dev"."main_staging"."stg_reviews"
    WHERE flight_id IS NOT NULL
),

complaints AS (
    SELECT
        flight_id,
        complaint_date          AS event_date,
        NULL::DOUBLE            AS rating,
        NULL::VARCHAR           AS nlp_sentiment,
        -1                      AS sentiment_score,
        complaint_type          AS complaint_category,
        'complaint'             AS signal_type,
        _source
    FROM "dev"."main_staging"."stg_complaint_logs"
    WHERE flight_id IS NOT NULL
),

combined AS (
    SELECT * FROM reviews
    UNION ALL
    SELECT * FROM complaints
),

final AS (
    SELECT
        SHA256(UPPER(TRIM(COALESCE(CAST(flight_id AS VARCHAR), 'UNKNOWN'))))
                                AS flight_hk,
        SHA256(
            COALESCE(CAST(flight_id       AS VARCHAR), '') ||
            COALESCE(CAST(event_date      AS VARCHAR), '') ||
            COALESCE(signal_type,         '') ||
            COALESCE(CAST(sentiment_score AS VARCHAR), '')
        )                       AS sat_flight_sentiment_hk,
        event_date,
        rating,
        nlp_sentiment,
        sentiment_score,
        complaint_category,
        signal_type,
        CURRENT_DATE            AS load_date,
        NULL::DATE              AS load_end_date,
        1                       AS is_current,
        _source                 AS record_source
    FROM combined
)

SELECT * FROM final

WHERE sat_flight_sentiment_hk NOT IN (
    SELECT sat_flight_sentiment_hk FROM "dev"."main_vault"."sat_flight_sentiment"
)
