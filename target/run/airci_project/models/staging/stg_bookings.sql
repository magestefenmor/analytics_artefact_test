
  
    
    

    create  table
      "dev"."main_staging"."stg_bookings__dbt_tmp"
  
    as (
      

SELECT
    booking_id                                              AS booking_id,
    CAST(booking_date       AS DATE)                        AS booking_date,
    customer_id                                             AS customer_id,
    flight_id                                               AS flight_id,
    TRIM(booking_channel)                                   AS booking_channel,
    UPPER(TRIM(fare_class))                                 AS fare_class,
    TRIM(fare_family)                                       AS fare_family,
    
    TRY_CAST(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(CAST(ticket_price_usd AS VARCHAR)), '$', ''),
                ' ', ''),
            ',', '.'),
        ' ', '')
    AS DOUBLE)
                 AS ticket_price_usd,
    
    TRY_CAST(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(CAST(ancillary_revenue_usd AS VARCHAR)), '$', ''),
                ' ', ''),
            ',', '.'),
        ' ', '')
    AS DOUBLE)
            AS ancillary_revenue_usd,
    CAST(bags_count         AS INTEGER)                     AS bags_count,
    CAST(seat_selection_flag AS INTEGER)                    AS seat_selection_flag,
    TRIM(booking_status)                                    AS booking_status,
    CURRENT_TIMESTAMP                                       AS _loaded_at,
    'seed_starter'                                          AS _source
FROM "dev"."main"."bookings"
WHERE booking_id IS NOT NULL
    );
  
  