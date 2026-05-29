
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select snapshot_date
from "dev"."main_vault"."pit_flight"
where snapshot_date is null



  
  
      
    ) dbt_internal_test