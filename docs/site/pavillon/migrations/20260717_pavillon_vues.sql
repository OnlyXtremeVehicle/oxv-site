-- ============================================================
-- OXV — Migration : vues Pavillon (écrans site web)
-- Lot : ECRANS_PAVILLON
-- À exécuter APRÈS validation par M. Fillat et APRÈS la
-- migration 20260717_profil_pavillon.sql (dépendance :
-- users.car_number, users.pavilion_name_optin).
-- ============================================================

-- ------------------------------------------------------------
-- 1. Vue pseudonymisée des pilotes du jour (écran ACCUEIL)
--    La pseudonymisation est appliquée CÔTÉ SERVEUR :
--    le client d'affichage ne reçoit JAMAIS le nom complet
--    d'un pilote sans opt-in. Prénom + initiale uniquement
--    même en opt-in (écran public).
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW public.pavillon_pilotes_jour
WITH (security_invoker = false) AS
SELECT
  u.id                                   AS user_id,
  u.car_number,
  u.public_handle,
  CASE
    WHEN u.pavilion_name_optin
    THEN u.first_name || ' ' || left(u.last_name, 1) || '.'
    ELSE NULL
  END                                    AS display_name,
  v.brand || ' ' || v.model              AS vehicle_label,
  ts.id                                  AS telemetry_session_id,
  ts.status                              AS session_status,
  ts.started_at
FROM public.telemetry_sessions ts
JOIN public.users u    ON u.id = ts.user_id
LEFT JOIN public.vehicles v ON v.id = ts.vehicle_id
WHERE ts.started_at::date = CURRENT_DATE;

-- IMPORTANT SÉCURITÉ : security_invoker = false rend la vue
-- SECURITY DEFINER. Restreindre le grant au seul rôle affichage :
REVOKE ALL ON public.pavillon_pilotes_jour FROM anon, authenticated;

-- ------------------------------------------------------------
-- 2. Rôle de session « affichage Pavillon »
--    Le poste TV se connecte avec un compte utilisateur dédié
--    (users.role = 'display'), créé manuellement par le staff.
--    Le grant SELECT est accordé à authenticated + policy sur
--    une table de contrôle, OU (option simple retenue) :
--    le grant est donné à authenticated et la vue ne contient
--    par construction AUCUNE donnée sensible (pseudonymisée).
-- ------------------------------------------------------------
GRANT SELECT ON public.pavillon_pilotes_jour TO authenticated;

-- ------------------------------------------------------------
-- 3. Vue météo du jour (écran ACCUEIL) — dernière snapshot
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW public.pavillon_meteo AS
SELECT DISTINCT ON (ws.session_id)
  ws.session_id,
  ws.captured_at,
  ws.temperature_c,
  ws.wind_speed_kmh,
  ws.wind_direction_deg,
  ws.precipitation_mm,
  ws.weather_label
FROM public.weather_snapshots ws
WHERE ws.captured_at::date = CURRENT_DATE
ORDER BY ws.session_id, ws.captured_at DESC;

GRANT SELECT ON public.pavillon_meteo TO authenticated;

-- ------------------------------------------------------------
-- 4. NOTE — CONTRAT QDI (à valider, TODO_ARBITRAGE)
--    app_session_analyses.qdi est NULL sur toutes les lignes
--    au 17/07/2026. Contrat jsonb proposé, à faire respecter
--    par le pipeline de calcul :
--    {
--      "version": 1,
--      "axes": {
--        "cap":          { "value": 0-100, "reference": 0-100 },
--        "trajectoire":  { "value": 0-100, "reference": 0-100 },
--        "visee":        { "value": 0-100, "reference": 0-100 },
--        "plongee":      { "value": 0-100, "reference": 0-100 },
--        "anticipation": { "value": 0-100, "reference": 0-100 }
--      }
--    }
--    AUCUN champ de score global — interdit par doctrine.
-- ------------------------------------------------------------
