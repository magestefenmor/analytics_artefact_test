
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select aircraft_type
from "dev"."main_marts"."dim_aircraft"
where aircraft_type is null



  
  
      
    ) dbt_internal_test