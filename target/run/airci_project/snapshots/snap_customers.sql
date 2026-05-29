
      update "dev"."snapshots"."snap_customers" as DBT_INTERNAL_TARGET
    set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to
    from "snap_customers__dbt_tmp20260525094144300299" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_scd_id::text = DBT_INTERNAL_TARGET.dbt_scd_id::text
      and DBT_INTERNAL_SOURCE.dbt_change_type::text in ('update'::text, 'delete'::text)
      
        and DBT_INTERNAL_TARGET.dbt_valid_to is null;
      

    insert into "dev"."snapshots"."snap_customers" ("customer_id", "first_name", "last_name", "gender", "birth_date", "country", "city", "customer_segment", "loyalty_tier", "signup_date", "preferred_channel", "_source", "dbt_updated_at", "dbt_valid_from", "dbt_valid_to", "dbt_scd_id")
    select DBT_INTERNAL_SOURCE."customer_id",DBT_INTERNAL_SOURCE."first_name",DBT_INTERNAL_SOURCE."last_name",DBT_INTERNAL_SOURCE."gender",DBT_INTERNAL_SOURCE."birth_date",DBT_INTERNAL_SOURCE."country",DBT_INTERNAL_SOURCE."city",DBT_INTERNAL_SOURCE."customer_segment",DBT_INTERNAL_SOURCE."loyalty_tier",DBT_INTERNAL_SOURCE."signup_date",DBT_INTERNAL_SOURCE."preferred_channel",DBT_INTERNAL_SOURCE."_source",DBT_INTERNAL_SOURCE."dbt_updated_at",DBT_INTERNAL_SOURCE."dbt_valid_from",DBT_INTERNAL_SOURCE."dbt_valid_to",DBT_INTERNAL_SOURCE."dbt_scd_id"
    from "snap_customers__dbt_tmp20260525094144300299" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_change_type::text = 'insert'::text;


  