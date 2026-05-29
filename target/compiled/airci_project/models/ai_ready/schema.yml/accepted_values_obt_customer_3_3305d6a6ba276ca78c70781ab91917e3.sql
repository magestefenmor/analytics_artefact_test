
    
    

with all_values as (

    select
        value_label as value_field,
        count(*) as n_records

    from "dev"."main_ai_ready"."obt_customer_360"
    group by value_label

)

select *
from all_values
where value_field not in (
    'High-value','Mid-value','Low-value','No revenue'
)


