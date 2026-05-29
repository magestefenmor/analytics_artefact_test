{% macro historise_model(source_model, business_key, columns) %}

WITH source AS (

    SELECT
        {{ business_key }} AS business_key,

        SHA256(
            {% for col in columns %}
                COALESCE(CAST({{ col }} AS VARCHAR), '')
                {% if not loop.last %} || {% endif %}
            {% endfor %}
        ) AS hash_diff,

        {% for col in columns %}
            {{ col }},
        {% endfor %}

        CURRENT_TIMESTAMP AS load_date,
        _source AS record_source

    FROM {{ ref(source_model) }}
),

current_target AS (

    SELECT *
    FROM {{ this }}
    WHERE is_current = 1

),

changes AS (

    SELECT
        s.*,
        t.hash_diff AS current_hash_diff

    FROM source s
    LEFT JOIN current_target t
        ON s.business_key = t.business_key

),

to_insert AS (

    SELECT *
    FROM changes
    WHERE current_hash_diff IS NULL
       OR current_hash_diff != hash_diff

),

to_close AS (

    SELECT
        t.business_key,
        t.hash_diff,
        {% for col in columns %}
            t.{{ col }},
        {% endfor %}

        t.load_date,
        CURRENT_TIMESTAMP AS load_end_date,
        0 AS is_current

    FROM current_target t
    JOIN changes c
        ON t.business_key = c.business_key
    WHERE c.current_hash_diff != c.hash_diff

),

final_insert AS (

    SELECT
        business_key,
        hash_diff,

        {% for col in columns %}
            {{ col }},
        {% endfor %}

        load_date,
        NULL AS load_end_date,
        1 AS is_current

    FROM to_insert

)

SELECT * FROM final_insert

{% if is_incremental() %}

UNION ALL

SELECT * FROM to_close

{% endif %}

{% endmacro %}