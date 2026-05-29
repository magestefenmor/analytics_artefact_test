
    
    

select
    lnk_flight_incident_hk as unique_field,
    count(*) as n_records

from "dev"."main_vault"."lnk_flight_incident"
where lnk_flight_incident_hk is not null
group by lnk_flight_incident_hk
having count(*) > 1


