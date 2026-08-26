-- ============================================================
-- OXV — L'audience partenaire : ce qui a été vu, cliqué, demandé
-- ============================================================
-- À APPLIQUER APRÈS migration_preuve_partenaire.sql (elle en remplace une
-- fonction). Idempotente, rejouable.
--
-- LE CONSTAT
--   Le site promet au partenaire « une audience identifiée, pas une
--   impression publicitaire ». Or RIEN n'était mesuré : window.track()
--   n'envoie qu'à Vercel Analytics et Plausible — deux services externes,
--   agrégés au domaine, incapables de dire ce qui concerne UN partenaire.
--   Aucune table de première main n'existait. La promesse n'était pas
--   vérifiable, donc pas vendable.
--
-- CE QUE CETTE MIGRATION MESURE
--   Un entonnoir, du regard à l'accord :
--     fiche   → la fiche du partenaire a été ouverte
--     offre   → une de ses offres a été consultée
--     site    → un clic est parti vers son site
--     contact → une mise en relation a été demandée
--   puis, déjà en place, le contact consenti (partner_leads).
--
-- LE PARTI PRIS QUI CHANGE TOUT : DES PERSONNES, PAS DES CLICS
--   La clé d'unicité est (partenaire, nature, JOUR, empreinte). Une même
--   personne qui ouvre dix fois la même fiche dans la journée compte pour
--   une. On ne rapporte donc pas un volume de clics — gonflable, et faux
--   dès qu'un curieux s'acharne — mais un nombre de personnes distinctes.
--   C'est plus honnête, plus difficile à truquer, et bien plus parlant :
--   « dix-sept personnes ont ouvert votre fiche » vaut mieux que
--   « quarante-trois clics ».
--
-- VIE PRIVÉE
--   L'empreinte est un identifiant aléatoire tiré par le navigateur ou
--   l'application, sans rapport avec une identité. user_id n'est renseigné
--   que si la personne est connectée, et n'est JAMAIS restitué au
--   partenaire : il ne sert qu'à purger sur demande d'effacement. Le
--   partenaire ne reçoit que des nombres. Les seules identités qu'il obtient
--   restent celles des pilotes ayant explicitement consenti
--   (oxv_partner_consented_contacts).
--
-- LA SATISFACTION DE LA JOURNÉE
--   Ajoutée au compte-rendu : note moyenne et recommandation, agrégées,
--   et SEULEMENT à partir de trois réponses — en deçà, un avis serait
--   attribuable à une personne. C'est aussi la preuve de la qualité du
--   plateau auquel le partenaire a été associé.
--
-- Application : Supabase Studio → SQL Editor.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 0. La publication à l'annuaire — un geste éditorial, pas un statut
-- ------------------------------------------------------------
-- `status = 'validated'` dit qu'un compte est légitime, pas qu'il doit
-- paraître à l'annuaire public : les comptes internes d'OXV sont validés eux
-- aussi. L'ancienne table `partners` avait un `is_published` ; en passant à
-- partner_accounts, ce garde-fou manquait — et deux comptes de test se sont
-- retrouvés publiés. La colonne le rétablit, FAUSSE par défaut : rien ne
-- paraît sans décision.
ALTER TABLE public.partner_accounts
  ADD COLUMN IF NOT EXISTS is_published boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.partner_accounts.is_published IS
  'Publication a l annuaire public du site. Faux par defaut : validated ne suffit pas, il faut une decision editoriale.';

-- NOTE : le site lit encore l annuaire depuis `partners` (seule table portant
-- aujourd hui ce feu vert). Une fois cette colonne en place ET de vrais
-- partenaires marques is_published = true, la bascule du site sur
-- partner_accounts se fait en une ligne (loadPartnersDirectory). Tant que
-- personne n est marque, l annuaire reste masque — ce qui est le bon defaut.

