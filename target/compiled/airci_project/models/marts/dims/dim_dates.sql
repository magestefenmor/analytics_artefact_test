

-- ================================================================
-- DIM_DATES
-- Source  : générée via DuckDB range — pas de vault
-- Dimension technique pure, pas d'entité métier historisable
-- Grain   : 1 ligne par jour (2024-01-01 → 2025-12-31)
-- ================================================================

WITH date_spine AS (
    SELECT CAST(RANGE AS DATE) AS date_id
    FROM RANGE(DATE '2024-01-01', DATE '2026-01-01', INTERVAL '1 DAY')
)

SELECT
    date_id,
    YEAR(date_id)                                           AS year,
    MONTH(date_id)                                          AS month,
    DAY(date_id)                                            AS day,
    QUARTER(date_id)                                        AS quarter,
    STRFTIME(date_id, '%B')                                 AS month_name,
    STRFTIME(date_id, '%A')                                 AS day_of_week,
    DAYOFWEEK(date_id)                                      AS day_of_week_num,
    CASE WHEN DAYOFWEEK(date_id) IN (0, 6)
         THEN 1 ELSE 0 END                                  AS is_weekend,
    WEEKOFYEAR(date_id)                                     AS week_of_year,
    CASE
        WHEN MONTH(date_id) IN (12, 1, 2)  THEN 'Grande saison sèche'
        WHEN MONTH(date_id) IN (3, 4, 5)   THEN 'Grande saison des pluies'
        WHEN MONTH(date_id) IN (6, 7)      THEN 'Petite saison sèche'
        WHEN MONTH(date_id) IN (8, 9, 10)  THEN 'Petite saison des pluies'
        ELSE 'Novembre'
    END                                                     AS season,
    CASE
        WHEN MONTH(date_id) = 1  AND DAY(date_id) = 1  THEN 1
        WHEN MONTH(date_id) = 5  AND DAY(date_id) = 1  THEN 1
        WHEN MONTH(date_id) = 8  AND DAY(date_id) = 7  THEN 1
        WHEN MONTH(date_id) = 11 AND DAY(date_id) = 1  THEN 1
        WHEN MONTH(date_id) = 12 AND DAY(date_id) = 25 THEN 1
        ELSE 0
    END                                                     AS is_holiday
FROM date_spine