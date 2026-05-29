

-- LINK FLIGHT_INCIDENT
-- Relation : un incident (ticket support ou plainte) lié à un client
-- Sources  : hub_customer via stg_support_tickets + stg_complaint_logs
-- Grain    : 1 ligne par incident (ticket ou plainte)

WITH tickets AS (
    SELECT
        ticket_id               AS incident_bk,
        customer_id,
        NULL                    AS flight_id,
        'ticket'                AS incident_type,
        _source
    FROM "dev"."main_staging"."stg_support_tickets"
    WHERE ticket_id IS NOT NULL

    UNION ALL

    SELECT
        complaint_id            AS incident_bk,
        customer_id,
        flight_id,
        'complaint'             AS incident_type,
        _source
    FROM "dev"."main_staging"."stg_complaint_logs"
    WHERE complaint_id IS NOT NULL
)

SELECT
    SHA256(
        UPPER(TRIM(COALESCE(CAST(incident_bk  AS VARCHAR), 'UNKNOWN')))
        || '||' ||
        UPPER(TRIM(COALESCE(CAST(customer_id  AS VARCHAR), 'UNKNOWN')))
    )                           AS lnk_flight_incident_hk,
    SHA256(UPPER(TRIM(COALESCE(CAST(incident_bk  AS VARCHAR), 'UNKNOWN'))))
                                AS incident_bk,
    SHA256(UPPER(TRIM(COALESCE(CAST(customer_id  AS VARCHAR), 'UNKNOWN'))))
                                AS customer_hk,
    SHA256(UPPER(TRIM(COALESCE(CAST(flight_id    AS VARCHAR), 'UNKNOWN'))))
                                AS flight_hk,
    incident_type,
    CURRENT_DATE                AS load_date,
    _source                     AS record_source
FROM tickets