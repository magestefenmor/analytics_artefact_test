
      update "dev"."snapshots"."snap_routes" as DBT_INTERNAL_TARGET
    set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to
    from "snap_routes__dbt_tmp20260525094145049187" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_scd_id::text = DBT_INTERNAL_TARGET.dbt_scd_id::text
      and DBT_INTERNAL_SOURCE.dbt_change_type::text in ('update'::text, 'delete'::text)
      
        and DBT_INTERNAL_TARGET.dbt_valid_to is null;
      

    insert into "dev"."snapshots"."snap_routes" ("route_id", "origin_airport_code", "destination_airport_code", "route_type", "distance_km", "block_time_min", "_source", "dbt_updated_at", "dbt_valid_from", "dbt_valid_to", "dbt_scd_id")
    select DBT_INTERNAL_SOURCE."route_id",DBT_INTERNAL_SOURCE."origin_airport_code",DBT_INTERNAL_SOURCE."destination_airport_code",DBT_INTERNAL_SOURCE."route_type",DBT_INTERNAL_SOURCE."distance_km",DBT_INTERNAL_SOURCE."block_time_min",DBT_INTERNAL_SOURCE."_source",DBT_INTERNAL_SOURCE."dbt_updated_at",DBT_INTERNAL_SOURCE."dbt_valid_from",DBT_INTERNAL_SOURCE."dbt_valid_to",DBT_INTERNAL_SOURCE."dbt_scd_id"
    from "snap_routes__dbt_tmp20260525094145049187" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_change_type::text = 'insert'::text;


  