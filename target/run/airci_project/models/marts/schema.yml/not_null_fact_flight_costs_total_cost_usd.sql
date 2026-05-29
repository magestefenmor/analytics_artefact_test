
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select total_cost_usd
from "dev"."main_marts"."fact_flight_costs"
where total_cost_usd is null



  
  
      
    ) dbt_internal_test