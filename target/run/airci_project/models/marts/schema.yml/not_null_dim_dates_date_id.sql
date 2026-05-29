
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select date_id
from "dev"."main_marts"."dim_dates"
where date_id is null



  
  
      
    ) dbt_internal_test