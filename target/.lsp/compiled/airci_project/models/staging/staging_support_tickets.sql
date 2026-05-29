-- ============================================================
-- 9. STG_SUPPORT_TICKETS
-- Note : pas de flight_id dans la source — booking_id disponible
-- ============================================================

CREATE OR REPLACE TABLE stg_support_tickets AS
SELECT
    CAST(ticket_id       AS VARCHAR)  AS ticket_id,
    CAST(customer_id     AS VARCHAR)  AS customer_id,
    CAST(booking_id      AS VARCHAR)  AS booking_id,
    TRY_CAST(created_date AS DATE)    AS created_date,
    TRIM(priority)                    AS priority,
    TRIM(category)                    AS category,
    TRIM(ticket_text)                 AS ticket_text,
    TRIM(status)                      AS status,
    CAST(resolution_days AS DOUBLE)   AS resolution_days,
    TRIM(customer_tier)               AS customer_tier,
    CURRENT_TIMESTAMP                 AS _loaded_at,
    'partie1_unstruct'                AS _source
FROM raw_support_tickets
WHERE ticket_id IS NOT NULL;