
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        sentiment_score as value_field,
        count(*) as n_records

    from "dev"."main_vault"."sat_flight_sentiment"
    group by sentiment_score

)

select *
from all_values
where value_field not in (
    '-1','0','1'
)



  
  
      
    ) dbt_internal_test