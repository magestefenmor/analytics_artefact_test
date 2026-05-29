
    
    

select
    route_id as unique_field,
    count(*) as n_records

from "dev"."main_ai_ready"."obt_route_summary"
where route_id is not null
group by route_id
having count(*) > 1


