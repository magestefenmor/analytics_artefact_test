
    
    



select lnk_booking_hk
from (select * from "dev"."main_vault"."bridge_flight_booking" where booking_id IS NOT NULL) dbt_subquery
where lnk_booking_hk is null


