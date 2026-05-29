



-- Snapshot des opérations de vol
-- SCD2 déclenché si : statut change (Scheduled → Delayed → Cancelled)
-- Capture l'évolution du statut en temps réel

SELECT
    flight_id,
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
    _source
FROM "dev"."main_staging"."stg_flights"

