
  
    
    

    create  table
      "dev"."main_vault"."sat_flight_costs__dbt_tmp"
  
    as (
      

-- SATELLITE FLIGHT_COSTS
-- Source   : snap_flight_costs (dbt snapshot)
-- SCD2     : déclenché si les coûts sont révisés

SELECT
    SHA256(UPPER(TRIM(COALESCE(CAST(flight_id AS VARCHAR), 'UNKNOWN'))))
                                        AS flight_hk,

    SHA256(
        COALESCE(CAST(fuel_cost_usd        AS VARCHAR), '') ||
        COALESCE(CAST(crew_cost_usd        AS VARCHAR), '') ||
        COALESCE(CAST(airport_handling_usd AS VARCHAR), '') ||
        COALESCE(CAST(maintenance_usd      AS VARCHAR), '') ||
        COALESCE(CAST(total_cost_usd       AS VARCHAR), '')
    )                                   AS hash_diff,

    dbt_scd_id                          AS sat_flight_costs_hk,

    -- Attributs
    fuel_cost_usd,
    crew_cost_usd,
    airport_handling_usd,
    maintenance_usd,
    total_cost_usd,
    cost_per_seat_usd,

    -- SCD2 metadata
    dbt_valid_from                      AS load_date,
    dbt_valid_to                        AS load_end_date,
    CASE WHEN dbt_valid_to IS NULL
         THEN 1 ELSE 0 END             AS is_current,

    _source                             AS record_source

FROM "dev"."snapshots"."snap_flight_costs"
    );
  
  