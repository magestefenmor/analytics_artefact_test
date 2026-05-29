

-- ================================================================
-- DIM_AIRPORTS
-- Source  : Business Vault
--   hub_airport + sat_airport_details (is_current direct)
--   Pas de PIT car 1 seul satellite
-- Grain   : 1 ligne par aéroport (version courante)
-- ================================================================

SELECT
    ha.airport_bk                                           AS airport_code,
    ha.airport_hk,

    -- Attributs (sat_airport_details direct — 1 seul satellite)
    sad.airport_name,
    sad.city,
    sad.country,
    sad.timezone,
    sad.latitude,
    sad.longitude,

    -- Région géographique
    CASE
        WHEN sad.country = 'Côte d''Ivoire'    THEN 'Côte d''Ivoire'
        WHEN sad.country IN (
            'Ghana','Sénégal','Burkina Faso',
            'Bénin','Guinée','Mali','Cameroun') THEN 'Afrique de l''Ouest'
        WHEN sad.country IN (
            'France','Maroc')                  THEN 'Europe / Maghreb'
        ELSE 'Autre'
    END                                                     AS region,

    sad.load_date                                           AS valid_from

FROM "dev"."main_vault"."hub_airports"                   ha
JOIN "dev"."main_vault"."sat_airport_details"           sad
    ON  sad.airport_hk = ha.airport_hk
    AND sad.is_current = 1