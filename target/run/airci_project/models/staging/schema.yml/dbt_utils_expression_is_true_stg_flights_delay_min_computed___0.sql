
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  



select
    1
from "dev"."main_staging"."stg_flights"

where not(delay_min_computed >= 0)


  
  
      
    ) dbt_internal_test