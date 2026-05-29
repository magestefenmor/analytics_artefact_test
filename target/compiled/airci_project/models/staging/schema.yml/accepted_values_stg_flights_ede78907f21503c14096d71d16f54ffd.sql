
    
    

with all_values as (

    select
        flight_status as value_field,
        count(*) as n_records

    from "dev"."main_staging"."stg_flights"
    group by flight_status

)

select *
from all_values
where value_field not in (
    'ON TIME','DELAYED','CANCELLED'
)


