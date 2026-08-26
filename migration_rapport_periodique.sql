-- ============================================================
-- OXV — Le bilan de période (Atelier Officiel) + le consentement au check-in
-- ============================================================
-- À APPLIQUER APRÈS migration_preuve_partenaire.sql ET
-- migration_audience_partenaire.sql (elle remplace la tâche quotidienne).
-- Idempotente, rejouable.
--
-- POURQUOI UN BILAN DE PÉRIODE
--   Constat fondateur : une seule journée porte peu de matière. Vingt pilotes,
--   quelques contacts, une poignée de regards — le compte-rendu à sept jours
--   reste juste, mais il est maigre. Additionné sur un trimestre, le même
--   partenariat devient lisible : des dizaines de pilotes, une tendance, une
--   valeur qu'on peut discuter en reconduction.
--
-- QUI Y A DROIT — ET QUI N'Y A PAS DROIT
--   L'Atelier Officiel SEUL. C'est la formule annuelle et exclusive : un seul
--   titulaire par saison. Le bilan cumulé est son avantage propre, et une
--   raison de plus de le prendre plutôt qu'une journée isolée.
--   Les autres formules gardent leur compte-rendu à sept jours, journée par
--   journée — c'est ce que le site leur promet, et cela ne change pas.
--   L'accès est verrouillé par la donnée elle-même : aucun bilan n'est produit
--   pour une autre formule, donc il n'y a rien à lire. La RLS fait le reste.
--
-- ⚠️ POINT À TRANCHER PAR LE FONDATEUR
--   La page partenaires promet au « Partenaire Application » : « Une audience
--   identifiée, pas une impression publicitaire ». Cette promesse porte sur
--   l'audience, que cette formule continue donc de recevoir dans son
--   compte-rendu. Si l'intention est de la réserver aussi à l'Atelier
--   Officiel, c'est la PAGE qu'il faut corriger d'abord — on ne retire pas en
--   silence un accès déjà annoncé publiquement.
--
-- LE CONSENTEMENT AU CHECK-IN
--   Décision fondateur : le consentement partenaire se donne au pointage
--   d'arrivée, dans l'application — pas sur un QR séparé. La fonction
--   ci-dessous est le contrat serveur de cet écran : le pilote coche les
--   partenaires qu'il accepte, décoche les autres, et peut changer d'avis à
--   tout moment. Le canal est 'qr_event', déjà prévu par la contrainte.
--
-- Application : Supabase Studio → SQL Editor.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Le bilan de période
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.partner_period_reports (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id         uuid NOT NULL REFERENCES public.partner_accounts (id) ON DELETE CASCADE,
  period_start       date NOT NULL,
  period_end         date NOT NULL,
  cadence            text NOT NULL DEFAULT 'trimestriel'
                       CHECK (cadence IN ('mensuel','trimestriel')),
  details            jsonb,
  conclusion         text,
  status             public.b2b_report_status NOT NULL DEFAULT 'draft',
  due_on             date,
  shared_at          timestamptz,
  auto_share_blocked boolean NOT NULL DEFAULT false,
  generated_at       timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (partner_id, period_start, period_end)
);

COMMENT ON TABLE public.partner_period_reports IS
  'Bilan cumule (trimestriel par defaut) reserve a la formule atelier_officiel. Les autres formules gardent le compte-rendu par journee.';

CREATE INDEX IF NOT EXISTS idx_period_reports_partner
  ON public.partner_period_reports (partner_id, period_end DESC);

ALTER TABLE public.partner_period_reports ENABLE ROW LEVEL SECURITY;

-- Meme regle que les comptes-rendus de journee : le partenaire ne voit que le
-- sien, et seulement une fois REMIS. Un brouillon ne se montre pas.
DROP POLICY IF EXISTS period_reports_admin_all ON public.partner_period_reports;
CREATE POLICY period_reports_admin_all ON public.partner_period_reports
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS period_reports_partner_select ON public.partner_period_reports;
CREATE POLICY period_reports_partner_select ON public.partner_period_reports
  FOR SELECT USING (public.owns_partner_account(partner_id) AND status = 'shared');

