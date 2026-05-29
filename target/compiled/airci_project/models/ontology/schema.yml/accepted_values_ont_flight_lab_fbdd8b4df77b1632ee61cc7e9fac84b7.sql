
    
    

with all_values as (

    select
        flight_label_ont as value_field,
        count(*) as n_records

    from "dev"."main_ontology"."ont_flight_labels"
    group by flight_label_ont

)

select *
from all_values
where value_field not in (
    'High-Yield','Chronically Delayed','Loss-Making','Underutilized','Cancelled','Standard'
)


