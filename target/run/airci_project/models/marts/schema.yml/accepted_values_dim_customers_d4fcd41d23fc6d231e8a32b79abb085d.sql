
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        loyalty_tier as value_field,
        count(*) as n_records

    from "dev"."main_marts"."dim_customers"
    group by loyalty_tier

)

select *
from all_values
where value_field not in (
    'None','Explorer','Silver','Gold'
)



  
  
      
    ) dbt_internal_test