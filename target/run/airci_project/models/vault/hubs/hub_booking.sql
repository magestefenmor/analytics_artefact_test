
  
    
    

    create  table
      "dev"."main_vault"."hub_booking__dbt_tmp"
  
    as (
      

-- HUB BOOKING
-- Clé métier : booking_id
-- Source     : stg_bookings
-- Grain      : 1 ligne par réservation unique

SELECT
    SHA256(UPPER(TRIM(COALESCE(CAST(booking_id AS VARCHAR), 'UNKNOWN'))))
                            AS booking_hk,
    booking_id              AS booking_bk,
    CURRENT_DATE            AS load_date,
    _source                 AS record_source
FROM "dev"."main_staging"."stg_bookings"
WHERE booking_id IS NOT NULL
    );
  
  