-- ------------------------------------------------------------
-- 1. Les points de contact
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.partner_touchpoints (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id uuid NOT NULL REFERENCES public.partner_accounts (id) ON DELETE CASCADE,
  kind       text NOT NULL CHECK (kind IN ('fiche','offre','site','contact')),
  source     text NOT NULL CHECK (source IN ('site','app')),
  jour       date NOT NULL DEFAULT current_date,
  empreinte  text NOT NULL,
  user_id    uuid REFERENCES public.users (id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.partner_touchpoints IS
  'Audience partenaire de premiere main. Unicite (partenaire, nature, jour, empreinte) : on compte des PERSONNES par jour, pas des clics.';
COMMENT ON COLUMN public.partner_touchpoints.empreinte IS
  'Identifiant aleatoire du navigateur ou de l app. Aucune donnee personnelle. Jamais restitue au partenaire.';
COMMENT ON COLUMN public.partner_touchpoints.user_id IS
  'Renseigne si la personne est connectee. Sert uniquement a purger sur demande d effacement. Jamais restitue au partenaire.';

CREATE UNIQUE INDEX IF NOT EXISTS uq_partner_touchpoints_jour
  ON public.partner_touchpoints (partner_id, kind, jour, empreinte);
CREATE INDEX IF NOT EXISTS idx_partner_touchpoints_lecture
  ON public.partner_touchpoints (partner_id, jour);

ALTER TABLE public.partner_touchpoints ENABLE ROW LEVEL SECURITY;

-- Aucune politique de lecture pour le partenaire : il n'accede JAMAIS aux
-- lignes (elles portent des empreintes et des user_id). Il ne lit que des
-- agregats, par oxv_partner_audience. L'administration garde la main.
DROP POLICY IF EXISTS partner_touchpoints_admin_all ON public.partner_touchpoints;
CREATE POLICY partner_touchpoints_admin_all ON public.partner_touchpoints
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ------------------------------------------------------------
-- 2. L'enregistrement d'un point de contact
-- ------------------------------------------------------------
-- Appelable par le site (visiteur anonyme compris) et par l'application.
-- Aucune ecriture directe dans la table : tout passe par ici, ou la nature
-- et la source sont validees et l'unicite du jour appliquee.
CREATE OR REPLACE FUNCTION public.oxv_track_partner_touch(
  p_partner_id uuid,
  p_kind       text,
  p_source     text DEFAULT 'site',
  p_empreinte  text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE v_emp text;
BEGIN
  IF p_kind NOT IN ('fiche','offre','site','contact')
     OR p_source NOT IN ('site','app') THEN
    RETURN json_build_object('ok', false, 'raison', 'nature_invalide');
  END IF;

  -- Le partenaire doit exister et etre valide : on ne mesure pas un brouillon.
  IF NOT EXISTS (SELECT 1 FROM public.partner_accounts
                  WHERE id = p_partner_id AND status = 'validated') THEN
    RETURN json_build_object('ok', false, 'raison', 'partenaire_inconnu');
  END IF;

  -- Empreinte bornee : ni vide, ni assez longue pour transporter autre chose.
  v_emp := left(coalesce(nullif(trim(p_empreinte), ''), 'anon-' || gen_random_uuid()::text), 64);

  INSERT INTO public.partner_touchpoints (partner_id, kind, source, empreinte, user_id)
  VALUES (p_partner_id, p_kind, p_source, v_emp, auth.uid())
  ON CONFLICT (partner_id, kind, jour, empreinte) DO NOTHING;

  RETURN json_build_object('ok', true);
EXCEPTION WHEN others THEN
  -- Une mesure ne doit jamais casser une page.
  RETURN json_build_object('ok', false, 'raison', 'erreur');
END $fn$;

REVOKE ALL ON FUNCTION public.oxv_track_partner_touch(uuid, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_track_partner_touch(uuid, text, text, text) TO anon, authenticated;

-- ------------------------------------------------------------
-- 3. La restitution — des nombres, jamais des lignes
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.oxv_partner_audience(
  p_partner_account_id uuid,
  p_from date DEFAULT NULL,
  p_to   date DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE v json;
BEGIN
  IF NOT (public.owns_partner_account(p_partner_account_id) OR public.is_admin()) THEN
    RETURN json_build_object('ok', false, 'raison', 'compte_autrui');
  END IF;

  SELECT json_build_object(
      'ok', true,
      'fiches',   NULLIF(count(*) FILTER (WHERE kind = 'fiche'), 0),
      'offres',   NULLIF(count(*) FILTER (WHERE kind = 'offre'), 0),
      'sites',    NULLIF(count(*) FILTER (WHERE kind = 'site'), 0),
      'contacts', NULLIF(count(*) FILTER (WHERE kind = 'contact'), 0),
      'personnes', NULLIF(count(DISTINCT empreinte), 0),
      'depuis_app',  NULLIF(count(*) FILTER (WHERE source = 'app'), 0),
      'depuis_site', NULLIF(count(*) FILTER (WHERE source = 'site'), 0)
    )
    INTO v
    FROM public.partner_touchpoints
   WHERE partner_id = p_partner_account_id
     AND (p_from IS NULL OR jour >= p_from)
     AND (p_to   IS NULL OR jour <= p_to);

  RETURN coalesce(v, json_build_object('ok', true));
END $fn$;

REVOKE ALL ON FUNCTION public.oxv_partner_audience(uuid, date, date) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_partner_audience(uuid, date, date) TO authenticated;

-- ------------------------------------------------------------
-- 4. La satisfaction de la journée — agrégée, jamais attribuable
-- ------------------------------------------------------------
-- Trois réponses minimum : en deçà, un avis serait attribuable à une
-- personne, et le pilote n'a pas donné son avis pour qu'un partenaire le lise.
CREATE OR REPLACE FUNCTION public.oxv_session_satisfaction(p_session_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE v_n integer; v_note numeric; v_nps numeric;
BEGIN
  SELECT count(*), round(avg(rating)::numeric, 1), round(avg(nps)::numeric, 1)
    INTO v_n, v_note, v_nps
    FROM public.session_feedback
   WHERE session_id = p_session_id AND rating IS NOT NULL;

  IF coalesce(v_n, 0) < 3 THEN
    RETURN NULL; -- pas assez de reponses : on ne publie rien
  END IF;

  RETURN json_build_object('reponses', v_n, 'note', v_note, 'recommandation', v_nps);
END $fn$;

REVOKE ALL ON FUNCTION public.oxv_session_satisfaction(uuid) FROM public;
REVOKE ALL ON FUNCTION public.oxv_session_satisfaction(uuid) FROM anon;

-- ------------------------------------------------------------
-- 5. Le compte-rendu embarque l'audience et la satisfaction
-- ------------------------------------------------------------
-- Remplace la version de migration_preuve_partenaire.sql : deux blocs de
-- plus dans le detail fige. Le reste est identique.
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
  v_audience   json;
  v_satis      json;
BEGIN
  SELECT * INTO v_ses FROM public.sessions WHERE id = p_session_id;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'raison', 'journee_introuvable');
  END IF;

  SELECT count(*) FILTER (WHERE status NOT IN ('cancelled')),
         count(*) FILTER (WHERE status = 'attended'),
         count(*) FILTER (WHERE attended_at IS NOT NULL)
    INTO v_inscrits, v_presents, v_pointes
    FROM public.registrations
   WHERE session_id = p_session_id;

  IF v_pointes > 0 THEN
    v_presents := v_pointes;
  ELSIF v_presents = 0 THEN
    v_presents := NULL;
  END IF;

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

  -- Audience de la fenetre : la veille, le jour, et la semaine qui suit —
  -- c'est la ou une journee produit ses regards.
  SELECT json_build_object(
      'fiches',   NULLIF(count(*) FILTER (WHERE kind = 'fiche'), 0),
      'offres',   NULLIF(count(*) FILTER (WHERE kind = 'offre'), 0),
      'sites',    NULLIF(count(*) FILTER (WHERE kind = 'site'), 0),
      'contacts', NULLIF(count(*) FILTER (WHERE kind = 'contact'), 0),
      'personnes', NULLIF(count(DISTINCT empreinte), 0)
    )
    INTO v_audience
    FROM public.partner_touchpoints
   WHERE partner_id = p_partner_account_id
     AND jour BETWEEN v_ses.date - 1 AND v_ses.date + 7;

  v_satis := public.oxv_session_satisfaction(p_session_id);

  RETURN json_build_object(
    'ok', true,
    'journee', json_build_object(
      'id', v_ses.id, 'date', v_ses.date, 'format', v_ses.format,
      'statut', v_ses.status, 'capacite', v_ses.max_capacity
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
      'inscrits', v_inscrits, 'presents', v_presents, 'capacite', v_ses.max_capacity
    ),
    'production', json_build_object(
      'contacts_consentis', v_contacts,
      'offres_publiees', v_offres,
      'medias_journee', NULLIF(v_medias, 0)
    ),
    'audience', v_audience,
    'satisfaction', v_satis
  );
END $fn$;

REVOKE ALL ON FUNCTION public.oxv_calc_partner_proof(uuid, uuid) FROM public;
REVOKE ALL ON FUNCTION public.oxv_calc_partner_proof(uuid, uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.oxv_calc_partner_proof(uuid, uuid) FROM anon;

COMMIT;

-- ============================================================
-- Cote application (React Native) — un seul appel a poser
-- ============================================================
-- A l'ouverture d'une fiche partenaire, sur un clic d'offre, sur un depart
-- vers le site du partenaire, et sur une demande de mise en relation :
--
--   await supabase.rpc('oxv_track_partner_touch', {
--     p_partner_id: partenaire.id,        // partner_accounts.id
--     p_kind:       'fiche',              // 'fiche' | 'offre' | 'site' | 'contact'
--     p_source:     'app',
--     p_empreinte:  await empreinteAppareil(),  // uuid tire une fois, garde en local
--   });
--
-- L'empreinte se tire une seule fois par installation (SecureStore /
-- AsyncStorage) : c'est elle qui permet de compter des personnes plutot que
-- des clics. Aucune donnee personnelle, aucun identifiant publicitaire.
-- ============================================================

-- ============================================================
-- Vérification après application
-- ============================================================
-- 1. Enregistrer un point de contact (en tant que visiteur) :
--      SELECT public.oxv_track_partner_touch('<partner_account_id>','fiche','site','test-1');
--      SELECT public.oxv_track_partner_touch('<partner_account_id>','fiche','site','test-1');
--      -- deux appels, UNE seule ligne : c'est le comptage par personne.
--      SELECT count(*) FROM public.partner_touchpoints;  -- 1
--
-- 2. Lire l'agregat (connecte en PARTENAIRE proprietaire) :
--      SELECT public.oxv_partner_audience('<son id>');
--      SELECT public.oxv_partner_audience('<id d un autre>');  -- compte_autrui
--
-- 3. Le partenaire ne voit AUCUNE ligne brute :
--      SELECT * FROM public.partner_touchpoints;  -- 0 ligne (RLS admin seule)
--
-- 4. La satisfaction se tait sous trois reponses :
--      SELECT public.oxv_session_satisfaction('<session_id>');  -- NULL
-- ============================================================
