-- ============================================================
-- 2. STG_BOOKINGS
-- Corrections :
--   - total_revenue_usd = ticket + ancillary (calculé)
--   - has_ancillary flag (0/1)
--   - is_active_booking flag : Confirmed ou Flown = 1
-- ============================================================

CREATE OR REPLACE TABLE stg_bookings AS
SELECT
    CAST(booking_id           AS VARCHAR)   AS booking_id,
    TRY_CAST(booking_date     AS DATE)      AS booking_date,
    CAST(customer_id          AS VARCHAR)   AS customer_id,
    CAST(flight_id            AS VARCHAR)   AS flight_id,
    TRIM(booking_channel)                   AS booking_channel,
    UPPER(TRIM(fare_class))                 AS fare_class,
    TRIM(fare_family)                       AS fare_family,
    CAST(ticket_price_usd     AS DOUBLE)    AS ticket_price_usd,
    CAST(ancillary_revenue_usd AS DOUBLE)   AS ancillary_revenue_usd,
    COALESCE(CAST(ticket_price_usd     AS DOUBLE), 0)
  + COALESCE(CAST(ancillary_revenue_usd AS DOUBLE), 0)
                                            AS total_revenue_usd,
    CAST(bags_count           AS INTEGER)   AS bags_count,
    CAST(seat_selection_flag  AS INTEGER)   AS seat_selection_flag,
    CASE WHEN CAST(ancillary_revenue_usd AS DOUBLE) > 0
         THEN 1 ELSE 0 END                 AS has_ancillary,
    TRIM(booking_status)                    AS booking_status,
    CASE WHEN UPPER(TRIM(booking_status)) IN ('CONFIRMED', 'FLOWN')
         THEN 1 ELSE 0 END                 AS is_active_booking,
    CURRENT_TIMESTAMP                       AS _loaded_at,
    'starter_dataset'                       AS _source
FROM raw_bookings
WHERE booking_id IS NOT NULL;
