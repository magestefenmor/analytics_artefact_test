{{ config(materialized='table') }}

SELECT
    complaint_id                                            AS complaint_id,
    customer_id                                             AS customer_id,
    flight_id                                               AS flight_id,
    booking_id                                              AS booking_id,
    TRY_CAST(complaint_date AS DATE)                        AS complaint_date,
    TRIM(complaint_type)                                    AS complaint_type,
    TRIM(complaint_text)                                    AS complaint_text,
    TRIM(assigned_department)                               AS assigned_department,
    TRIM(resolution_status)                                 AS resolution_status,
    TRIM(corrective_action_taken)                           AS corrective_action_taken,
    CURRENT_TIMESTAMP                                       AS _loaded_at,
    'seed_partie1'                                          AS _source
FROM {{ ref('complaintlog') }}
WHERE complaint_id IS NOT NULL
