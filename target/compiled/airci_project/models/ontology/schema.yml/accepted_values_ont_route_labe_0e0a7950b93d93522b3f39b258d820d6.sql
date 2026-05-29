
    
    

with all_values as (

    select
        route_label_ont as value_field,
        count(*) as n_records

    from "dev"."main_ontology"."ont_route_labels"
    group by route_label_ont

)

select *
from all_values
where value_field not in (
    'Cash Cow','Strategic Underperformer','Loss Maker','Emerging','High Concentration Risk'
)


