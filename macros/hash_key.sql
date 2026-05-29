{#
  hash_key(column_name)
  ----------------------
  Génère un hash MD5 sur la clé métier.
  Utilisé comme PK dans tous les hubs, links et satellites.
  - Uppercase + trim pour normaliser avant hash
  - NULL coercé en 'UNKNOWN' pour éviter les hash NULL

  Usage : {{ hash_key('flight_id') }} AS flight_hk
#}
{% macro hash_key(column_name) %}
    MD5(UPPER(TRIM(COALESCE(CAST({{ column_name }} AS VARCHAR), 'UNKNOWN'))))
{% endmacro %}

{#
  hash_link(col1, col2, ...)
  ---------------------------
  Génère un hash MD5 sur la concaténation de plusieurs clés.
  Utilisé comme PK des links.

  Usage : {{ hash_link('flight_id', 'customer_id') }} AS booking_hk
#}
{% macro hash_link(columns) %}
    MD5(
        {% for col in columns %}
            UPPER(TRIM(COALESCE(CAST({{ col }} AS VARCHAR), 'UNKNOWN')))
            {% if not loop.last %} || '||' || {% endif %}
        {% endfor %}
    )
{% endmacro %}
