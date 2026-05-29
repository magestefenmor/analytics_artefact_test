

-- ================================================================
-- PIT_ROUTE — Point-In-Time Table
-- Hub      : hub_route
-- Satellites couverts :
--   - sat_route_details        (type, distance, durée)
--   - bv_sat_route_profitability (margin, RASK, CASK agrégés)
--
-- Grain    : 1 ligne par (route_hk × snapshot_date)
-- Usage    : analyser la performance d'une route à une date donnée
--            en joignant les deux satellites cohéremment
-- ================================================================

WITH snapshots AS (
    SELECT DISTINCT load_date AS snapshot_date
    FROM "dev"."main_vault"."sat_route_details"
),

routes AS (
    SELECT route_hk FROM "dev"."main_vault"."hub_routes"
),

spine AS (
    SELECT
        r.route_hk,
        s.snapshot_date
    FROM routes r
    CROSS JOIN snapshots s
)

SELECT
    sp.route_hk,
    sp.snapshot_date,

    -- Version active de sat_route_details à snapshot_date
    COALESCE(
        (SELECT srd.sat_route_details_hk
         FROM "dev"."main_vault"."sat_route_details" srd
         WHERE srd.route_hk     = sp.route_hk
           AND srd.load_date   <= sp.snapshot_date
           AND (srd.load_end_date > sp.snapshot_date
                OR srd.load_end_date IS NULL)
         ORDER BY srd.load_date DESC LIMIT 1),
        'GHOST'
    )                                               AS sat_route_details_hk,

    CURRENT_TIMESTAMP                               AS _pit_loaded_at

FROM spine sp