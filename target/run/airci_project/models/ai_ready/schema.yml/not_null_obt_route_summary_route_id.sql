
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select route_id
from "dev"."main_ai_ready"."obt_route_summary"
where route_id is null



  
  
      
    ) dbt_internal_test