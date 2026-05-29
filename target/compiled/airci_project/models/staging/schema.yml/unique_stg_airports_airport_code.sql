
    
    

select
    airport_code as unique_field,
    count(*) as n_records

from "dev"."main_staging"."stg_airports"
where airport_code is not null
group by airport_code
having count(*) > 1


