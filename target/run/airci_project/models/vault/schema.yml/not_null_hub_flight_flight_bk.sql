
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select flight_bk
from "dev"."main_vault"."hub_flight"
where flight_bk is null



  
  
      
    ) dbt_internal_test