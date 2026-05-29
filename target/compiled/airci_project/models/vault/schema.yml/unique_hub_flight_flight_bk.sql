
    
    

select
    flight_bk as unique_field,
    count(*) as n_records

from "dev"."main_vault"."hub_flight"
where flight_bk is not null
group by flight_bk
having count(*) > 1


