{{ config(materialized='table') }}

-- ================================================================
-- FACT_FLIGHT_COSTS
-- Source  : Business Vault
--   pit_flight → sat_flight_costs (version courante)
-- Grain   : 1 ligne par vol
-- ================================================================

SELECT
    -- Clés
    hf.flight_bk                                            AS flight_id,
    hf.flight_hk,

    -- Coûts (sat_flight_costs via PIT)
    sfc.fuel_cost_usd,
    sfc.crew_cost_usd,
    sfc.airport_handling_usd,
    sfc.maintenance_usd,
    sfc.total_cost_usd,
    sfc.cost_per_seat_usd,

    -- Parts relatives
    CASE WHEN sfc.total_cost_usd > 0
         THEN ROUND(sfc.fuel_cost_usd
                  / sfc.total_cost_usd * 100, 1)
         ELSE NULL END                                      AS fuel_cost_pct,
    CASE WHEN sfc.total_cost_usd > 0
         THEN ROUND(sfc.crew_cost_usd
                  / sfc.total_cost_usd * 100, 1)
         ELSE NULL END                                      AS crew_cost_pct,
    CASE WHEN sfc.total_cost_usd > 0
         THEN ROUND(sfc.airport_handling_usd
                  / sfc.total_cost_usd * 100, 1)
         ELSE NULL END                                      AS handling_cost_pct,
    CASE WHEN sfc.total_cost_usd > 0
         THEN ROUND(sfc.maintenance_usd
                  / sfc.total_cost_usd * 100, 1)
         ELSE NULL END                                      AS maintenance_cost_pct,

    pit.snapshot_date

FROM {{ ref('hub_flight') }}                    hf

-- PIT flight
JOIN {{ ref('pit_flight') }}                    pit
    ON  pit.flight_hk     = hf.flight_hk
    AND pit.snapshot_date = (
        SELECT MAX(p.snapshot_date)
        FROM {{ ref('pit_flight') }} p
        WHERE p.flight_hk = hf.flight_hk
    )

-- Satellite coûts via PIT
JOIN {{ ref('sat_flight_costs') }}              sfc
    ON  sfc.sat_flight_costs_hk = pit.sat_flight_costs_hk
    AND pit.sat_flight_costs_hk != 'GHOST'
