
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        booking_status as value_field,
        count(*) as n_records

    from "dev"."main_staging"."stg_bookings"
    group by booking_status

)

select *
from all_values
where value_field not in (
    'Confirmed','Flown','No Show','Changed'
)



  
  
      
    ) dbt_internal_test