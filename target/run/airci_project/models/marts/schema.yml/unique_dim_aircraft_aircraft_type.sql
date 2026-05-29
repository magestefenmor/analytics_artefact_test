
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    aircraft_type as unique_field,
    count(*) as n_records

from "dev"."main_marts"."dim_aircraft"
where aircraft_type is not null
group by aircraft_type
having count(*) > 1



  
  
      
    ) dbt_internal_test