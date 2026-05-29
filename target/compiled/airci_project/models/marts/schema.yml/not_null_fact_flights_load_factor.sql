
    
    



select load_factor
from (select * from "dev"."main_marts"."fact_flights" where flight_status != 'CANCELLED') dbt_subquery
where load_factor is null


