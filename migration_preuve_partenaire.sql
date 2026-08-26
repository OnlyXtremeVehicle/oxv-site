-- ============================================================
-- OXV — La boucle de preuve partenaire
-- ============================================================
-- « Le partenaire paie une preuve, pas une visibilité. »
--
-- La page partenaires promet publiquement, depuis sa mise en ligne : « Le
-- compte-rendu des essais réalisés, sous sept jours », et « ce que vous avez
-- fait, qui était là, ce que ça a produit — remis noir sur blanc sous sept
-- jours ». Rien ne l'implémentait.
--
-- CE QUI EXISTAIT DÉJÀ
--   public.b2b_event_reports (migration app 20260628180623) — la table de
--   compte-rendu, sa RLS éprouvée (le partenaire ne voit QUE son rapport
--   PARTAGÉ, jamais un brouillon) et ses tests RLS côté app.
--
-- LE POINT STRUCTUREL
--   Elle est accrochée à public.events, DÉPRÉCIÉE depuis le 2026-06-30
--   (décision produit Option A). Le commentaire de la table le dit lui-même :
--     « A SUPPRIMER apres migration code app (...) + repoint
--       b2b_event_reports.event_id & event_partners.event_id vers sessions.id »
--   Cette migration exécute ce repointage pour la partie compte-rendu. Elle
--   est NON DESTRUCTIVE : event_id est conservée, seulement rendue
--   facultative, et session_id devient le rattachement canonique.
--
-- CE QUE CETTE MIGRATION AJOUTE
--   1. Le rattachement canonique à la journée (public.sessions) ;
--   2. L'échéance contractuelle : date de la journée + 7 jours, CALCULÉE ;
--   3. La date de remise, distincte de updated_at — corriger une coquille ne
--      doit pas réécrire la date à laquelle la preuve a été remise ;
--   4. Le détail mesuré, en jsonb, figé à la remise ;
--   5. Deux fonctions : l'une CALCULE les chiffres depuis les données réelles
--      (aucun chiffre n'est jamais saisi à la main), l'autre REMET le rapport.
--
-- RÈGLE D'OR, reprise de l'application : une valeur non mesurée ne s'affiche
-- pas. Les fonctions renvoient null — jamais zéro — quand la mesure n'existe
-- pas, et le site affiche un tiret. Un partenariat se renouvelle sur la
-- preuve : un chiffre inventé vaut moins que pas de chiffre du tout.
--
-- Application : Supabase Studio → SQL Editor, ou `supabase db execute`.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Repointage vers le modèle canonique + cadre contractuel
-- ------------------------------------------------------------
ALTER TABLE public.b2b_event_reports
  ADD COLUMN IF NOT EXISTS session_id uuid REFERENCES public.sessions (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS due_on     date,
  ADD COLUMN IF NOT EXISTS shared_at  timestamptz,
  ADD COLUMN IF NOT EXISTS details    jsonb;

COMMENT ON COLUMN public.b2b_event_reports.session_id IS
  'Rattachement canonique a la journee (public.sessions). Remplace event_id, deprecie.';
COMMENT ON COLUMN public.b2b_event_reports.due_on IS
  'Echeance contractuelle : date de la journee + 7 jours. Calculee, jamais saisie.';
COMMENT ON COLUMN public.b2b_event_reports.shared_at IS
  'Date de remise au partenaire. Distincte de updated_at : corriger une coquille ne reecrit pas la date de remise.';
COMMENT ON COLUMN public.b2b_event_reports.details IS
  'Detail mesure, fige a la remise. Une valeur non mesuree vaut null, jamais zero.';

-- event_id devient facultative : les nouveaux rapports portent session_id.
ALTER TABLE public.b2b_event_reports ALTER COLUMN event_id DROP NOT NULL;

-- Un seul rapport par journée et par partenaire.
CREATE UNIQUE INDEX IF NOT EXISTS uq_b2b_reports_session_partner
  ON public.b2b_event_reports (session_id, partner_id)
  WHERE session_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_b2b_reports_due
  ON public.b2b_event_reports (due_on)
  WHERE status = 'draft';

-- ------------------------------------------------------------
-- 2. Le calcul de la preuve — depuis les données réelles
-- ------------------------------------------------------------
-- Aucun chiffre n'est saisi : tout est mesuré ici, et ce qui n'est pas
-- mesurable revient null. La fonction NE MODIFIE RIEN — l'administration lit
-- le résultat, le relit, puis décide de le figer.
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
  IF NOT public.is_admin() THEN
    RETURN json_build_object('ok', false, 'raison', 'reserve_administration');
  END IF;

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
      'exclusivite', v_engagement.exclusivity_category
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

REVOKE ALL ON FUNCTION public.oxv_build_partner_proof(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_build_partner_proof(uuid, uuid) TO authenticated;

-- ------------------------------------------------------------
-- 3. La remise — le geste qui rend la preuve opposable
-- ------------------------------------------------------------
-- Figer, pas recalculer : le partenaire doit pouvoir relire exactement ce qui
-- lui a été remis, même si les données bougent ensuite.
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
     SET status = 'shared',
         shared_at = coalesce(shared_at, now())
   WHERE id = p_report_id;

  RETURN json_build_object('ok', true, 'remis_le', now());
END $fn$;

REVOKE ALL ON FUNCTION public.oxv_share_partner_proof(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_share_partner_proof(uuid) TO authenticated;

COMMIT;

-- ============================================================
-- Vérification après application
-- ============================================================
-- 1. Les colonnes sont là :
--      SELECT column_name FROM information_schema.columns
--       WHERE table_name = 'b2b_event_reports' ORDER BY ordinal_position;
-- 2. Le calcul tourne (connecté en ADMIN), sur une journée et un partenaire réels :
--      SELECT public.oxv_build_partner_proof('<session_id>', '<partner_account_id>');
-- 3. La RLS tient : connecté en PARTENAIRE, un rapport 'draft' reste invisible,
--    un rapport 'shared' est lisible — et seulement le sien.
-- 4. Les journées dont la preuve est due :
--      SELECT s.date, s.date + 7 AS echeance FROM public.sessions s
--       WHERE s.date < current_date ORDER BY s.date DESC;
-- ============================================================
