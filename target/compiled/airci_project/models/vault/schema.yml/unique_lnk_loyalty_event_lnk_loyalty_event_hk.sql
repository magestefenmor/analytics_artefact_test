
    
    

select
    lnk_loyalty_event_hk as unique_field,
    count(*) as n_records

from "dev"."main_vault"."lnk_loyalty_event"
where lnk_loyalty_event_hk is not null
group by lnk_loyalty_event_hk
having count(*) > 1


