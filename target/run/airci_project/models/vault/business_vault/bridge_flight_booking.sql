
  
    
    

    create  table
      "dev"."main_vault"."bridge_flight_booking__dbt_tmp"
  
    as (
      

-- ================================================================
-- BRIDGE_FLIGHT_BOOKING
-- Grain    : 1 ligne par (flight × booking × customer)
-- Chemin   : hub_flight
--              → lnk_flight_route → hub_route
--              → lnk_booking → hub_booking → hub_customer
--
-- Usage    : fact_flights lit ce bridge au lieu de traverser
--            5 liens et hubs manuellement.
--            Optimisé pour les analyses revenue par vol.
--
-- Clé primaire : flight_hk (agrégeable au niveau vol)
-- ================================================================

SELECT
    -- Clés hub
    hf.flight_hk,
    hf.flight_bk                                    AS flight_id,
    hc.customer_hk,
    hc.customer_bk                                  AS customer_id,
    hb.booking_hk,
    hb.booking_bk                                   AS booking_id,
    hr.route_hk,
    hr.route_bk                                     AS route_id,

    -- Clés des links (traçabilité)
    lb.lnk_booking_hk,
    lfr.lnk_flight_route_hk,

    -- Record source
    CURRENT_DATE                                    AS load_date,
    'bridge_flight_booking'                         AS record_source

FROM "dev"."main_vault"."hub_flight"            hf
-- Route du vol
JOIN "dev"."main_vault"."lnk_flight_route"      lfr ON lfr.flight_hk    = hf.flight_hk
JOIN "dev"."main_vault"."hub_routes"             hr  ON hr.route_hk       = lfr.route_hk
-- Réservations sur ce vol
LEFT JOIN "dev"."main_vault"."lnk_booking"      lb  ON lb.flight_hk      = hf.flight_hk
LEFT JOIN "dev"."main_vault"."hub_booking"      hb  ON hb.booking_hk     = lb.booking_hk
LEFT JOIN "dev"."main_vault"."hub_customer"     hc  ON hc.customer_hk    = lb.customer_hk
    );
  
  