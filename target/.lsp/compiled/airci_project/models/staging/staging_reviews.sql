-- ============================================================
-- 8. STG_REVIEWS
-- Corrections :
--   - nlp_sentiment en français (Positif/Neutre/Négatif)
--     → sentiment_score normalisé : 1 / 0 / -1
--   - rating_1_5 renommé rating
-- ============================================================

CREATE OR REPLACE TABLE stg_reviews AS
SELECT
    CAST(review_id          AS VARCHAR)  AS review_id,
    CAST(customer_id        AS VARCHAR)  AS customer_id,
    CAST(flight_id          AS VARCHAR)  AS flight_id,
    TRY_CAST(review_date    AS DATE)     AS review_date,
    CAST(rating_1_5         AS DOUBLE)   AS rating,
    TRIM(nlp_sentiment)                  AS nlp_sentiment,
    TRIM(complaint_category)             AS complaint_category,
    UPPER(TRIM(language))                AS language,
    TRIM(review_text)                    AS review_text,
    CASE UPPER(TRIM(nlp_sentiment))
        WHEN 'POSITIF'  THEN  1
        WHEN 'NEUTRE'   THEN  0
        WHEN 'NÉGATIF'  THEN -1
        WHEN 'NEGATIF'  THEN -1
        ELSE NULL
    END                                  AS sentiment_score,
    CURRENT_TIMESTAMP                    AS _loaded_at,
    'partie1_unstruct'                   AS _source
FROM raw_reviews
WHERE review_id IS NOT NULL;