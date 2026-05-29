



select
    1
from "dev"."main_staging"."stg_flights"

where not(actual_arrival actual_arrival >= actual_departure)

