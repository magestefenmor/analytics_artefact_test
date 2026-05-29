
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        load_factor_label as value_field,
        count(*) as n_records

    from "dev"."main_semantic"."sem_kpis_operations"
    group by load_factor_label

)

select *
from all_values
where value_field not in (
    'Optimal','Acceptable','Sous-rempli','Critique'
)



  
  
      
    ) dbt_internal_test