
    
    

with all_values as (

    select
        load_factor_label as value_field,
        count(*) as n_records

    from "dev"."main_ai_ready"."obt_flight_full"
    group by load_factor_label

)

select *
from all_values
where value_field not in (
    'Optimal','Acceptable','Sous-rempli','Critique'
)


