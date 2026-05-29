
      update "dev"."snapshots"."snap_flight_operations" as DBT_INTERNAL_TARGET
    set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to
    from "snap_flight_operations__dbt_tmp20260525094144674028" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_scd_id::text = DBT_INTERNAL_TARGET.dbt_scd_id::text
      and DBT_INTERNAL_SOURCE.dbt_change_type::text in ('update'::text, 'delete'::text)
      
        and DBT_INTERNAL_TARGET.dbt_valid_to is null;
      

    insert into "dev"."snapshots"."snap_flight_operations" ("flight_id", "flight_number", "route_id", "aircraft_type", "flight_date", "scheduled_departure", "actual_departure", "scheduled_arrival", "actual_arrival", "flight_status", "delay_min", "seat_capacity", "_source", "dbt_updated_at", "dbt_valid_from", "dbt_valid_to", "dbt_scd_id")
    select DBT_INTERNAL_SOURCE."flight_id",DBT_INTERNAL_SOURCE."flight_number",DBT_INTERNAL_SOURCE."route_id",DBT_INTERNAL_SOURCE."aircraft_type",DBT_INTERNAL_SOURCE."flight_date",DBT_INTERNAL_SOURCE."scheduled_departure",DBT_INTERNAL_SOURCE."actual_departure",DBT_INTERNAL_SOURCE."scheduled_arrival",DBT_INTERNAL_SOURCE."actual_arrival",DBT_INTERNAL_SOURCE."flight_status",DBT_INTERNAL_SOURCE."delay_min",DBT_INTERNAL_SOURCE."seat_capacity",DBT_INTERNAL_SOURCE."_source",DBT_INTERNAL_SOURCE."dbt_updated_at",DBT_INTERNAL_SOURCE."dbt_valid_from",DBT_INTERNAL_SOURCE."dbt_valid_to",DBT_INTERNAL_SOURCE."dbt_scd_id"
    from "snap_flight_operations__dbt_tmp20260525094144674028" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_change_type::text = 'insert'::text;


  