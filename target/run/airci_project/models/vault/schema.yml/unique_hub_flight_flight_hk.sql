
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    flight_hk as unique_field,
    count(*) as n_records

from "dev"."main_vault"."hub_flight"
where flight_hk is not null
group by flight_hk
having count(*) > 1



  
  
      
    ) dbt_internal_test