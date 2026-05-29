
  
    
    

    create  table
      "dev"."main_vault"."pit_flight__dbt_tmp"
  
    as (
      

-- ================================================================
-- PIT_FLIGHT — Point-In-Time Table
-- Hub      : hub_flight
-- Satellites couverts :
--   - sat_flight_operations   (statut, retard, capacité)
--   - sat_flight_costs        (coûts opérationnels)
--   - sat_flight_sentiment    (reviews + plaintes)
--   - bv_sat_flight_performance (KPIs calculés)
--
-- Grain    : 1 ligne par (flight_hk × snapshot_date)
-- Usage    : garantit la cohérence temporelle quand on joint
--            plusieurs satellites d'un même vol à une date donnée
-- ================================================================

WITH snapshots AS (
    -- Dates de snapshot = toutes les dates de chargement connues
    -- dans tous les satellites du hub_flight
    SELECT DISTINCT load_date AS snapshot_date
    FROM "dev"."main_vault"."sat_flight_operations"
    UNION
    SELECT DISTINCT load_date
    FROM "dev"."main_vault"."sat_flight_costs"
    UNION
    SELECT DISTINCT load_date
    FROM "dev"."main_vault"."sat_flight_sentiment"
),

flights AS (
    SELECT flight_hk FROM "dev"."main_vault"."hub_flight"
),

-- Produit cartésien hub × snapshots
spine AS (
    SELECT
        f.flight_hk,
        s.snapshot_date
    FROM flights f
    CROSS JOIN snapshots s
)

SELECT
    sp.flight_hk,
    sp.snapshot_date,

    -- Hash key actif pour sat_flight_operations à snapshot_date
    -- NULL si le satellite n'existait pas encore à cette date
    COALESCE(
        (SELECT sfo.sat_flight_operations_hk
         FROM "dev"."main_vault"."sat_flight_operations" sfo
         WHERE sfo.flight_hk    = sp.flight_hk
           AND sfo.load_date   <= sp.snapshot_date
           AND (sfo.load_end_date > sp.snapshot_date
                OR sfo.load_end_date IS NULL)
         ORDER BY sfo.load_date DESC LIMIT 1),
        'GHOST'
    )                                               AS sat_flight_operations_hk,

    -- Hash key actif pour sat_flight_costs à snapshot_date
    COALESCE(
        (SELECT sfc.sat_flight_costs_hk
         FROM "dev"."main_vault"."sat_flight_costs" sfc
         WHERE sfc.flight_hk    = sp.flight_hk
           AND sfc.load_date   <= sp.snapshot_date
           AND (sfc.load_end_date > sp.snapshot_date
                OR sfc.load_end_date IS NULL)
         ORDER BY sfc.load_date DESC LIMIT 1),
        'GHOST'
    )                                               AS sat_flight_costs_hk,

    -- Hash key actif pour sat_flight_sentiment à snapshot_date
    COALESCE(
        (SELECT sfs.sat_flight_sentiment_hk
         FROM "dev"."main_vault"."sat_flight_sentiment" sfs
         WHERE sfs.flight_hk    = sp.flight_hk
           AND sfs.load_date   <= sp.snapshot_date
           AND (sfs.load_end_date > sp.snapshot_date
                OR sfs.load_end_date IS NULL)
         ORDER BY sfs.load_date DESC LIMIT 1),
        'GHOST'
    )                                               AS sat_flight_sentiment_hk,

    CURRENT_TIMESTAMP                               AS _pit_loaded_at

FROM spine sp
    );
  
  