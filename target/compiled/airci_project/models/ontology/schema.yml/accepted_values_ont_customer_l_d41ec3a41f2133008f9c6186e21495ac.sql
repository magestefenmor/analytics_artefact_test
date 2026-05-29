
    
    

with all_values as (

    select
        customer_label_ont as value_field,
        count(*) as n_records

    from "dev"."main_ontology"."ont_customer_labels"
    group by customer_label_ont

)

select *
from all_values
where value_field not in (
    'Corporate High-Value','High-Value Active','High-Value At-Risk','Loyal Budget','One-Timer','Dormant','Standard'
)


