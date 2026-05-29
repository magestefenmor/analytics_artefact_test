{% snapshot snap_routes %}

{{
    config(
        target_schema='snapshots',
        unique_key='route_id',
        strategy='check',
        check_cols=[
            'origin_airport_code',
            'destination_airport_code',
            'route_type',
            'distance_km',
            'block_time_min'
        ]
    )
}}

-- Snapshot des routes
-- SCD2 déclenché si : type de route change, durée de bloc change

SELECT
    route_id,
    origin_airport_code,
    destination_airport_code,
    route_type,
    distance_km,
    block_time_min,
    _source
FROM {{ ref('stg_routes') }}

{% endsnapshot %}
