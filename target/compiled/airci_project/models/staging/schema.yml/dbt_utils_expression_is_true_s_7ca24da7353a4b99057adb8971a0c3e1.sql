



select
    1
from "dev"."main_staging"."stg_flights"

where not(ecart_departure_computed actual_arrival >= actual_departure)

