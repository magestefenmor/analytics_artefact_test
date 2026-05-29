
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    airport_hk as unique_field,
    count(*) as n_records

from "dev"."main_vault"."hub_airports"
where airport_hk is not null
group by airport_hk
having count(*) > 1



  
  
      
    ) dbt_internal_test