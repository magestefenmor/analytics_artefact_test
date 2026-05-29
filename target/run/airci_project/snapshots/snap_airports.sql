
      
  
    
    

    create  table
      "dev"."snapshots"."snap_airports"
  
    as (
      
    

    select *,
        md5(coalesce(cast(airport_code as varchar ), '')
         || '|' || coalesce(cast(now()::timestamp as varchar ), '')
        ) as dbt_scd_id,
        now()::timestamp as dbt_updated_at,
        now()::timestamp as dbt_valid_from,
        
  
  coalesce(nullif(now()::timestamp, now()::timestamp), null)
  as dbt_valid_to
from (
        



SELECT
    airport_code,
    airport_name,
    city,
    country,
    timezone,
    latitude,
    longitude,
    _source
FROM "dev"."main_staging"."stg_airports"

    ) sbq



    );
  
  
  