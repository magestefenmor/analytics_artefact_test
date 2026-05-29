

-- ================================================================
-- BRIDGE ROUTE_PERFORMANCE
-- Hubs traversés : hub_route + hub_flight + hub_airport (×2)
-- Links utilisés : lnk_flight_route
--
-- Rôle : pré-calcule le chemin hub_route ↔ hub_flight ↔ aéroports.
--        Permet d'analyser la performance réseau complet sans
--        traverser 4 hubs et 2 links à chaque requête.
--
-- Usage dans le mart / semantic :
--   FROM bridge_route_performance brp
--   JOIN sat_flight_operations sfo ON sfo.flight_hk = brp.flight_hk
--   JOIN sat_flight_costs      sfc ON sfc.flight_hk = brp.flight_hk
--   → Analyse revenu + coût + retard par route + aéroports en 1 bloc
--
-- Grain : 1 ligne par vol (flight_hk unique par route)
-- ================================================================

SELECT
    -- Clés de navigation
    hr.route_hk,
    hf.flight_hk,
    hao.airport_hk                              AS origin_airport_hk,
    had.airport_hk                              AS destination_airport_hk,

    -- Clés métier
    hr.route_bk                                 AS route_id,
    hf.flight_bk                                AS flight_id,
    hao.airport_bk                              AS origin_airport_code,
    had.airport_bk                              AS destination_airport_code,

    -- Attributs route pré-joints
    srd.route_label,
    srd.route_type,
    srd.distance_km,
    srd.block_time_min,

    -- Attributs aéroport origine pré-joints
    sao.city                                    AS origin_city,
    sao.country                                 AS origin_country,
  

    -- Attributs aéroport destination pré-joints
    sad.city                                    AS destination_city,
    sad.country                                 AS destination_country,
   

    -- Date du vol (pour agrégations temporelles)
    CAST(sfo.scheduled_departure AS DATE)        AS flight_date,

    -- Opérations pré-joints (évite sat_flight_operations dans chaque query)
    sfo.flight_status,
    sfo.delay_min,
    sfo.seat_capacity,
    CASE WHEN sfo.flight_status = 'ON TIME'  THEN 1 ELSE 0 END AS is_on_time,
    CASE WHEN sfo.flight_status = 'DELAYED'  THEN 1 ELSE 0 END AS is_delayed,
    CASE WHEN sfo.flight_status = 'CANCELLED'THEN 1 ELSE 0 END AS is_cancelled,

    -- Metadata
    CURRENT_DATE                                AS bridge_load_date

FROM "dev"."main_vault"."lnk_flight_route"          lfr

-- Hub route
JOIN "dev"."main_vault"."hub_routes"                 hr
    ON  hr.route_hk     = lfr.route_hk

-- Hub flight
JOIN "dev"."main_vault"."hub_flight"                hf
    ON  hf.flight_hk    = lfr.flight_hk

-- Satellite route (version courante)
JOIN "dev"."main_vault"."sat_route_details"         srd
    ON  srd.route_hk    = hr.route_hk
    AND srd.is_current  = 1

-- Satellite opérations vol (version courante)
JOIN "dev"."main_vault"."sat_flight_operations"     sfo
    ON  sfo.flight_hk   = hf.flight_hk
    AND sfo.is_current  = 1

-- Hub aéroport origine
LEFT JOIN "dev"."main_vault"."hub_airports"          hao
    ON  hao.airport_bk  = srd.origin_airport_code

-- Satellite aéroport origine
LEFT JOIN "dev"."main_vault"."sat_airport_details"  sao
    ON  sao.airport_hk  = hao.airport_hk
    AND sao.is_current  = 1

-- Hub aéroport destination
LEFT JOIN "dev"."main_vault"."hub_airports"          had
    ON  had.airport_bk  = srd.destination_airport_code

-- Satellite aéroport destination
LEFT JOIN "dev"."main_vault"."sat_airport_details"  sad
    ON  sad.airport_hk  = had.airport_hk
    AND sad.is_current  = 1