{{ config(materialized='table') }}

-- LINK BOOKING
-- Relation : une réservation lie un client à un vol
-- Sources  : hub_booking + hub_customer + hub_flight via stg_bookings
-- Grain    : 1 ligne par réservation

SELECT
    SHA256(
        UPPER(TRIM(COALESCE(CAST(b.booking_id  AS VARCHAR), 'UNKNOWN')))
        || '||' ||
        UPPER(TRIM(COALESCE(CAST(b.customer_id AS VARCHAR), 'UNKNOWN')))
        || '||' ||
        UPPER(TRIM(COALESCE(CAST(b.flight_id   AS VARCHAR), 'UNKNOWN')))
    )                           AS lnk_booking_hk,
    SHA256(UPPER(TRIM(COALESCE(CAST(b.booking_id  AS VARCHAR), 'UNKNOWN'))))
                                AS booking_hk,
    SHA256(UPPER(TRIM(COALESCE(CAST(b.customer_id AS VARCHAR), 'UNKNOWN'))))
                                AS customer_hk,
    SHA256(UPPER(TRIM(COALESCE(CAST(b.flight_id   AS VARCHAR), 'UNKNOWN'))))
                                AS flight_hk,
    CURRENT_DATE                AS load_date,
    b._source                   AS record_source
FROM {{ ref('stg_bookings') }} b
WHERE b.booking_id  IS NOT NULL
  AND b.customer_id IS NOT NULL
  AND b.flight_id   IS NOT NULL
