
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select lnk_flight_incident_hk
from "dev"."main_vault"."lnk_flight_incident"
where lnk_flight_incident_hk is null



  
  
      
    ) dbt_internal_test