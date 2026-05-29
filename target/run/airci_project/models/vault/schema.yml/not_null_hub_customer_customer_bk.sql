
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select customer_bk
from "dev"."main_vault"."hub_customer"
where customer_bk is null



  
  
      
    ) dbt_internal_test