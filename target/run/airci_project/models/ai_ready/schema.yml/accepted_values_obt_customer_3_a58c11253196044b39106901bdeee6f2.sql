
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        recency_label as value_field,
        count(*) as n_records

    from "dev"."main_ai_ready"."obt_customer_360"
    group by recency_label

)

select *
from all_values
where value_field not in (
    'Actif','En risque','Dormant','Jamais réservé'
)



  
  
      
    ) dbt_internal_test