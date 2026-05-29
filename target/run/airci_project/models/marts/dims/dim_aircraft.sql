
  
    
    

    create  table
      "dev"."main_marts"."dim_aircraft__dbt_tmp"
  
    as (
      

-- ================================================================
-- DIM_AIRCRAFT
-- Source  : valeurs distinctes depuis sat_flight_operations (via PIT)
-- Pas de hub_aircraft ni satellite dédié — dimension technique statique
-- Grain   : 1 ligne par type d'appareil
-- ================================================================

WITH aircraft_types AS (
    SELECT DISTINCT sfo.flight_status, pit.flight_hk,
        -- Récupérer l'aircraft_type depuis stg (seule source disponible)
        -- Note : en prod, créer hub_aircraft + sat_aircraft_specs
        NULL AS aircraft_type
    FROM "dev"."main_vault"."pit_flight"             pit
    JOIN "dev"."main_vault"."sat_flight_operations"  sfo
        ON  sfo.sat_flight_operations_hk = pit.sat_flight_operations_hk
    WHERE pit.sat_flight_operations_hk != 'GHOST'
),

-- Source directe depuis stg car pas de hub_aircraft dans ce modèle
types AS (
    SELECT DISTINCT aircraft_type
    FROM "dev"."main_staging"."stg_flights"
    WHERE aircraft_type IS NOT NULL
)

SELECT
    aircraft_type,
    CASE
        WHEN aircraft_type = 'A319'         THEN 'Narrow-body court-courrier'
        WHEN aircraft_type IN ('A320',
             'A320neo')                     THEN 'Narrow-body moyen-courrier'
        WHEN aircraft_type = 'A330-900neo'  THEN 'Wide-body long-courrier'
        ELSE 'Autre'
    END                                                     AS aircraft_family,
    CASE
        WHEN aircraft_type = 'A319'         THEN 122
        WHEN aircraft_type IN ('A320',
             'A320neo')                     THEN 150
        WHEN aircraft_type = 'A330-900neo'  THEN 287
        ELSE NULL
    END                                                     AS typical_seat_capacity,
    CASE WHEN aircraft_type LIKE '%neo%'
         THEN 1 ELSE 0 END                                  AS is_neo_engine,
    CASE
        WHEN aircraft_type = 'A319'         THEN 'Court < 3000km'
        WHEN aircraft_type IN ('A320',
             'A320neo')                     THEN 'Moyen < 5000km'
        WHEN aircraft_type = 'A330-900neo'  THEN 'Long > 5000km'
        ELSE 'Inconnu'
    END                                                     AS range_category
FROM types
    );
  
  