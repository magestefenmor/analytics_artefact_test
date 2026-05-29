{% snapshot snap_flight_costs %}

{{
    config(
        target_schema='snapshots',
        unique_key='flight_id',
        strategy='check',
        check_cols=[
            'fuel_cost_usd',
            'crew_cost_usd',
            'airport_handling_usd',
            'maintenance_usd',
            'total_cost_usd'
        ]
    )
}}

-- Snapshot des coûts par vol
-- SCD2 déclenché si les coûts sont révisés
-- is_generated tracé pour distinguer réel vs synthétique

SELECT
    flight_id,
    route_id,
    aircraft_type,
    fuel_cost_usd,
    crew_cost_usd,
    airport_handling_usd,
    maintenance_usd,
    total_cost_usd,
    cost_per_seat_usd,
    _source
FROM {{ ref('stg_flight_costs') }}

{% endsnapshot %}
