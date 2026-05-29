
    
    

select
    flight_id as unique_field,
    count(*) as n_records

from "dev"."main_staging"."stg_flight_costs"
where flight_id is not null
group by flight_id
having count(*) > 1


