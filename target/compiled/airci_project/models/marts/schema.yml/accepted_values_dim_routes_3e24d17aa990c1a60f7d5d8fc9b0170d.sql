
    
    

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