-- ------------------------------------------------------------
-- 2. Le calcul du bilan — moteur interne
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.oxv_calc_partner_period(
  p_partner_account_id uuid,
  p_from date,
  p_to   date
)
RETURNS json
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
  -- Tout en CTE, aucune table temporaire : une fonction STABLE ne peut rien
  -- ecrire, pas meme un scratch. `jours` = les journees de la periode que
  -- l'engagement du partenaire couvrait reellement.
  WITH jours AS (
    SELECT DISTINCT s.id, s.date AS jour
      FROM public.sessions s
      JOIN public.partner_engagements e
        ON e.partner_account_id = p_partner_account_id
       AND e.status = 'active'
       AND (e.starts_on IS NULL OR e.starts_on <= s.date)
       AND (e.ends_on   IS NULL OR e.ends_on   >= s.date)
     WHERE s.date BETWEEN p_from AND p_to
       AND s.status::text <> 'cancelled'
  ),
  presence AS (
    SELECT NULLIF(count(*) FILTER (WHERE r.status NOT IN ('cancelled')), 0) AS inscrits,
           NULLIF(count(*) FILTER (WHERE r.attended_at IS NOT NULL
                                      OR r.status = 'attended'), 0) AS presents
      FROM public.registrations r
     WHERE r.session_id IN (SELECT id FROM jours)
  ),
  medias AS (
    SELECT NULLIF(count(*), 0) AS n
      FROM public.media
     WHERE session_id IN (SELECT id FROM jours)
       AND published_at IS NOT NULL
  ),
  contacts AS (
    SELECT count(*) AS n
      FROM public.partner_leads
     WHERE partner_id = p_partner_account_id
       AND consent_contact IS TRUE
       AND created_at::date BETWEEN p_from AND p_to
  ),
  aud AS (
    SELECT json_build_object(
             'fiches',    NULLIF(count(*) FILTER (WHERE kind = 'fiche'), 0),
             'offres',    NULLIF(count(*) FILTER (WHERE kind = 'offre'), 0),
             'sites',     NULLIF(count(*) FILTER (WHERE kind = 'site'), 0),
             'contacts',  NULLIF(count(*) FILTER (WHERE kind = 'contact'), 0),
             'personnes', NULLIF(count(DISTINCT empreinte), 0)
           ) AS j
      FROM public.partner_touchpoints
     WHERE partner_id = p_partner_account_id
       AND jour BETWEEN p_from AND p_to
  ),
  satis AS (
    -- Trois reponses minimum sur toute la periode, sinon rien : en deca, un
    -- avis serait attribuable a une personne.
    SELECT CASE WHEN count(*) >= 3
                THEN json_build_object('reponses', count(*),
                                       'note', round(avg(rating)::numeric, 1),
                                       'recommandation', round(avg(nps)::numeric, 1))
                ELSE NULL END AS j
      FROM public.session_feedback
     WHERE session_id IN (SELECT id FROM jours)
       AND rating IS NOT NULL
  ),
  detail AS (
    -- Journee par journee : un bilan doit pouvoir se verifier.
    SELECT json_agg(json_build_object('date', j.jour, 'presents', p.n) ORDER BY j.jour) AS j
      FROM jours j
      LEFT JOIN LATERAL (
        SELECT NULLIF(count(*) FILTER (WHERE r.attended_at IS NOT NULL
                                          OR r.status = 'attended'), 0) AS n
          FROM public.registrations r WHERE r.session_id = j.id
      ) p ON true
  ),
  formule AS (
    SELECT e.plan_key
      FROM public.partner_engagements e
     WHERE e.partner_account_id = p_partner_account_id
       AND e.status = 'active'
     ORDER BY e.starts_on DESC NULLS LAST
     LIMIT 1
  )
  SELECT json_build_object(
    'ok', true,
    'periode', json_build_object('debut', p_from, 'fin', p_to),
    'formule', (SELECT plan_key FROM formule),
    'libelle', (SELECT label FROM public.partner_plans
                 WHERE key = (SELECT plan_key FROM formule)),
    'journees', NULLIF((SELECT count(*) FROM jours), 0),
    'presence', json_build_object('inscrits', (SELECT inscrits FROM presence),
                                  'presents', (SELECT presents FROM presence)),
    'production', json_build_object('contacts_consentis', (SELECT n FROM contacts),
                                    'medias', (SELECT n FROM medias)),
    'audience', (SELECT j FROM aud),
    'satisfaction', (SELECT j FROM satis),
    'journees_detail', (SELECT j FROM detail)
  );
$fn$;

REVOKE ALL ON FUNCTION public.oxv_calc_partner_period(uuid, date, date) FROM public;
REVOKE ALL ON FUNCTION public.oxv_calc_partner_period(uuid, date, date) FROM authenticated;
REVOKE ALL ON FUNCTION public.oxv_calc_partner_period(uuid, date, date) FROM anon;

