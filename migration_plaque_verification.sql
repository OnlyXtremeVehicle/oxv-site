-- ============================================================
-- La validation d'un véhicule passe par sa plaque (2026-08-29)
-- ============================================================
-- Décision fondateur : un véhicule n'est validé qu'après vérification de
-- l'immatriculation — et seulement si tout tient ensemble.
--
-- La règle vit ICI, pas dans le navigateur. Le site l'affiche, il ne la
-- décide pas : un client modifié ne peut pas se déclarer conforme.
--
-- Ce qui se vérifie automatiquement :
--   1. la FORME de la plaque (SIV, FNI, ou étrangère plausible) ;
--   2. l'UNICITÉ — une plaque déjà portée par un autre véhicule ;
--   3. la COHÉRENCE avec le millésime — le SIV (AA-123-AA) est en vigueur
--      depuis avril 2009 ; une voiture déclarée 2010 ou après ne peut pas
--      porter une plaque FNI (« 1234 AB 17 »).
--
-- Ce qui ne s'automatise PAS : HistoVec exige la carte grise du titulaire,
-- il n'existe aucune interface machine. Le contrôle reste humain, et les
-- colonnes `histovec_*`, présentes depuis le début et écrites par personne,
-- le portent enfin.

ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS plaque_statut text,
  ADD COLUMN IF NOT EXISTS plaque_motif text,
  ADD COLUMN IF NOT EXISTS plaque_verifiee_le timestamptz;

ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_plaque_statut_check;
ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_plaque_statut_check
  CHECK (plaque_statut IS NULL OR plaque_statut IN ('conforme', 'a_verifier', 'refusee'));

COMMENT ON COLUMN public.vehicles.plaque_statut IS
  'Verdict du controle d immatriculation. Pose par le declencheur, jamais par le client.';
COMMENT ON COLUMN public.vehicles.plaque_motif IS
  'Ce qui empeche la conformite, redige pour etre lu par le pilote.';

-- ------------------------------------------------------------
-- 1. Normalisation : « AB-123-CD » et « ab123cd » sont la meme plaque
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.oxv_plaque_normalisee(p text)
RETURNS text LANGUAGE sql IMMUTABLE
AS $$ SELECT upper(regexp_replace(coalesce(p, ''), '[^A-Za-z0-9]', '', 'g')) $$;

CREATE INDEX IF NOT EXISTS vehicles_plaque_normalisee_idx
  ON public.vehicles (public.oxv_plaque_normalisee(license_plate))
  WHERE license_plate IS NOT NULL;

