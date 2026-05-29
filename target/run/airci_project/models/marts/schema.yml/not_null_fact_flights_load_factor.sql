
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select load_factor
from (select * from "dev"."main_marts"."fact_flights" where flight_status != 'CANCELLED') dbt_subquery
where load_factor is null



  
  
      
    ) dbt_internal_test