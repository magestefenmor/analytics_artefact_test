
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select flight_id
from "dev"."main_ai_ready"."obt_flight_full"
where flight_id is null



  
  
      
    ) dbt_internal_test