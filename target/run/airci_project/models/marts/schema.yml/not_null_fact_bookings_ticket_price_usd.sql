
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select ticket_price_usd
from "dev"."main_marts"."fact_bookings"
where ticket_price_usd is null



  
  
      
    ) dbt_internal_test