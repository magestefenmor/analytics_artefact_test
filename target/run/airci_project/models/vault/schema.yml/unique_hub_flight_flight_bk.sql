
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    flight_bk as unique_field,
    count(*) as n_records

from "dev"."main_vault"."hub_flight"
where flight_bk is not null
group by flight_bk
having count(*) > 1



  
  
      
    ) dbt_internal_test