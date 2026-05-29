{{ config(materialized='table') }}

SELECT
    booking_id                                              AS booking_id,
    CAST(booking_date       AS DATE)                        AS booking_date,
    customer_id                                             AS customer_id,
    flight_id                                               AS flight_id,
    TRIM(booking_channel)                                   AS booking_channel,
    UPPER(TRIM(fare_class))                                 AS fare_class,
    TRIM(fare_family)                                       AS fare_family,
    {{ clean_numeric('ticket_price_usd') }}                 AS ticket_price_usd,
    {{ clean_numeric('ancillary_revenue_usd') }}            AS ancillary_revenue_usd,
    CAST(bags_count         AS INTEGER)                     AS bags_count,
    CAST(seat_selection_flag AS INTEGER)                    AS seat_selection_flag,
    TRIM(booking_status)                                    AS booking_status,
    CURRENT_TIMESTAMP                                       AS _loaded_at,
    'seed_starter'                                          AS _source
FROM {{ ref('bookings') }}
WHERE booking_id IS NOT NULL
