
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select route_hk
from "dev"."main_vault"."sat_route_details"
where route_hk is null



  
  
      
    ) dbt_internal_test