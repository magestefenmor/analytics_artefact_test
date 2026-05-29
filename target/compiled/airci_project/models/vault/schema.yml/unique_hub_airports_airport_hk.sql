
    
    

select
    airport_hk as unique_field,
    count(*) as n_records

from "dev"."main_vault"."hub_airports"
where airport_hk is not null
group by airport_hk
having count(*) > 1


