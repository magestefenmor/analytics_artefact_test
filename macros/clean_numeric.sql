{# 
  clean_numeric(column_name)
  --------------------------
  Nettoie une colonne VARCHAR contenant des montants "sales" :
    - Symbole dollar      : "$153.40"  → 153.40
    - Séparateur milliers : "1 234"    → 1234
    - Virgule décimale    : "48,32"    → 48.32
  Retourne un DOUBLE. Retourne NULL si la valeur est vide.
  
  Usage : {{ clean_numeric('ticket_price_usd') }} AS ticket_price_usd
#}

{% macro clean_numeric(column_name) %}
    TRY_CAST(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(CAST({{ column_name }} AS VARCHAR)), '$', ''),
                ' ', ''),
            ',', '.'),
        ' ', '')
    AS DOUBLE)
{% endmacro %}
