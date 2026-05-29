
    
    

select
    lnk_flight_review_hk as unique_field,
    count(*) as n_records

from "dev"."main_vault"."lnk_flight_review"
where lnk_flight_review_hk is not null
group by lnk_flight_review_hk
having count(*) > 1


