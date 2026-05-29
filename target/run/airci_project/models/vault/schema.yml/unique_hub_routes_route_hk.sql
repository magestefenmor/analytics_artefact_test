
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    route_hk as unique_field,
    count(*) as n_records

from "dev"."main_vault"."hub_routes"
where route_hk is not null
group by route_hk
having count(*) > 1



  
  
      
    ) dbt_internal_test