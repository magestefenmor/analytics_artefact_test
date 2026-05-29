
      update "dev"."snapshots"."snap_loyalty_activity" as DBT_INTERNAL_TARGET
    set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to
    from "snap_loyalty_activity__dbt_tmp20260525094144865787" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_scd_id::text = DBT_INTERNAL_TARGET.dbt_scd_id::text
      and DBT_INTERNAL_SOURCE.dbt_change_type::text in ('update'::text, 'delete'::text)
      
        and DBT_INTERNAL_TARGET.dbt_valid_to is null;
      

    insert into "dev"."snapshots"."snap_loyalty_activity" ("activity_id", "customer_id", "activity_date", "event_type", "loyalty_tier", "points_earned", "points_redeemed", "balance_after", "_source", "dbt_updated_at", "dbt_valid_from", "dbt_valid_to", "dbt_scd_id")
    select DBT_INTERNAL_SOURCE."activity_id",DBT_INTERNAL_SOURCE."customer_id",DBT_INTERNAL_SOURCE."activity_date",DBT_INTERNAL_SOURCE."event_type",DBT_INTERNAL_SOURCE."loyalty_tier",DBT_INTERNAL_SOURCE."points_earned",DBT_INTERNAL_SOURCE."points_redeemed",DBT_INTERNAL_SOURCE."balance_after",DBT_INTERNAL_SOURCE."_source",DBT_INTERNAL_SOURCE."dbt_updated_at",DBT_INTERNAL_SOURCE."dbt_valid_from",DBT_INTERNAL_SOURCE."dbt_valid_to",DBT_INTERNAL_SOURCE."dbt_scd_id"
    from "snap_loyalty_activity__dbt_tmp20260525094144865787" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_change_type::text = 'insert'::text;


  