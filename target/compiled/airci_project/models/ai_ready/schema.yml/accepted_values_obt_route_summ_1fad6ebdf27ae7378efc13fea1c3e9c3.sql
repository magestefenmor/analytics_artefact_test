
    
    

with all_values as (

    select
        route_label_ontology as value_field,
        count(*) as n_records

    from "dev"."main_ai_ready"."obt_route_summary"
    group by route_label_ontology

)

select *
from all_values
where value_field not in (
    'Cash Cow','Strategic Underperformer','Loss Maker','Emerging','Standard'
)


