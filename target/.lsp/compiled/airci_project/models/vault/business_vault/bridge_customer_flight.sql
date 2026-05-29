

-- ================================================================
-- BRIDGE_CUSTOMER_FLIGHT
-- Grain    : 1 ligne par (customer × booking × flight × route)
-- Chemin   : hub_customer
--              → lnk_booking → hub_booking → hub_flight
--              → lnk_flight_route → hub_route
--
-- Usage    : sem_kpis_customer et dim_customers lisent ce bridge
--            pour agréger tous les vols d'un client sans
--            traverser le vault manuellement.
--            Optimisé pour les analyses comportement client.
--
-- Clé primaire : customer_hk (agrégeable au niveau client)
-- Différence vs bridge_flight_booking :
--   → grain différent (client vs vol)
--   → LEFT JOIN sur les vols (client sans vol = conservé)
-- ================================================================

SELECT
    -- Clés hub
    hc.customer_hk,
    hc.customer_bk                                  AS customer_id,
    hb.booking_hk,
    hb.booking_bk                                   AS booking_id,
    hf.flight_hk,
    hf.flight_bk                                    AS flight_id,
    hr.route_hk,
    hr.route_bk                                     AS route_id,

    -- Clés des links
    lb.lnk_booking_hk,
    lfr.lnk_flight_route_hk,

    -- Indique si le client a au moins un vol associé
    CASE WHEN hf.flight_hk IS NOT NULL
         THEN 1 ELSE 0 END                          AS has_flight,

    -- Indique si le client a au moins une réservation
    CASE WHEN hb.booking_hk IS NOT NULL
         THEN 1 ELSE 0 END                          AS has_booking,

    CURRENT_DATE                                    AS load_date,
    'bridge_customer_flight'                        AS record_source

FROM "dev"."main_vault"."hub_customer"          hc
-- Réservations du client
LEFT JOIN "dev"."main_vault"."lnk_booking"      lb  ON lb.customer_hk    = hc.customer_hk
LEFT JOIN "dev"."main_vault"."hub_booking"      hb  ON hb.booking_hk     = lb.booking_hk
-- Vol de la réservation
LEFT JOIN "dev"."main_vault"."hub_flight"       hf  ON hf.flight_hk      = lb.flight_hk
-- Route du vol
LEFT JOIN "dev"."main_vault"."lnk_flight_route" lfr ON lfr.flight_hk     = hf.flight_hk
LEFT JOIN "dev"."main_vault"."hub_routes"        hr  ON hr.route_hk        = lfr.route_hk