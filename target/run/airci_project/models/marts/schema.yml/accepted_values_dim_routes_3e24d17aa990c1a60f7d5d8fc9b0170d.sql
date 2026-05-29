
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        route_type as value_field,
        count(*) as n_records

    from "dev"."main_marts"."dim_routes"
    group by route_type

)

select *
from all_values
where value_field not in (
    'Domestic','Regional','International'
)



  
  
      
    ) dbt_internal_test