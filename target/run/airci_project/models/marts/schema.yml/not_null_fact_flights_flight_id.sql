
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select flight_id
from "dev"."main_marts"."fact_flights"
where flight_id is null



  
  
      
    ) dbt_internal_test