
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select lnk_loyalty_event_hk
from "dev"."main_vault"."lnk_loyalty_event"
where lnk_loyalty_event_hk is null



  
  
      
    ) dbt_internal_test