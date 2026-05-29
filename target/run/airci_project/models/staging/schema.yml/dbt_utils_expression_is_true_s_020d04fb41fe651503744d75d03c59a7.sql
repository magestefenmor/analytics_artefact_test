
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  



select
    1
from "dev"."main_staging"."stg_flights"

where not(actual_arrival  >= actual_departure)


  
  
      
    ) dbt_internal_test