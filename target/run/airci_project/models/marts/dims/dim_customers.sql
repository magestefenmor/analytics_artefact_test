
  
    
    

    create  table
      "dev"."main_marts"."dim_customers__dbt_tmp"
  
    as (
      

-- ================================================================
-- DIM_CUSTOMERS
-- Source  : Business Vault
--   hub_customer + pit_customer + sat_customer_profile
-- Grain   : 1 ligne par client (version courante)
-- ================================================================

SELECT
    hc.customer_bk                                          AS customer_id,
    hc.customer_hk,

    -- Attributs profil (sat_customer_profile via PIT)
    scp.first_name,
    scp.last_name,
    scp.first_name || ' ' || scp.last_name                 AS full_name,
    scp.gender,
    scp.birth_date,
    DATEDIFF('year', scp.birth_date, DATE '2025-01-01')     AS age,
    CASE
        WHEN DATEDIFF('year', scp.birth_date, DATE '2025-01-01') < 25 THEN '<25'
        WHEN DATEDIFF('year', scp.birth_date, DATE '2025-01-01') < 35 THEN '25-34'
        WHEN DATEDIFF('year', scp.birth_date, DATE '2025-01-01') < 45 THEN '35-44'
        WHEN DATEDIFF('year', scp.birth_date, DATE '2025-01-01') < 55 THEN '45-54'
        ELSE '55+'
    END                                                     AS age_group,
    scp.country,
    scp.city,
    scp.customer_segment,
    scp.loyalty_tier,
    scp.signup_date,
    scp.preferred_channel,
    DATEDIFF('day', scp.signup_date, DATE '2025-01-01')     AS days_since_signup,

    -- SCD2 metadata
    scp.load_date                                           AS valid_from,
    pit.snapshot_date

FROM "dev"."main_vault"."hub_customer"                  hc

JOIN "dev"."main_vault"."pit_customer"                  pit
    ON  pit.customer_hk   = hc.customer_hk
    AND pit.snapshot_date = (
        SELECT MAX(p.snapshot_date)
        FROM "dev"."main_vault"."pit_customer" p
        WHERE p.customer_hk = hc.customer_hk
    )

JOIN "dev"."main_vault"."sat_customer_profile"          scp
    ON  scp.sat_customer_profile_hk = pit.sat_customer_profile_hk
    AND pit.sat_customer_profile_hk != 'GHOST'
    );
  
  