-- Enveloppe publique, pour un recalcul a la demande depuis l'administration.
CREATE OR REPLACE FUNCTION public.oxv_build_partner_period(
  p_partner_account_id uuid, p_from date, p_to date
)
RETURNS json
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
  IF NOT public.is_admin() THEN
    RETURN json_build_object('ok', false, 'raison', 'reserve_administration');
  END IF;
  RETURN public.oxv_calc_partner_period(p_partner_account_id, p_from, p_to);
END $fn$;

REVOKE ALL ON FUNCTION public.oxv_build_partner_period(uuid, date, date) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_build_partner_period(uuid, date, date) TO authenticated;

CREATE OR REPLACE FUNCTION public.oxv_share_partner_period(p_report_id uuid)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_rep public.partner_period_reports;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN json_build_object('ok', false, 'raison', 'reserve_administration');
  END IF;
  SELECT * INTO v_rep FROM public.partner_period_reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'raison', 'rapport_introuvable');
  END IF;
  IF v_rep.status = 'shared' THEN
    RETURN json_build_object('ok', true, 'deja_remis', true, 'remis_le', v_rep.shared_at);
  END IF;
  UPDATE public.partner_period_reports
     SET status = 'shared', shared_at = coalesce(shared_at, now()), updated_at = now()
   WHERE id = p_report_id;
  RETURN json_build_object('ok', true, 'remis_le', now());
END $fn$;

REVOKE ALL ON FUNCTION public.oxv_share_partner_period(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_share_partner_period(uuid) TO authenticated;

-- ------------------------------------------------------------
-- 3. La tâche quotidienne prend en charge le bilan de période
-- ------------------------------------------------------------
-- Remplace la version de migration_preuve_partenaire.sql : trois gestes au
-- lieu de deux. Le trimestre écoulé est bilanté dès qu'il est clos ; comme
-- pour la journée, le défaut est de LIVRER, à J+5 de l'échéance.
CREATE OR REPLACE FUNCTION public.oxv_generer_preuves_dues()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  r          record;
  v_calc     json;
  v_creees   integer := 0;
  v_remises  integer := 0;
  v_bilans   integer := 0;
  v_bremis   integer := 0;
  v_tri_fin  date;
  v_tri_deb  date;
BEGIN
  -- a) Les comptes-rendus de journee manquants.
  FOR r IN
    SELECT s.id AS session_id, s.date AS jour, e.partner_account_id
      FROM public.sessions s
      JOIN public.partner_engagements e
        ON e.status = 'active'
       AND (e.starts_on IS NULL OR e.starts_on <= s.date)
       AND (e.ends_on   IS NULL OR e.ends_on   >= s.date)
     WHERE s.date < current_date
       AND s.date >= current_date - 90
       AND s.status::text <> 'cancelled'
       AND NOT EXISTS (
             SELECT 1 FROM public.b2b_event_reports br
              WHERE br.session_id = s.id AND br.partner_id = e.partner_account_id)
  LOOP
    v_calc := public.oxv_calc_partner_proof(r.session_id, r.partner_account_id);
    CONTINUE WHEN NOT coalesce((v_calc->>'ok')::boolean, false);

    INSERT INTO public.b2b_event_reports
      (session_id, partner_id, status, due_on, details, registered_count, checked_in_count)
    VALUES
      (r.session_id, r.partner_account_id, 'draft', r.jour + 7, v_calc,
       coalesce((v_calc->'presence'->>'inscrits')::int, 0),
       coalesce((v_calc->'presence'->>'presents')::int, 0))
    ON CONFLICT DO NOTHING;

    v_creees := v_creees + 1;
  END LOOP;

  -- b) La remise des comptes-rendus de journee, deux jours avant l'echeance.
  UPDATE public.b2b_event_reports
     SET status = 'shared', shared_at = coalesce(shared_at, now())
   WHERE status = 'draft'
     AND auto_share_blocked = false
     AND session_id IS NOT NULL
     AND due_on IS NOT NULL
     AND current_date >= due_on - 2;
  GET DIAGNOSTICS v_remises = ROW_COUNT;

  -- c) Le bilan du trimestre ecoule — Atelier Officiel SEUL.
  v_tri_fin := (date_trunc('quarter', current_date)::date - 1);
  v_tri_deb := date_trunc('quarter', v_tri_fin)::date;

  FOR r IN
    SELECT DISTINCT e.partner_account_id
      FROM public.partner_engagements e
     WHERE e.status = 'active'
       AND e.plan_key = 'atelier_officiel'
       AND (e.starts_on IS NULL OR e.starts_on <= v_tri_fin)
       AND (e.ends_on   IS NULL OR e.ends_on   >= v_tri_deb)
       AND NOT EXISTS (
             SELECT 1 FROM public.partner_period_reports pr
              WHERE pr.partner_id = e.partner_account_id
                AND pr.period_start = v_tri_deb AND pr.period_end = v_tri_fin)
  LOOP
    v_calc := public.oxv_calc_partner_period(r.partner_account_id, v_tri_deb, v_tri_fin);
    CONTINUE WHEN NOT coalesce((v_calc->>'ok')::boolean, false);

    INSERT INTO public.partner_period_reports
      (partner_id, period_start, period_end, cadence, details, status, due_on)
    VALUES
      (r.partner_account_id, v_tri_deb, v_tri_fin, 'trimestriel', v_calc, 'draft', v_tri_fin + 7)
    ON CONFLICT DO NOTHING;

    v_bilans := v_bilans + 1;
  END LOOP;

  UPDATE public.partner_period_reports
     SET status = 'shared', shared_at = coalesce(shared_at, now()), updated_at = now()
   WHERE status = 'draft'
     AND auto_share_blocked = false
     AND due_on IS NOT NULL
     AND current_date >= due_on - 2;
  GET DIAGNOSTICS v_bremis = ROW_COUNT;

  RETURN json_build_object('ok', true,
    'brouillons_crees', v_creees, 'remis', v_remises,
    'bilans_crees', v_bilans, 'bilans_remis', v_bremis);
