
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        margin_label as value_field,
        count(*) as n_records

    from "dev"."main_semantic"."sem_kpis_revenue"
    group by margin_label

)

select *
from all_values
where value_field not in (
    'Très rentable','Rentable','Légèrement déficitaire','Fortement déficitaire'
)



  
  
      
    ) dbt_internal_test