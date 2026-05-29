{% snapshot snap_loyalty_activity %}

{{
    config(
        target_schema='snapshots',
        unique_key='activity_id',
        strategy='check',
        check_cols=[
            'points_earned',
            'points_redeemed',
            'balance_after',
            'loyalty_tier'
        ]
    )
}}

-- Snapshot des événements loyalty
-- Grain événement — chaque activité est immuable en principe
-- SCD2 déclenché si un événement est corrigé (ex: points ajustés)

SELECT
    activity_id,
    customer_id,
    activity_date,
    event_type,
    loyalty_tier,
    points_earned,
    points_redeemed,
    balance_after,
    _source
FROM {{ ref('stg_loyalty_activity') }}

{% endsnapshot %}
