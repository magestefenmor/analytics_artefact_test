{% snapshot snap_bookings %}

{{
    config(
        target_schema='snapshots',
        unique_key='booking_id',
        strategy='check',
        check_cols=[
            'booking_status',
            'ticket_price_usd',
            'ancillary_revenue_usd',
            'bags_count',
            'seat_selection_flag'
        ]
    )
}}

-- Snapshot des réservations
-- SCD2 déclenché si : statut change (Confirmed → Flown / No Show / Changed)
-- ou si le prix est amendé

SELECT
    booking_id,
    booking_date,
    customer_id,
    flight_id,
    booking_channel,
    fare_class,
    fare_family,
    ticket_price_usd,
    ancillary_revenue_usd,
    bags_count,
    seat_selection_flag,
    booking_status,
    _source
FROM {{ ref('stg_bookings') }}

{% endsnapshot %}
