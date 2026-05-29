

-- SATELLITE BOOKING_DETAILS
-- Source   : snap_bookings (dbt snapshot)
-- SCD2     : déclenché si statut change (Confirmed→Flown/NoShow/Changed)

SELECT
    SHA256(UPPER(TRIM(COALESCE(CAST(booking_id AS VARCHAR), 'UNKNOWN'))))
                                        AS booking_hk,

    SHA256(
        COALESCE(booking_status,           '') ||
        COALESCE(CAST(ticket_price_usd     AS VARCHAR), '') ||
        COALESCE(CAST(ancillary_revenue_usd AS VARCHAR), '') ||
        COALESCE(CAST(bags_count           AS VARCHAR), '') ||
        COALESCE(CAST(seat_selection_flag  AS VARCHAR), '')
    )                                   AS hash_diff,

    dbt_scd_id                          AS sat_booking_details_hk,

    -- Attributs
    booking_date,
    customer_id,
    flight_id,
    booking_channel,
    fare_class,
    fare_family,
    ticket_price_usd,
    ancillary_revenue_usd,
    bags_count,
    seat_selection_flag,
    booking_status,

    -- SCD2 metadata
    dbt_valid_from                      AS load_date,
    dbt_valid_to                        AS load_end_date,
    CASE WHEN dbt_valid_to IS NULL
         THEN 1 ELSE 0 END             AS is_current,

    _source                             AS record_source

FROM "dev"."snapshots"."snap_bookings"