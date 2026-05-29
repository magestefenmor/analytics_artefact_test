-- ============================================================
-- 10. STG_COMPLAINT_LOGS
-- Ajout : corrective_action_taken conservé (utile pour l'ontologie)
-- ============================================================

CREATE OR REPLACE TABLE stg_complaint_logs AS
SELECT
    CAST(complaint_id             AS VARCHAR)  AS complaint_id,
    CAST(customer_id              AS VARCHAR)  AS customer_id,
    CAST(flight_id                AS VARCHAR)  AS flight_id,
    CAST(booking_id               AS VARCHAR)  AS booking_id,
    TRY_CAST(complaint_date       AS DATE)     AS complaint_date,
    TRIM(complaint_type)                       AS complaint_type,
    TRIM(complaint_text)                       AS complaint_text,
    TRIM(assigned_department)                  AS assigned_department,
    TRIM(resolution_status)                    AS resolution_status,
    TRIM(corrective_action_taken)              AS corrective_action_taken,
    CURRENT_TIMESTAMP                          AS _loaded_at,
    'partie1_unstruct'                         AS _source
FROM raw_complaint_logs
WHERE complaint_id IS NOT NULL;