EXCEPTION WHEN others THEN
  RAISE WARNING '[oxv_generer_preuves_dues] %', sqlerrm;
  RETURN json_build_object('ok', false, 'raison', sqlerrm);
END $fn$;

REVOKE ALL ON FUNCTION public.oxv_generer_preuves_dues() FROM public;
REVOKE ALL ON FUNCTION public.oxv_generer_preuves_dues() FROM anon;
GRANT EXECUTE ON FUNCTION public.oxv_generer_preuves_dues() TO authenticated;

-- ------------------------------------------------------------
-- 4. Le consentement partenaire, donné au check-in
-- ------------------------------------------------------------
-- Décision fondateur : plus de QR séparé — le pilote coche les partenaires
-- au pointage d'arrivée, dans l'application. Ce qui compte ici :
--   · seul un pilote INSCRIT à cette journée peut consentir ;
--   · seuls les partenaires réellement engagés ce jour-là sont éligibles ;
--   · la liste fait foi : décocher retire le consentement. Un accord se
--     reprend aussi facilement qu'il se donne, sinon ce n'est pas un accord.
CREATE OR REPLACE FUNCTION public.oxv_consent_partners_at_checkin(
  p_session_id  uuid,
  p_partner_ids uuid[]
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_uid      uuid := auth.uid();
  v_jour     date;
  v_donnes   integer := 0;
  v_retires  integer := 0;
  v_pid      uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('ok', false, 'raison', 'non_connecte');
  END IF;

  SELECT s.date INTO v_jour
    FROM public.sessions s
    JOIN public.registrations r ON r.session_id = s.id
   WHERE s.id = p_session_id
     AND r.user_id = v_uid
     AND r.status NOT IN ('cancelled')
   LIMIT 1;

  IF v_jour IS NULL THEN
    RETURN json_build_object('ok', false, 'raison', 'pas_inscrit_a_cette_journee');
  END IF;

  -- Les partenaires coches : on inscrit ou on ravive le consentement.
  FOREACH v_pid IN ARRAY coalesce(p_partner_ids, ARRAY[]::uuid[]) LOOP
    CONTINUE WHEN NOT EXISTS (
      SELECT 1 FROM public.partner_engagements e
       WHERE e.partner_account_id = v_pid
         AND e.status = 'active'
         AND (e.starts_on IS NULL OR e.starts_on <= v_jour)
         AND (e.ends_on   IS NULL OR e.ends_on   >= v_jour));

    IF EXISTS (SELECT 1 FROM public.partner_leads l
                WHERE l.partner_id = v_pid AND l.pilot_id = v_uid) THEN
      UPDATE public.partner_leads
         SET consent_contact = true, consent_at = coalesce(consent_at, now()), updated_at = now()
       WHERE partner_id = v_pid AND pilot_id = v_uid;
    ELSE
      INSERT INTO public.partner_leads
        (partner_id, pilot_id, consent_contact, consent_at, channel, status)
      VALUES (v_pid, v_uid, true, now(), 'qr_event', 'new');
    END IF;
    v_donnes := v_donnes + 1;
  END LOOP;

  -- Les partenaires engages ce jour-la mais NON coches : le consentement est
  -- retire. La liste fait foi.
  UPDATE public.partner_leads l
     SET consent_contact = false, updated_at = now()
    FROM public.partner_engagements e
   WHERE l.pilot_id = v_uid
     AND l.partner_id = e.partner_account_id
     AND e.status = 'active'
     AND (e.starts_on IS NULL OR e.starts_on <= v_jour)
     AND (e.ends_on   IS NULL OR e.ends_on   >= v_jour)
     AND l.consent_contact IS TRUE
     AND NOT (l.partner_id = ANY (coalesce(p_partner_ids, ARRAY[]::uuid[])));
  GET DIAGNOSTICS v_retires = ROW_COUNT;

  RETURN json_build_object('ok', true, 'accordes', v_donnes, 'retires', v_retires);
END $fn$;

REVOKE ALL ON FUNCTION public.oxv_consent_partners_at_checkin(uuid, uuid[]) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_consent_partners_at_checkin(uuid, uuid[]) TO authenticated;

-- Les partenaires a proposer au pointage : ceux reellement engages ce jour-la.
CREATE OR REPLACE FUNCTION public.oxv_partners_of_session(p_session_id uuid)
RETURNS TABLE (partner_id uuid, nom text, type text, logo_url text, deja_consenti boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
  SELECT pa.id, pa.display_name, pa.type, pa.logo_url,
         EXISTS (SELECT 1 FROM public.partner_leads l
                  WHERE l.partner_id = pa.id AND l.pilot_id = auth.uid()
                    AND l.consent_contact IS TRUE)
    FROM public.sessions s
    JOIN public.partner_engagements e
      ON e.status = 'active'
     AND (e.starts_on IS NULL OR e.starts_on <= s.date)
     AND (e.ends_on   IS NULL OR e.ends_on   >= s.date)
    JOIN public.partner_accounts pa ON pa.id = e.partner_account_id
   WHERE s.id = p_session_id
     AND pa.status = 'validated'
     AND EXISTS (SELECT 1 FROM public.registrations r
                  WHERE r.session_id = s.id AND r.user_id = auth.uid()
                    AND r.status NOT IN ('cancelled'))
   ORDER BY pa.display_name;
$fn$;

REVOKE ALL ON FUNCTION public.oxv_partners_of_session(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_partners_of_session(uuid) TO authenticated;

COMMIT;

-- ============================================================
-- Côté application — l'écran de pointage
-- ============================================================
--   const { data: partenaires } = await supabase
--     .rpc('oxv_partners_of_session', { p_session_id: session.id });
--   // -> [{ partner_id, nom, type, logo_url, deja_consenti }]
--   // Le pilote coche/décoche, puis :
--   await supabase.rpc('oxv_consent_partners_at_checkin', {
--     p_session_id:  session.id,
--     p_partner_ids: coches.map(p => p.partner_id),   // [] = je ne consens à aucun
--   });
-- Décocher retire le consentement : le contact disparaît de l'espace du
-- partenaire au prochain chargement.
-- ============================================================

-- ============================================================
-- Vérification après application
-- ============================================================
-- 1. La tâche fait bien quatre gestes :
--      SELECT public.oxv_generer_preuves_dues();
--      -- { ok, brouillons_crees, remis, bilans_crees, bilans_remis }
-- 2. Un bilan ne se produit QUE pour atelier_officiel :
--      SELECT pr.*, e.plan_key FROM public.partner_period_reports pr
--        JOIN public.partner_engagements e ON e.partner_account_id = pr.partner_id;
--      -- plan_key doit valoir 'atelier_officiel' partout
-- 3. Connecté en PARTENAIRE non-atelier : aucun bilan visible.
--      SELECT count(*) FROM public.partner_period_reports;  -- 0
-- 4. Le consentement au pointage, connecté en PILOTE inscrit :
--      SELECT public.oxv_consent_partners_at_checkin('<session>', ARRAY['<partenaire>']::uuid[]);
--      SELECT public.oxv_consent_partners_at_checkin('<session>', ARRAY[]::uuid[]);  -- retire
-- ============================================================
