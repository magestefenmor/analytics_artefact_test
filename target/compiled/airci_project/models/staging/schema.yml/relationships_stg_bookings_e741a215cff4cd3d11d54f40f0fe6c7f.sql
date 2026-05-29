
    
    

with child as (
    select flight_id as from_field
    from "dev"."main_staging"."stg_bookings"
    where flight_id is not null
),

parent as (
    select flight_id as to_field
    from "dev"."main_staging"."stg_flights"
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


