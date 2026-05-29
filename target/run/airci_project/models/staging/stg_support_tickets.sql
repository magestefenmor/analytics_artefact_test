
  
    
    

    create  table
      "dev"."main_staging"."stg_support_tickets__dbt_tmp"
  
    as (
      

SELECT
    ticket_id                                               AS ticket_id,
    customer_id                                             AS customer_id,
    booking_id                                              AS booking_id,
    TRY_CAST(created_date   AS DATE)                        AS created_date,
    TRIM(priority)                                          AS priority,
    TRIM(category)                                          AS category,
    TRIM(ticket_text)                                       AS ticket_text,
    TRIM(status)                                            AS status,
    TRY_CAST(resolution_days    AS INTEGER)                 AS resolution_days,
    TRIM(customer_tier)                                     AS customer_tier,
    CURRENT_TIMESTAMP                                       AS _loaded_at,
    'seed_partie1'                                          AS _source
FROM "dev"."main"."supportticket"
WHERE ticket_id IS NOT NULL
    );
  
  