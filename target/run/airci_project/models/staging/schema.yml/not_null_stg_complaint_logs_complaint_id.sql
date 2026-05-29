
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select complaint_id
from "dev"."main_staging"."stg_complaint_logs"
where complaint_id is null



  
  
      
    ) dbt_internal_test