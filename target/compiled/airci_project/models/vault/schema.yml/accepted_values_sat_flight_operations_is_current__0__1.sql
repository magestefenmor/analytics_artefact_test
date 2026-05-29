
    
    

with all_values as (

    select
        is_current as value_field,
        count(*) as n_records

    from "dev"."main_vault"."sat_flight_operations"
    group by is_current

)

select *
from all_values
where value_field not in (
    '0','1'
)