-- ------------------------------------------------------------
-- 2. Le controle
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.oxv_controler_plaque(
  p_plaque text, p_annee integer, p_vehicle_id uuid, p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_norm text := public.oxv_plaque_normalisee(p_plaque);
  v_siv boolean;
  v_fni boolean;
  v_plausible boolean;
  v_autre_compte boolean;
  v_meme_compte boolean;
BEGIN
  IF v_norm = '' THEN
    RETURN jsonb_build_object('statut', 'a_verifier',
      'motif', 'Aucune immatriculation renseignée.');
  END IF;

  v_siv := v_norm ~ '^[A-Z]{2}[0-9]{3}[A-Z]{2}$';
  v_fni := v_norm ~ '^[0-9]{1,4}[A-Z]{2,3}[0-9]{2,3}$';
  -- Plaque étrangère ou de collection : on exige une forme plausible, pas
  -- une forme française. Une plaque mutilée ne rapproche plus rien.
  v_plausible := length(v_norm) BETWEEN 4 AND 12
                 AND v_norm ~ '[A-Z]' AND v_norm ~ '[0-9]';

  IF NOT (v_siv OR v_fni OR v_plausible) THEN
    RETURN jsonb_build_object('statut', 'refusee',
      'motif', 'Cette immatriculation n’a pas une forme reconnaissable.');
  END IF;

  SELECT bool_or(v.user_id IS DISTINCT FROM p_user_id),
         bool_or(v.user_id IS NOT DISTINCT FROM p_user_id)
    INTO v_autre_compte, v_meme_compte
  FROM public.vehicles v
  WHERE public.oxv_plaque_normalisee(v.license_plate) = v_norm
    AND (p_vehicle_id IS NULL OR v.id <> p_vehicle_id);

  -- Deux voitures ne portent pas la même plaque. Sur le même compte c'est
  -- une erreur de saisie ; sur deux comptes ce peut être une copropriété
  -- réelle — OXV tranche, le site ne présume pas.
  IF v_meme_compte THEN
    RETURN jsonb_build_object('statut', 'refusee',
      'motif', 'Cette immatriculation est déjà portée par un autre de vos véhicules.');
  END IF;
  IF v_autre_compte THEN
    RETURN jsonb_build_object('statut', 'a_verifier',
      'motif', 'Cette immatriculation est déjà enregistrée sur un autre compte. Nous la vérifions avant validation.');
  END IF;

  IF p_annee IS NOT NULL AND p_annee >= 2010 AND v_fni AND NOT v_siv THEN
    RETURN jsonb_build_object('statut', 'a_verifier',
      'motif', format('Millésime %s déclaré avec une plaque au format FNI. Le SIV (AA-123-AA) est en vigueur depuis avril 2009.', p_annee));
  END IF;

  IF NOT (v_siv OR v_fni) THEN
    RETURN jsonb_build_object('statut', 'a_verifier',
      'motif', 'Immatriculation hors format français. Nous la vérifions avant validation.');
  END IF;

  RETURN jsonb_build_object('statut', 'conforme', 'motif', NULL);
END;
$$;

GRANT EXECUTE ON FUNCTION public.oxv_controler_plaque(text, integer, uuid, uuid) TO authenticated;

-- ------------------------------------------------------------
-- 3. Reprise de l'existant — AVANT le déclencheur
-- ------------------------------------------------------------
-- Posé après, le déclencheur préserverait l'ancienne valeur (NULL) et la
-- reprise ne se ferait jamais. L'ordre compte.
-- `UPDATE ... FROM LATERAL` ne peut pas referencer la table cible : Postgres
-- refuse (42P10). L'appel se fait donc directement dans le SET.
UPDATE public.vehicles v
SET plaque_statut = (public.oxv_controler_plaque(v.license_plate, v.year, v.id, v.user_id))->>'statut',
    plaque_motif  = (public.oxv_controler_plaque(v.license_plate, v.year, v.id, v.user_id))->>'motif',
    plaque_verifiee_le = now()
WHERE v.plaque_statut IS NULL;

-- ------------------------------------------------------------
-- 4. Le verdict s'écrit tout seul — le client ne le choisit pas
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.vehicles_controle_plaque()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v jsonb;
  v_admin boolean;
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.license_plate IS NOT DISTINCT FROM OLD.license_plate
     AND NEW.year IS NOT DISTINCT FROM OLD.year THEN
    -- Ni la plaque ni le millésime n'ont bougé : il n'y a rien à
    -- recontrôler. Le verdict ne se déplace alors que par
    -- `oxv_statuer_plaque`, réservée à l'administration — un client modifié
    -- ne peut pas se déclarer conforme.
    SELECT is_admin IS TRUE INTO v_admin FROM public.users WHERE id = auth.uid();
    IF NOT COALESCE(v_admin, false) THEN
      NEW.plaque_statut := OLD.plaque_statut;
      NEW.plaque_motif := OLD.plaque_motif;
      NEW.plaque_verifiee_le := OLD.plaque_verifiee_le;
    END IF;
    RETURN NEW;
  END IF;

  v := public.oxv_controler_plaque(NEW.license_plate, NEW.year, NEW.id, NEW.user_id);
  NEW.plaque_statut := v->>'statut';
  NEW.plaque_motif := v->>'motif';
  NEW.plaque_verifiee_le := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vehicles_controle_plaque ON public.vehicles;
CREATE TRIGGER trg_vehicles_controle_plaque
  BEFORE INSERT OR UPDATE ON public.vehicles
  FOR EACH ROW EXECUTE FUNCTION public.vehicles_controle_plaque();

-- ------------------------------------------------------------
-- 5. Levée manuelle par un administrateur
-- ------------------------------------------------------------
-- Ce que la machine ne peut pas trancher — copropriété réelle, plaque
-- étrangère, rapport HistoVec produit par le pilote — un humain le tranche,
-- et sa décision porte son motif.
--
-- `histovec_*` n'est touché que lorsque le rapport a réellement été lu :
-- écrire « non établie » sur un dossier simplement en attente serait un
-- constat faux.
CREATE OR REPLACE FUNCTION public.oxv_statuer_plaque(
  p_vehicle_id uuid, p_statut text, p_motif text DEFAULT NULL,
  p_histovec text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.users
                 WHERE id = auth.uid() AND is_admin IS TRUE) THEN
    RAISE EXCEPTION 'Réservé à l’administration.';
  END IF;
  IF p_statut NOT IN ('conforme', 'a_verifier', 'refusee') THEN
    RAISE EXCEPTION 'Verdict inconnu : %', p_statut;
  END IF;
  IF p_histovec IS NOT NULL AND p_histovec NOT IN ('verifiee', 'non_etablie') THEN
    RAISE EXCEPTION 'État HistoVec inconnu : %', p_histovec;
  END IF;

  UPDATE public.vehicles
  SET plaque_statut = p_statut,
      plaque_motif = p_motif,
      plaque_verifiee_le = now(),
      histovec_statut = COALESCE(p_histovec, histovec_statut),
      histovec_verifie_le = CASE WHEN p_histovec IS NOT NULL
                                 THEN now() ELSE histovec_verifie_le END
  WHERE id = p_vehicle_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Véhicule introuvable.';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.oxv_statuer_plaque(uuid, text, text, text) TO authenticated;
