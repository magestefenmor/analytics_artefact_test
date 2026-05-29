

-- SATELLITE FLIGHT_OPERATIONS
-- Source   : snap_flight_operations (dbt snapshot)
-- SCD2     : déclenché si statut change (ex: Scheduled → Delayed)

SELECT
    SHA256(UPPER(TRIM(COALESCE(CAST(flight_id AS VARCHAR), 'UNKNOWN'))))
                                        AS flight_hk,

    SHA256(
        COALESCE(CAST(flight_status       AS VARCHAR), '') ||
        COALESCE(CAST(delay_min           AS VARCHAR), '') ||
        COALESCE(CAST(actual_departure    AS VARCHAR), '') ||
        COALESCE(CAST(actual_arrival      AS VARCHAR), '')
    )                                   AS hash_diff,

    dbt_scd_id                          AS sat_flight_operations_hk,

    -- Attributs
    flight_number,
    route_id,
    aircraft_type,
    flight_date,
    scheduled_departure,
    actual_departure,
    scheduled_arrival,
    actual_arrival,
    flight_status,
    delay_min,
    seat_capacity,

    -- SCD2 metadata
    dbt_valid_from                      AS load_date,
    dbt_valid_to                        AS load_end_date,
    CASE WHEN dbt_valid_to IS NULL
         THEN 1 ELSE 0 END             AS is_current,

    _source                             AS record_source

FROM "dev"."snapshots"."snap_flight_operations"