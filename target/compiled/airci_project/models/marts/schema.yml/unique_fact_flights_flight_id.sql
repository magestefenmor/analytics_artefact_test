
    
    

select
    flight_id as unique_field,
    count(*) as n_records

from "dev"."main_marts"."fact_flights"
where flight_id is not null
group by flight_id
having count(*) > 1


