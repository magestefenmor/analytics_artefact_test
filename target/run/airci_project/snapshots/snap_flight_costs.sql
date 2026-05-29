
      update "dev"."snapshots"."snap_flight_costs" as DBT_INTERNAL_TARGET
    set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to
    from "snap_flight_costs__dbt_tmp20260525094144496827" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_scd_id::text = DBT_INTERNAL_TARGET.dbt_scd_id::text
      and DBT_INTERNAL_SOURCE.dbt_change_type::text in ('update'::text, 'delete'::text)
      
        and DBT_INTERNAL_TARGET.dbt_valid_to is null;
      

    insert into "dev"."snapshots"."snap_flight_costs" ("flight_id", "route_id", "aircraft_type", "fuel_cost_usd", "crew_cost_usd", "airport_handling_usd", "maintenance_usd", "total_cost_usd", "cost_per_seat_usd", "_source", "dbt_updated_at", "dbt_valid_from", "dbt_valid_to", "dbt_scd_id")
    select DBT_INTERNAL_SOURCE."flight_id",DBT_INTERNAL_SOURCE."route_id",DBT_INTERNAL_SOURCE."aircraft_type",DBT_INTERNAL_SOURCE."fuel_cost_usd",DBT_INTERNAL_SOURCE."crew_cost_usd",DBT_INTERNAL_SOURCE."airport_handling_usd",DBT_INTERNAL_SOURCE."maintenance_usd",DBT_INTERNAL_SOURCE."total_cost_usd",DBT_INTERNAL_SOURCE."cost_per_seat_usd",DBT_INTERNAL_SOURCE."_source",DBT_INTERNAL_SOURCE."dbt_updated_at",DBT_INTERNAL_SOURCE."dbt_valid_from",DBT_INTERNAL_SOURCE."dbt_valid_to",DBT_INTERNAL_SOURCE."dbt_scd_id"
    from "snap_flight_costs__dbt_tmp20260525094144496827" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_change_type::text = 'insert'::text;


  