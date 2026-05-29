
    
    

select
    route_id as unique_field,
    count(*) as n_records

from "dev"."main_ontology"."ont_route_labels"
where route_id is not null
group by route_id
having count(*) > 1


