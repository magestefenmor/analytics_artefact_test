
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    lnk_loyalty_event_hk as unique_field,
    count(*) as n_records

from "dev"."main_vault"."lnk_loyalty_event"
where lnk_loyalty_event_hk is not null
group by lnk_loyalty_event_hk
having count(*) > 1



  
  
      
    ) dbt_internal_test