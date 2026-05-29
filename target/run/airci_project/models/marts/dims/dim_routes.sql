
  
    
    

    create  table
      "dev"."main_marts"."dim_routes__dbt_tmp"
  
    as (
      

-- ================================================================
-- DIM_ROUTES
-- Source  : Business Vault
--   hub_route + pit_route + sat_route_details
--   + sat_airport_details pour enrichissement O&D
-- Grain   : 1 ligne par route (version courante)
-- ================================================================

SELECT
    hr.route_bk                                             AS route_id,
    hr.route_hk,

    -- Attributs route (sat_route_details via PIT)
    srd.origin_airport_code,
    srd.destination_airport_code,
    srd.route_label,
    srd.route_type,
    srd.distance_km,
    srd.block_time_min,

    -- Enrichissement aéroport origine (sat_airport_details direct)
    sao.city                                                AS origin_city,
    sao.country                                             AS origin_country,

    -- Enrichissement aéroport destination
    sad.city                                                AS destination_city,
    sad.country                                             AS destination_country,

    -- Flag retour symétrique
    CASE WHEN EXISTS (
        SELECT 1 FROM "dev"."main_vault"."hub_routes" hr2
        JOIN "dev"."main_vault"."sat_route_details" srd2
            ON  srd2.route_hk   = hr2.route_hk
            AND srd2.is_current = 1
        WHERE srd2.origin_airport_code      = srd.destination_airport_code
          AND srd2.destination_airport_code = srd.origin_airport_code
    ) THEN 1 ELSE 0 END                                     AS has_return_route,

    srd.load_date                                           AS valid_from,
    pit.snapshot_date

FROM "dev"."main_vault"."hub_routes"                     hr

JOIN "dev"."main_vault"."pit_route"                     pit
    ON  pit.route_hk      = hr.route_hk
    AND pit.snapshot_date = (
        SELECT MAX(p.snapshot_date)
        FROM "dev"."main_vault"."pit_route" p
        WHERE p.route_hk = hr.route_hk
    )

JOIN "dev"."main_vault"."sat_route_details"             srd
    ON  srd.sat_route_details_hk = pit.sat_route_details_hk
    AND pit.sat_route_details_hk != 'GHOST'

-- Aéroport origine (sat direct — hub_airports n'a pas de PIT)
LEFT JOIN "dev"."main_vault"."hub_airports"              hao
    ON  hao.airport_bk = srd.origin_airport_code
LEFT JOIN "dev"."main_vault"."sat_airport_details"      sao
    ON  sao.airport_hk = hao.airport_hk
    AND sao.is_current = 1

-- Aéroport destination
LEFT JOIN "dev"."main_vault"."hub_airports"              had
    ON  had.airport_bk = srd.destination_airport_code
LEFT JOIN "dev"."main_vault"."sat_airport_details"      sad
    ON  sad.airport_hk = had.airport_hk
    AND sad.is_current = 1
    );
  
  