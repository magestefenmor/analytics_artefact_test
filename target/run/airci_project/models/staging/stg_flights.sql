
  
    
    

    create  table
      "dev"."main_staging"."stg_flights__dbt_tmp"
  
    as (
      

SELECT
    flight_id                                               AS flight_id,
    flight_number                                           AS flight_number,
    route_id                                                AS route_id,
    aircraft_type                                           AS aircraft_type,
    CAST(flight_date        AS DATE)                        AS flight_date,
    TRY_CAST(scheduled_departure AS TIMESTAMP)              AS scheduled_departure,
    TRY_CAST(actual_departure    AS TIMESTAMP)              AS actual_departure,
    TRY_CAST(scheduled_arrival   AS TIMESTAMP)              AS scheduled_arrival,
    TRY_CAST(actual_arrival      AS TIMESTAMP)              AS actual_arrival,                                         
    UPPER(TRIM(flight_status))                              AS flight_status,
    CAST(delay_min          AS INTEGER)                     AS delay_min,
    CAST(seat_capacity      AS INTEGER)                     AS seat_capacity,
    CURRENT_TIMESTAMP                                       AS _loaded_at,
    'seed_starter'                                          AS _source
FROM "dev"."main"."flights"
WHERE flight_id IS NOT NULL
    );
  
  