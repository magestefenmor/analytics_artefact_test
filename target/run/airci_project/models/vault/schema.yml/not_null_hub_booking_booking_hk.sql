
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select booking_hk
from "dev"."main_vault"."hub_booking"
where booking_hk is null



  
  
      
    ) dbt_internal_test