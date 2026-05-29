
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select airport_hk
from "dev"."main_vault"."sat_airport_details"
where airport_hk is null



  
  
      
    ) dbt_internal_test