

-- ============================================================
-- 1. STG_FLIGHTS
-- Corrections :
--   - delay_min recalculé depuis actual_arrival (plus fiable)
--   - flight_status normalisé en MAJUSCULES
-- ============================================================

CREATE OR REPLACE TABLE stg_flights AS
SELECT
    CAST(flight_id            AS VARCHAR)   AS flight_id,
    CAST(flight_number        AS VARCHAR)   AS flight_number,
    CAST(route_id             AS VARCHAR)   AS route_id,
    CAST(aircraft_type        AS VARCHAR)   AS aircraft_type,
    TRY_CAST(flight_date      AS DATE)      AS flight_date,
    TRY_CAST(scheduled_departure AS TIMESTAMP) AS scheduled_departure,
    TRY_CAST(actual_departure    AS TIMESTAMP) AS actual_departure,
    TRY_CAST(scheduled_arrival   AS TIMESTAMP) AS scheduled_arrival,
    TRY_CAST(actual_arrival      AS TIMESTAMP) AS actual_arrival,
    UPPER(TRIM(flight_status))              AS flight_status,
    -- delay_min recalculé depuis arrival (departure identique dans la source pour 43 vols)
    CASE
        WHEN TRY_CAST(actual_arrival     AS TIMESTAMP) IS NOT NULL
         AND TRY_CAST(scheduled_arrival  AS TIMESTAMP) IS NOT NULL
        THEN GREATEST(0, DATEDIFF('minute',
                TRY_CAST(scheduled_arrival AS TIMESTAMP),
                TRY_CAST(actual_arrival    AS TIMESTAMP)))
        WHEN TRY_CAST(actual_departure    AS TIMESTAMP) IS NOT NULL
         AND TRY_CAST(scheduled_departure AS TIMESTAMP) IS NOT NULL
        THEN GREATEST(0, DATEDIFF('minute',
                TRY_CAST(scheduled_departure AS TIMESTAMP),
                TRY_CAST(actual_departure    AS TIMESTAMP)))
        ELSE NULL
    END                                     AS delay_min_computed,
    CAST(delay_min            AS INTEGER)   AS delay_min_raw,
    CAST(seat_capacity        AS INTEGER)   AS seat_capacity,
    CURRENT_TIMESTAMP                       AS _loaded_at,
    'starter_dataset'                       AS _source
FROM raw_flights
WHERE flight_id IS NOT NULL;
