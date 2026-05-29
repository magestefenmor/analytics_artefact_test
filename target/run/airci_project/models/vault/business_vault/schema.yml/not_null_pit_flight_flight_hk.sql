
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select flight_hk
from "dev"."main_vault"."pit_flight"
where flight_hk is null



  
  
      
    ) dbt_internal_test