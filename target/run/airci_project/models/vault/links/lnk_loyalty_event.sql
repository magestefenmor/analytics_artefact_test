
  
    
    

    create  table
      "dev"."main_vault"."lnk_loyalty_event__dbt_tmp"
  
    as (
      

-- LINK LOYALTY_EVENT
-- Relation : un événement loyalty appartient à un client
-- Sources  : hub_customer via stg_loyalty_activity
-- Grain    : 1 ligne par événement loyalty

SELECT
    SHA256(
        UPPER(TRIM(COALESCE(CAST(la.activity_id  AS VARCHAR), 'UNKNOWN')))
        || '||' ||
        UPPER(TRIM(COALESCE(CAST(la.customer_id  AS VARCHAR), 'UNKNOWN')))
    )                           AS lnk_loyalty_event_hk,
    SHA256(UPPER(TRIM(COALESCE(CAST(la.activity_id  AS VARCHAR), 'UNKNOWN'))))
                                AS activity_bk,
    SHA256(UPPER(TRIM(COALESCE(CAST(la.customer_id  AS VARCHAR), 'UNKNOWN'))))
                                AS customer_hk,
    CURRENT_DATE                AS load_date,
    la._source                  AS record_source
FROM "dev"."main_staging"."stg_loyalty_activity" la
WHERE la.activity_id IS NOT NULL
  AND la.customer_id IS NOT NULL
    );
  
  