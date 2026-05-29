{{ config(materialized='table') }}

SELECT
    flight_id                                             AS flight_id,
    route_id                                              AS route_id,
    TRIM(aircraft_type)                                   AS aircraft_type,

    {{ clean_numeric('fuel_cost_usd') }}                  AS fuel_cost_usd,
    {{ clean_numeric('crew_cost_usd') }}                  AS crew_cost_usd,
    {{ clean_numeric('airport_handling_usd') }}           AS airport_handling_usd,
    {{ clean_numeric('maintenance_usd') }}                AS maintenance_usd,
    {{ clean_numeric('total_cost_usd') }}                 AS total_cost_usd,
    {{ clean_numeric('cost_per_seat_usd') }}              AS cost_per_seat_usd,

    CURRENT_TIMESTAMP                                     AS _loaded_at,
    'seed_partie1'                                        AS _source

FROM {{ ref('flightCosts') }}

WHERE flight_id IS NOT NULL