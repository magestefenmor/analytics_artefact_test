
  
    
    

    create  table
      "dev"."main_vault"."pit_customer__dbt_tmp"
  
    as (
      

-- ================================================================
-- PIT_CUSTOMER — Point-In-Time Table
-- Hub      : hub_customer
-- Satellites couverts :
--   - sat_customer_profile  (données démographiques)
--   - sat_customer_loyalty  (événements loyalty)
--   - bv_sat_customer_value (LTV, fréquence, inactivité)
--
-- Grain    : 1 ligne par (customer_hk × snapshot_date)
-- Usage    : reconstituer le profil complet d'un client
--            à n'importe quelle date historique en 1 jointure
-- ================================================================

WITH snapshots AS (
    SELECT DISTINCT load_date AS snapshot_date
    FROM "dev"."main_vault"."sat_customer_profile"
    UNION
    SELECT DISTINCT load_date
    FROM "dev"."main_vault"."sat_customer_loyalty"
),

customers AS (
    SELECT customer_hk FROM "dev"."main_vault"."hub_customer"
),

spine AS (
    SELECT
        c.customer_hk,
        s.snapshot_date
    FROM customers c
    CROSS JOIN snapshots s
)

SELECT
    sp.customer_hk,
    sp.snapshot_date,

    -- Version active de sat_customer_profile à snapshot_date
    COALESCE(
        (SELECT scp.sat_customer_profile_hk
         FROM "dev"."main_vault"."sat_customer_profile" scp
         WHERE scp.customer_hk  = sp.customer_hk
           AND scp.load_date   <= sp.snapshot_date
           AND (scp.load_end_date > sp.snapshot_date
                OR scp.load_end_date IS NULL)
         ORDER BY scp.load_date DESC LIMIT 1),
        'GHOST'
    )                                               AS sat_customer_profile_hk,

    -- Version active de sat_customer_loyalty à snapshot_date
    -- Note : grain événement — on prend le dernier événement connu
    COALESCE(
        (SELECT scl.sat_customer_loyalty_hk
         FROM "dev"."main_vault"."sat_customer_loyalty" scl
         WHERE scl.customer_hk  = sp.customer_hk
           AND scl.load_date   <= sp.snapshot_date
           AND (scl.load_end_date > sp.snapshot_date
                OR scl.load_end_date IS NULL)
         ORDER BY scl.load_date DESC LIMIT 1),
        'GHOST'
    )                                               AS sat_customer_loyalty_hk,

    CURRENT_TIMESTAMP                               AS _pit_loaded_at

FROM spine sp
    );
  
  