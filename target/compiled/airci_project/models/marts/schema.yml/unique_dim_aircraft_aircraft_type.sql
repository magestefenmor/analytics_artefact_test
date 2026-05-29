
    
    

select
    aircraft_type as unique_field,
    count(*) as n_records

from "dev"."main_marts"."dim_aircraft"
where aircraft_type is not null
group by aircraft_type
having count(*) > 1


