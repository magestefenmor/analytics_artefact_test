
    
    

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


