
      update "dev"."snapshots"."snap_bookings" as DBT_INTERNAL_TARGET
    set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to
    from "snap_bookings__dbt_tmp20260525094144046570" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_scd_id::text = DBT_INTERNAL_TARGET.dbt_scd_id::text
      and DBT_INTERNAL_SOURCE.dbt_change_type::text in ('update'::text, 'delete'::text)
      
        and DBT_INTERNAL_TARGET.dbt_valid_to is null;
      

    insert into "dev"."snapshots"."snap_bookings" ("booking_id", "booking_date", "customer_id", "flight_id", "booking_channel", "fare_class", "fare_family", "ticket_price_usd", "ancillary_revenue_usd", "bags_count", "seat_selection_flag", "booking_status", "_source", "dbt_updated_at", "dbt_valid_from", "dbt_valid_to", "dbt_scd_id")
    select DBT_INTERNAL_SOURCE."booking_id",DBT_INTERNAL_SOURCE."booking_date",DBT_INTERNAL_SOURCE."customer_id",DBT_INTERNAL_SOURCE."flight_id",DBT_INTERNAL_SOURCE."booking_channel",DBT_INTERNAL_SOURCE."fare_class",DBT_INTERNAL_SOURCE."fare_family",DBT_INTERNAL_SOURCE."ticket_price_usd",DBT_INTERNAL_SOURCE."ancillary_revenue_usd",DBT_INTERNAL_SOURCE."bags_count",DBT_INTERNAL_SOURCE."seat_selection_flag",DBT_INTERNAL_SOURCE."booking_status",DBT_INTERNAL_SOURCE."_source",DBT_INTERNAL_SOURCE."dbt_updated_at",DBT_INTERNAL_SOURCE."dbt_valid_from",DBT_INTERNAL_SOURCE."dbt_valid_to",DBT_INTERNAL_SOURCE."dbt_scd_id"
    from "snap_bookings__dbt_tmp20260525094144046570" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_change_type::text = 'insert'::text;


  