
  
    
    

    create  table
      "dev"."main_vault"."bridge_flight_customer__dbt_tmp"
  
    as (
      

-- ================================================================
-- BRIDGE FLIGHT_CUSTOMER
-- Hubs traversés : hub_flight + hub_customer + hub_booking
-- Links utilisés : lnk_booking
--
-- Rôle : pré-calcule le chemin hub_flight ↔ hub_customer
--        via les réservations. Élimine les jointures multi-niveaux
--        dans les marts et la semantic layer.
--
-- Usage dans le mart :
--   FROM bridge_flight_customer bfc
--   JOIN sat_flight_operations sfo ON sfo.flight_hk = bfc.flight_hk
--   JOIN sat_booking_details   sbd ON sbd.booking_hk = bfc.booking_hk
--   JOIN sat_customer_profile  scp ON scp.customer_hk = bfc.customer_hk
--   → Plus besoin de traverser lnk_booking manuellement
--
-- Grain : 1 ligne par réservation (booking_hk unique)
-- ================================================================

SELECT
    -- Clés de navigation (toutes les hash keys en un seul endroit)
    lb.flight_hk,
    lb.customer_hk,
    lb.booking_hk,

    -- Clés métier (pour lisibilité dans les requêtes ad-hoc)
    hf.flight_bk                                AS flight_id,
    hc.customer_bk                              AS customer_id,
    hb.booking_bk                               AS booking_id,

    -- Clé route (via lnk_flight_route — enrichissement bridge)
    lfr.route_hk,
    hr.route_bk                                 AS route_id,

    -- Date réservation (pour analyses temporelles)
    sbd.booking_date,

    -- Statut réservation (filtre courant dans les marts)
    sbd.booking_status,
    CASE WHEN UPPER(sbd.booking_status) IN ('CONFIRMED','FLOWN')
         THEN 1 ELSE 0 END                      AS is_active_booking,

    -- Revenus pré-joints (évite la jointure sat_booking_details
    -- dans chaque requête analytique)
    sbd.ticket_price_usd,
    sbd.ancillary_revenue_usd,
    sbd.ticket_price_usd
        + sbd.ancillary_revenue_usd             AS total_revenue_usd,
    sbd.fare_class,
    sbd.booking_channel,

    -- Metadata
    CURRENT_DATE                                AS bridge_load_date

FROM "dev"."main_vault"."lnk_booking"               lb

-- Hub flight
JOIN "dev"."main_vault"."hub_flight"                hf
    ON  hf.flight_hk    = lb.flight_hk

-- Hub customer
JOIN "dev"."main_vault"."hub_customer"              hc
    ON  hc.customer_hk  = lb.customer_hk

-- Hub booking
JOIN "dev"."main_vault"."hub_booking"               hb
    ON  hb.booking_hk   = lb.booking_hk

-- Satellite booking (version courante — revenus et statut)
JOIN "dev"."main_vault"."sat_booking_details"       sbd
    ON  sbd.booking_hk  = lb.booking_hk
    AND sbd.is_current  = 1

-- Enrichissement route via lnk_flight_route
LEFT JOIN "dev"."main_vault"."lnk_flight_route"     lfr
    ON  lfr.flight_hk   = lb.flight_hk

-- Hub route
LEFT JOIN "dev"."main_vault"."hub_routes"            hr
    ON  hr.route_hk     = lfr.route_hk
    );
  
  