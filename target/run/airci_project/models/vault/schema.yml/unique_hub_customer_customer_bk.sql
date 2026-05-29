
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    customer_bk as unique_field,
    count(*) as n_records

from "dev"."main_vault"."hub_customer"
where customer_bk is not null
group by customer_bk
having count(*) > 1



  
  
      
    ) dbt_internal_test