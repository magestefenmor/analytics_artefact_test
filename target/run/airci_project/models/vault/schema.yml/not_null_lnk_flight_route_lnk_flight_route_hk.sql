
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select lnk_flight_route_hk
from "dev"."main_vault"."lnk_flight_route"
where lnk_flight_route_hk is null



  
  
      
    ) dbt_internal_test