
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select lnk_booking_hk
from "dev"."main_vault"."lnk_booking"
where lnk_booking_hk is null



  
  
      
    ) dbt_internal_test