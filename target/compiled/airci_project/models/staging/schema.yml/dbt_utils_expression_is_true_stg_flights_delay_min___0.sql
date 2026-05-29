



select
    1
from "dev"."main_staging"."stg_flights"

where not(delay_min  >= 0)

