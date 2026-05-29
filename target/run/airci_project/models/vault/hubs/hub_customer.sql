
  
    
    

    create  table
      "dev"."main_vault"."hub_customer__dbt_tmp"
  
    as (
      

-- HUB CUSTOMER
-- Clé métier : customer_id
-- Source     : stg_customers
-- Grain      : 1 ligne par client unique

SELECT
    SHA256(UPPER(TRIM(COALESCE(CAST(customer_id AS VARCHAR), 'UNKNOWN'))))
                            AS customer_hk,
    customer_id             AS customer_bk,
    CURRENT_DATE            AS load_date,
    _source                 AS record_source
FROM "dev"."main_staging"."stg_customers"
WHERE customer_id IS NOT NULL
    );
  
  