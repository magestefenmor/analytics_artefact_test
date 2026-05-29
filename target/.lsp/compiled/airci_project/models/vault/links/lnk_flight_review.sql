

-- LINK FLIGHT_REVIEW
-- Relation : un avis client est lié à un vol et un client
-- Sources  : hub_flight + hub_customer via stg_reviews
-- Grain    : 1 ligne par avis

SELECT
    SHA256(
        UPPER(TRIM(COALESCE(CAST(r.review_id   AS VARCHAR), 'UNKNOWN')))
        || '||' ||
        UPPER(TRIM(COALESCE(CAST(r.flight_id   AS VARCHAR), 'UNKNOWN')))
        || '||' ||
        UPPER(TRIM(COALESCE(CAST(r.customer_id AS VARCHAR), 'UNKNOWN')))
    )                           AS lnk_flight_review_hk,
    SHA256(UPPER(TRIM(COALESCE(CAST(r.review_id   AS VARCHAR), 'UNKNOWN'))))
                                AS review_bk,
    SHA256(UPPER(TRIM(COALESCE(CAST(r.flight_id   AS VARCHAR), 'UNKNOWN'))))
                                AS flight_hk,
    SHA256(UPPER(TRIM(COALESCE(CAST(r.customer_id AS VARCHAR), 'UNKNOWN'))))
                                AS customer_hk,
    CURRENT_DATE                AS load_date,
    r._source                   AS record_source
FROM "dev"."main_staging"."stg_reviews" r
WHERE r.review_id   IS NOT NULL
  AND r.flight_id   IS NOT NULL
  AND r.customer_id IS NOT NULL