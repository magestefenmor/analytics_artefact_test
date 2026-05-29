
    
    

with all_values as (

    select
        loyalty_tier as value_field,
        count(*) as n_records

    from "dev"."main_staging"."stg_customers"
    group by loyalty_tier

)

select *
from all_values
where value_field not in (
    'None','Explorer','Silver','Gold'
)


