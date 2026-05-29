
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    customer_hk as unique_field,
    count(*) as n_records

from "dev"."main_vault"."hub_customer"
where customer_hk is not null
group by customer_hk
having count(*) > 1



  
  
      
    ) dbt_internal_test