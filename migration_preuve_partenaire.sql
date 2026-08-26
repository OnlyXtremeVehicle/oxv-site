-- ============================================================
-- OXV — La boucle de preuve partenaire, automatisée
-- ============================================================
-- « Le partenaire paie une preuve, pas une visibilité. »
--
-- La page partenaires promet publiquement « le compte-rendu des essais
-- réalisés, sous sept jours », et « ce que vous avez fait, qui était là, ce
-- que ça a produit — remis noir sur blanc ». Rien ne l'implémentait.
--
-- CE QUI EXISTAIT DÉJÀ
--   public.b2b_event_reports (migration app 20260628180623) — la table, et sa
--   RLS éprouvée : le partenaire ne voit QUE son rapport PARTAGÉ, jamais un
--   brouillon. Tests RLS côté app (b2bReportRLS.test.ts).
--
-- LE POINT STRUCTUREL
--   Elle est accrochée à public.events, DÉPRÉCIÉE depuis le 2026-06-30. Le
--   commentaire de la table le dit : « A SUPPRIMER (...) + repoint
--   b2b_event_reports.event_id & event_partners.event_id vers sessions.id ».
--   Cette migration exécute ce repointage. NON DESTRUCTIVE : event_id est
--   conservée, seulement rendue facultative.
--
-- CE QUE CETTE MIGRATION APPORTE
--   1. Le rattachement canonique à la journée (public.sessions) ;
--   2. L'échéance contractuelle CALCULÉE : date de la journée + 7 jours ;
--   3. La date de remise, distincte de updated_at ;
--   4. Le détail mesuré en jsonb, figé à la remise ;
--   5. Le calcul, entièrement automatique — aucun chiffre saisi à la main ;
--   6. LA GÉNÉRATION ET LA REMISE AUTOMATIQUES : une tâche quotidienne crée
--      les comptes-rendus dus et les remet à J+5, deux jours avant
--      l'échéance. La promesse des sept jours devient structurellement
--      intenable à manquer — sauf suspension explicite de l'administration ;
--   7. Les contacts consentis enfin LISIBLES par le partenaire.
--
-- LE MANQUE QUE LE POINT 7 COMBLE
--   Le site promet « les contacts des pilotes qui ont consenti, et eux
--   seuls ». Or partner_leads ne porte ni nom ni courriel, et la RLS de
--   public.users interdit au partenaire de remonter au pilote : il voyait
--   une ligne anonyme. La promesse était invendable. Une fonction
--   SECURITY DEFINER la tient, strictement bornée au consentement donné.
--
-- RÈGLE D'OR, reprise de l'application : une valeur non mesurée ne s'affiche
-- pas. Les fonctions renvoient null — jamais zéro — quand la mesure n'existe
-- pas, et le site affiche un tiret. Un chiffre inventé vaut moins que pas de
-- chiffre du tout, surtout sur un document contractuel.
--
-- Application : Supabase Studio → SQL Editor, ou `supabase db execute`.
-- Idempotente : rejouable sans dommage.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Repointage canonique + cadre contractuel
-- ------------------------------------------------------------
ALTER TABLE public.b2b_event_reports
  ADD COLUMN IF NOT EXISTS session_id         uuid REFERENCES public.sessions (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS due_on             date,
  ADD COLUMN IF NOT EXISTS shared_at          timestamptz,
  ADD COLUMN IF NOT EXISTS details            jsonb,
  ADD COLUMN IF NOT EXISTS auto_share_blocked boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.b2b_event_reports.session_id IS
  'Rattachement canonique a la journee (public.sessions). Remplace event_id, deprecie.';
COMMENT ON COLUMN public.b2b_event_reports.due_on IS
  'Echeance contractuelle : date de la journee + 7 jours. Calculee, jamais saisie.';
COMMENT ON COLUMN public.b2b_event_reports.shared_at IS
  'Date de remise. Distincte de updated_at : corriger une coquille ne reecrit pas la date de remise.';
COMMENT ON COLUMN public.b2b_event_reports.details IS
  'Detail mesure, fige a la remise. Une valeur non mesuree vaut null, jamais zero.';
COMMENT ON COLUMN public.b2b_event_reports.auto_share_blocked IS
  'Suspend la remise automatique (litige, journee atypique). Le defaut est de remettre : l inaction livre.';

ALTER TABLE public.b2b_event_reports ALTER COLUMN event_id DROP NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_b2b_reports_session_partner
  ON public.b2b_event_reports (session_id, partner_id)
  WHERE session_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_b2b_reports_due
  ON public.b2b_event_reports (due_on)
  WHERE status = 'draft';

-- ------------------------------------------------------------
-- 2. Le calcul — moteur interne, sans garde d'appelant
-- ------------------------------------------------------------
-- Séparé de la fonction publique pour une raison précise : la tâche
-- quotidienne s'exécute sans utilisateur connecté (auth.uid() est nul), donc
-- is_admin() y est faux. Un moteur interne, non exposé, sert les deux
-- appelants ; la garde vit dans l'enveloppe publique.
CREATE OR REPLACE FUNCTION public.oxv_calc_partner_proof(
  p_session_id uuid,
  p_partner_account_id uuid
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_ses        public.sessions;
  v_inscrits   integer;
  v_presents   integer;
  v_pointes    integer;
  v_contacts   integer;
  v_offres     integer;
  v_medias     integer;
  v_engagement public.partner_engagements;
BEGIN
  SELECT * INTO v_ses FROM public.sessions WHERE id = p_session_id;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'raison', 'journee_introuvable');
  END IF;

  -- Qui était inscrit, qui est venu. « Présent » = pointé à l'arrivée.
  SELECT count(*) FILTER (WHERE status NOT IN ('cancelled')),
         count(*) FILTER (WHERE status = 'attended'),
         count(*) FILTER (WHERE attended_at IS NOT NULL)
    INTO v_inscrits, v_presents, v_pointes
    FROM public.registrations
   WHERE session_id = p_session_id;

  -- Le pointage fait foi quand il a eu lieu ; sinon le statut. Si ni l'un ni
  -- l'autre n'a été renseigné, la présence n'a pas été mesurée : null.
  IF v_pointes > 0 THEN
    v_presents := v_pointes;
  ELSIF v_presents = 0 THEN
    v_presents := NULL;
  END IF;

  -- Contacts : uniquement ceux qui ont consenti, autour de la journée.
  SELECT count(*) INTO v_contacts
    FROM public.partner_leads
   WHERE partner_id = p_partner_account_id
     AND consent_contact IS TRUE
     AND created_at::date BETWEEN v_ses.date - 1 AND v_ses.date + 7;

  SELECT count(*) INTO v_offres
    FROM public.partner_offers
   WHERE partner_id = p_partner_account_id
     AND status = 'published';

  SELECT count(*) INTO v_medias
    FROM public.media
   WHERE session_id = p_session_id
     AND published_at IS NOT NULL;

  SELECT * INTO v_engagement
    FROM public.partner_engagements
   WHERE partner_account_id = p_partner_account_id
     AND status = 'active'
     AND (starts_on IS NULL OR starts_on <= v_ses.date)
     AND (ends_on   IS NULL OR ends_on   >= v_ses.date)
   ORDER BY starts_on DESC NULLS LAST
   LIMIT 1;

  RETURN json_build_object(
    'ok', true,
    'journee', json_build_object(
      'id', v_ses.id,
      'date', v_ses.date,
      'format', v_ses.format,
      'statut', v_ses.status,
      'capacite', v_ses.max_capacity
    ),
    'echeance', v_ses.date + 7,
    'engagement', CASE WHEN v_engagement.id IS NULL THEN NULL ELSE json_build_object(
      'formule', v_engagement.plan_key,
      'libelle', (SELECT label FROM public.partner_plans WHERE key = v_engagement.plan_key),
      'quantite', v_engagement.quantity,
      'exclusivite', v_engagement.exclusivity_category,
      'fin', v_engagement.ends_on
    ) END,
    'presence', json_build_object(
      'inscrits', v_inscrits,
      'presents', v_presents,
      'capacite', v_ses.max_capacity
    ),
    'production', json_build_object(
      'contacts_consentis', v_contacts,
      'offres_publiees', v_offres,
      'medias_journee', NULLIF(v_medias, 0)
    )
  );
END $fn$;

-- Moteur interne : jamais appelable depuis un navigateur.
REVOKE ALL ON FUNCTION public.oxv_calc_partner_proof(uuid, uuid) FROM public;
REVOKE ALL ON FUNCTION public.oxv_calc_partner_proof(uuid, uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.oxv_calc_partner_proof(uuid, uuid) FROM anon;

-- Enveloppe publique : l'administration peut recalculer à la demande.
CREATE OR REPLACE FUNCTION public.oxv_build_partner_proof(
  p_session_id uuid,
  p_partner_account_id uuid
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
BEGIN
  IF NOT public.is_admin() THEN
    RETURN json_build_object('ok', false, 'raison', 'reserve_administration');
  END IF;
  RETURN public.oxv_calc_partner_proof(p_session_id, p_partner_account_id);
END $fn$;

REVOKE ALL ON FUNCTION public.oxv_build_partner_proof(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_build_partner_proof(uuid, uuid) TO authenticated;

-- ------------------------------------------------------------
-- 3. La remise — le geste qui rend la preuve opposable
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.oxv_share_partner_proof(p_report_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE v_rep public.b2b_event_reports;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN json_build_object('ok', false, 'raison', 'reserve_administration');
  END IF;

  SELECT * INTO v_rep FROM public.b2b_event_reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'raison', 'rapport_introuvable');
  END IF;
  IF v_rep.status = 'shared' THEN
    RETURN json_build_object('ok', true, 'deja_remis', true, 'remis_le', v_rep.shared_at);
  END IF;

  UPDATE public.b2b_event_reports
     SET status = 'shared', shared_at = coalesce(shared_at, now())
   WHERE id = p_report_id;

  RETURN json_build_object('ok', true, 'remis_le', now());
END $fn$;

REVOKE ALL ON FUNCTION public.oxv_share_partner_proof(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_share_partner_proof(uuid) TO authenticated;

-- Suspendre ou réactiver la remise automatique d'un compte-rendu.
CREATE OR REPLACE FUNCTION public.oxv_hold_partner_proof(p_report_id uuid, p_hold boolean)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
BEGIN
  IF NOT public.is_admin() THEN
    RETURN json_build_object('ok', false, 'raison', 'reserve_administration');
  END IF;
  UPDATE public.b2b_event_reports SET auto_share_blocked = p_hold WHERE id = p_report_id;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'raison', 'rapport_introuvable');
  END IF;
  RETURN json_build_object('ok', true, 'suspendu', p_hold);
END $fn$;

REVOKE ALL ON FUNCTION public.oxv_hold_partner_proof(uuid, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_hold_partner_proof(uuid, boolean) TO authenticated;

-- ------------------------------------------------------------
-- 4. L'AUTOMATISATION — la promesse tenue sans intervention
-- ------------------------------------------------------------
-- Deux gestes, tous les jours :
--   a) créer le brouillon de chaque journée passée couverte par un engagement
--      actif, chiffres calculés ;
--   b) remettre à J+5 tout brouillon non suspendu — deux jours de marge avant
--      l'échéance des sept jours.
-- Le défaut est de LIVRER. Ne rien faire remet le compte-rendu ; il faut un
-- geste explicite (auto_share_blocked) pour le retenir. C'est l'inverse de
-- l'usage, et c'est voulu : une promesse contractuelle ne doit pas dépendre
-- de la disponibilité de quelqu'un un vendredi soir.
CREATE OR REPLACE FUNCTION public.oxv_generer_preuves_dues()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  r         record;
  v_calc    json;
  v_creees  integer := 0;
  v_remises integer := 0;
BEGIN
  -- a) Les brouillons manquants. Fenêtre de 90 jours : au-delà, une reprise
  -- se fait à la main, on ne réécrit pas l'histoire ancienne tout seul.
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

  -- b) La remise, deux jours avant l'échéance.
  UPDATE public.b2b_event_reports
     SET status = 'shared', shared_at = coalesce(shared_at, now())
   WHERE status = 'draft'
     AND auto_share_blocked = false
     AND session_id IS NOT NULL
     AND due_on IS NOT NULL
     AND current_date >= due_on - 2;
  GET DIAGNOSTICS v_remises = ROW_COUNT;

  RETURN json_build_object('ok', true, 'brouillons_crees', v_creees, 'remis', v_remises);
EXCEPTION WHEN others THEN
  RAISE WARNING '[oxv_generer_preuves_dues] %', sqlerrm;
  RETURN json_build_object('ok', false, 'raison', sqlerrm);
END $fn$;

REVOKE ALL ON FUNCTION public.oxv_generer_preuves_dues() FROM public;
REVOKE ALL ON FUNCTION public.oxv_generer_preuves_dues() FROM anon;
GRANT EXECUTE ON FUNCTION public.oxv_generer_preuves_dues() TO authenticated; -- relance manuelle admin

-- La tâche quotidienne, même convention que les autres jobs oxv-*.
DO $do$
BEGIN
  PERFORM cron.unschedule('oxv-preuve-partenaire');
EXCEPTION WHEN others THEN
  NULL; -- la tâche n'existait pas encore
END $do$;

SELECT cron.schedule(
  'oxv-preuve-partenaire',
  '15 6 * * *',
  $cron$ SELECT public.oxv_generer_preuves_dues(); $cron$
);

-- ------------------------------------------------------------
-- 5. Les contacts consentis, enfin lisibles par le partenaire
-- ------------------------------------------------------------
-- Le site promet « les contacts des pilotes qui ont consenti, et eux seuls ».
-- partner_leads ne porte ni nom ni courriel, et la RLS de public.users
-- interdit au partenaire de remonter au pilote : la promesse n'était pas
-- tenable. Cette fonction la tient, et rien de plus :
--   · le consentement du pilote est la seule clé — consent_contact = true ;
--   · le demandeur doit posséder le compte partenaire (ou être admin) ;
--   · aucun pilote non consentant n'apparaît, jamais, même en nombre ;
--   · retirer le consentement fait disparaître le contact au prochain appel.
CREATE OR REPLACE FUNCTION public.oxv_partner_consented_contacts(
  p_partner_account_id uuid,
  p_from date DEFAULT NULL,
  p_to   date DEFAULT NULL
)
RETURNS TABLE (
  lead_id     uuid,
  prenom      text,
  nom         text,
  email       text,
  telephone   text,
  consenti_le timestamptz,
  canal       text,
  statut      text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
  SELECT l.id,
         u.first_name,
         u.last_name,
         u.email,
         u.phone,
         coalesce(l.consent_at, l.created_at),
         l.channel,
         l.status
    FROM public.partner_leads l
    JOIN public.users u ON u.id = l.pilot_id
   WHERE l.partner_id = p_partner_account_id
     AND l.consent_contact IS TRUE
     AND (public.owns_partner_account(p_partner_account_id) OR public.is_admin())
     AND (p_from IS NULL OR l.created_at::date >= p_from)
     AND (p_to   IS NULL OR l.created_at::date <= p_to)
   ORDER BY coalesce(l.consent_at, l.created_at) DESC;
$fn$;

REVOKE ALL ON FUNCTION public.oxv_partner_consented_contacts(uuid, date, date) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_partner_consented_contacts(uuid, date, date) TO authenticated;

COMMIT;

-- ============================================================
-- Vérification après application
-- ============================================================
-- 1. Colonnes et tâche en place :
--      SELECT column_name FROM information_schema.columns
--       WHERE table_name = 'b2b_event_reports' ORDER BY ordinal_position;
--      SELECT jobname, schedule FROM cron.job WHERE jobname = 'oxv-preuve-partenaire';
--
-- 2. Lancer l'automatisation à la main, une fois, pour voir ce qu'elle produit :
--      SELECT public.oxv_generer_preuves_dues();
--      -- { "ok": true, "brouillons_crees": n, "remis": m }
--      -- n = 0 tant qu'aucun engagement partenaire n'est enregistre : c'est
--      --     normal, la boucle suit le contrat.
--
-- 3. La RLS tient — connecte en PARTENAIRE :
--      SELECT id, status FROM public.b2b_event_reports;   -- que les 'shared', les siens
--      SELECT * FROM public.oxv_partner_consented_contacts('<son partner_account_id>');
--      SELECT * FROM public.oxv_partner_consented_contacts('<celui d un autre>'); -- 0 ligne
--
-- 4. Le moteur interne n'est pas joignable depuis un navigateur :
--      SELECT public.oxv_calc_partner_proof('<s>','<p>');  -- permission denied
-- ============================================================
