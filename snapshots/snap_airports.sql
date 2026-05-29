{% snapshot snap_airports %}

{{
    config(
        target_schema='snapshots',
        unique_key='airport_code',
        strategy='check',
        check_cols=[
            'airport_name',
            'city',
            'country',
            'timezone',
            'latitude',
            'longitude'
        ]
    )
}}

SELECT
    airport_code,
    airport_name,
    city,
    country,
    timezone,
    latitude,
    longitude,
    _source
FROM {{ ref('stg_airports') }}

{% endsnapshot %}
