{{ config(materialized='table') }}

SELECT
    review_id                                               AS review_id,
    customer_id                                             AS customer_id,
    flight_id                                               AS flight_id,
    route_id                                                AS route_id,
    TRY_CAST(review_date    AS DATE)                        AS review_date,
    CAST(rating_1_5         AS INTEGER)                     AS rating,
    TRIM(review_text)                                       AS review_text,
    TRIM(nlp_sentiment)                                     AS nlp_sentiment,
    TRIM(complaint_category)                                AS complaint_category,
    UPPER(TRIM(language))                                   AS language,
    linked_booking_id                                       AS booking_id,
    CURRENT_TIMESTAMP                                       AS _loaded_at,
    'seed_partie1'                                          AS _source
FROM {{ ref('customerReviews') }}
WHERE review_id IS NOT NULL
