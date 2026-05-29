
    
    

select
    customer_id as unique_field,
    count(*) as n_records

from "dev"."main_ontology"."ont_customer_labels"
where customer_id is not null
group by customer_id
having count(*) > 1


