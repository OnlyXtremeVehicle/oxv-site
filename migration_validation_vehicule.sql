-- ============================================================
-- La voiture se valide, PUIS elle devient sélectionnable
-- ============================================================
-- APPLIQUÉE en production le 2026-08-30. État CONSOLIDÉ : ce fichier
-- remplace six migrations successives, dont trois correctifs. Il est écrit
-- d'après les définitions relues en base, pas de mémoire.
--
--   validation_du_vehicule
--   passage_en_examen_automatique
--   correctif_garde_admin_oxv_is_admin
--   correctif_declencheurs_examen_sans_liste_de_colonnes
--   correctif_decision_humaine_sur_vehicule
--   referentiel_exclusion_automatique  (voir migration_referentiel_exclusion.sql)
--
-- LE MODÈLE (décision fondateur du 2026-08-30)
-- Le pilote saisit sa voiture. Un rapprochement vérifie chaque information.
-- La voiture passe en validé. Une voiture validée est sélectionnable à la
-- réservation, selon sa classe.
--
-- Une première version avait posé l'examen sur la RÉSERVATION : d'où une
-- distinction entre engagement payé et non payé qui n'avait pas lieu d'être.
-- L'examen appartient au VÉHICULE.
--
-- NE PAS CONFONDRE avec `eligibility_items`, qui existe déjà et couvre la
-- JOURNÉE : casque, briefing, niveau sonore, pneus et freins, décharge, CNI,
-- permis, assurance circuit, contrôle technique. Ici on ne juge que ce qui
-- décrit la voiture, une fois pour toutes.
--
-- TROIS PIÈGES RENCONTRÉS, à ne pas refaire :
--   1. `users.is_admin` N'EXISTE PAS. La qualité d'administrateur se lit
--      `users.role = 'admin'`, et la maison a `public.oxv_is_admin()`.
--   2. `AFTER UPDATE OF colonne` ne se déclenche que si l'INSTRUCTION nomme
--      la colonne — une colonne posée par un déclencheur BEFORE ne compte
--      pas. Garder sur la VALEUR.
--   3. Le garde restaurait l'ancien verdict dès que l'appelant n'était pas
--      administrateur, ce qui bloquait aussi la fonction d'administration.
--      Elle s'annonce par un drapeau LOCAL à la transaction.

-- ------------------------------------------------------------
-- 1. Les colonnes
-- ------------------------------------------------------------
ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS modifie boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS modifications_detail text,
  ADD COLUMN IF NOT EXISTS plaque_statut text,
  ADD COLUMN IF NOT EXISTS plaque_motif text,
  ADD COLUMN IF NOT EXISTS plaque_verifiee_le timestamptz,
  ADD COLUMN IF NOT EXISTS statut_validation text,
  ADD COLUMN IF NOT EXISTS validation_motif text,
  ADD COLUMN IF NOT EXISTS validation_le timestamptz,
  ADD COLUMN IF NOT EXISTS validation_manuelle boolean NOT NULL DEFAULT false;

ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_statut_validation_check;
ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_statut_validation_check
  CHECK (statut_validation IS NULL OR statut_validation IN
         ('incomplet','en_verification','valide','refuse'));

ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_plaque_statut_check;
ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_plaque_statut_check
  CHECK (plaque_statut IS NULL OR plaque_statut IN ('conforme','a_verifier','refusee'));

ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_modifications_detaillees;
ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_modifications_detaillees
  CHECK (NOT modifie OR (modifications_detail IS NOT NULL AND length(btrim(modifications_detail)) > 0));

ALTER TABLE public.registrations
  ADD COLUMN IF NOT EXISTS motif_examen text,
  ADD COLUMN IF NOT EXISTS examen_ouvert_le timestamptz;

-- ------------------------------------------------------------
-- 2. Le rapprochement — seul juge
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.oxv_evaluer_vehicule(
  p_referentiel_id uuid, p_plaque_statut text, p_plaque_motif text,
  p_modifie boolean, p_detail text, p_annee integer)
RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE r record;
BEGIN
  IF p_referentiel_id IS NULL THEN
    RETURN jsonb_build_object('statut','incomplet',
      'motif','Designez le vehicule au referentiel : marque, modele, generation.');
  END IF;

  SELECT * INTO r FROM public.vehicules_eligibles WHERE id = p_referentiel_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('statut','incomplet',
      'motif','La designation ne correspond plus a aucune ligne du referentiel.');
  END IF;

  IF r.statut = 'exclu' THEN
    RETURN jsonb_build_object('statut','refuse',
      'motif', format('Hors des criteres d acces : %s kg/ch. Le referentiel admet jusqu a 6,00 kg/ch.', r.ratio_kg_ch));
  END IF;

  IF p_plaque_statut = 'refusee' THEN
    RETURN jsonb_build_object('statut','refuse',
      'motif', COALESCE(p_plaque_motif,'Immatriculation refusee.'));
  END IF;
  IF p_plaque_statut IS NULL OR p_plaque_motif = 'Aucune immatriculation renseignee.' THEN
    RETURN jsonb_build_object('statut','incomplet','motif','Renseignez l immatriculation.');
  END IF;

  IF p_modifie IS TRUE AND COALESCE(btrim(p_detail),'') = '' THEN
    RETURN jsonb_build_object('statut','incomplet',
      'motif','Precisez la nature des modifications declarees.');
  END IF;

  -- Ce qui reste demande un humain, jamais un calcul.
  IF p_plaque_statut = 'a_verifier' THEN
    RETURN jsonb_build_object('statut','en_verification',
      'motif', COALESCE(p_plaque_motif,'Immatriculation en cours de verification.'));
  END IF;
  IF p_modifie IS TRUE THEN
    RETURN jsonb_build_object('statut','en_verification',
      'motif','Modifications declarees : elles sont examinees avant validation.');
  END IF;
  IF p_annee IS NOT NULL AND (p_annee < r.annee_debut OR (r.annee_fin IS NOT NULL AND p_annee > r.annee_fin)) THEN
    RETURN jsonb_build_object('statut','en_verification',
      'motif', format('Millesime %s declare sur une generation produite %s.', p_annee,
        CASE WHEN r.annee_fin IS NULL THEN 'depuis ' || r.annee_debut
             ELSE 'de ' || r.annee_debut || ' a ' || r.annee_fin END));
  END IF;

  RETURN jsonb_build_object('statut','valide','motif',NULL);
END;
$fn$;

-- ------------------------------------------------------------
-- 3. Plaque et validation : un seul déclencheur, dans l'ordre
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.vehicles_controle_plaque()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE v jsonb; e jsonb; faits_changes boolean; statue boolean;
BEGIN
  statue := COALESCE(current_setting('oxv.statue_vehicule', true), '0') = '1';

  IF TG_OP = 'UPDATE' THEN
    faits_changes :=
         NEW.license_plate IS DISTINCT FROM OLD.license_plate
      OR NEW.year IS DISTINCT FROM OLD.year
      OR NEW.referentiel_id IS DISTINCT FROM OLD.referentiel_id
      OR NEW.modifie IS DISTINCT FROM OLD.modifie
      OR NEW.modifications_detail IS DISTINCT FROM OLD.modifications_detail;
  ELSE
    faits_changes := true;
  END IF;

  -- 1. L'immatriculation.
  IF TG_OP = 'INSERT'
     OR NEW.license_plate IS DISTINCT FROM OLD.license_plate
     OR NEW.year IS DISTINCT FROM OLD.year THEN
    v := public.oxv_controler_plaque(NEW.license_plate, NEW.year, NEW.id, NEW.user_id);
    NEW.plaque_statut := v->>'statut';
    NEW.plaque_motif := v->>'motif';
    NEW.plaque_verifiee_le := now();
  ELSIF NOT (statue OR public.oxv_is_admin()) THEN
    NEW.plaque_statut := OLD.plaque_statut;
    NEW.plaque_motif := OLD.plaque_motif;
    NEW.plaque_verifiee_le := OLD.plaque_verifiee_le;
  END IF;

  -- 2. La validation. Une decision humaine tient jusqu a ce que les FAITS
  --    changent ; alors le rapprochement reprend la main.
  IF statue THEN
    RETURN NEW;                                   -- la decision passe telle quelle
  END IF;

  IF faits_changes THEN NEW.validation_manuelle := false; END IF;

  IF NOT COALESCE(NEW.validation_manuelle, false) THEN
    e := public.oxv_evaluer_vehicule(NEW.referentiel_id, NEW.plaque_statut, NEW.plaque_motif,
                                     NEW.modifie, NEW.modifications_detail, NEW.year);
    NEW.statut_validation := e->>'statut';
    NEW.validation_motif := e->>'motif';
    NEW.validation_le := now();
  ELSIF TG_OP = 'UPDATE' THEN
    NEW.statut_validation := OLD.statut_validation;
    NEW.validation_motif := OLD.validation_motif;
    NEW.validation_le := OLD.validation_le;
  END IF;

  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_vehicles_controle_plaque ON public.vehicles;
CREATE TRIGGER trg_vehicles_controle_plaque
  BEFORE INSERT OR UPDATE ON public.vehicles
  FOR EACH ROW EXECUTE FUNCTION public.vehicles_controle_plaque();

-- ------------------------------------------------------------
-- 4. La décision humaine
-- ------------------------------------------------------------
-- Le drapeau est LOCAL à la transaction : elle seule peut le poser, il
-- disparaît avec elle. Le client, lui, reste incapable de se déclarer valide.
CREATE OR REPLACE FUNCTION public.oxv_statuer_vehicule(
  p_vehicle_id uuid, p_statut text, p_motif text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
BEGIN
  IF NOT public.oxv_is_admin() THEN
    RAISE EXCEPTION 'Reserve a l''administration.';
  END IF;
  IF p_statut NOT IN ('valide','refuse','en_verification') THEN
    RAISE EXCEPTION 'Verdict inconnu : %', p_statut;
  END IF;
  IF p_statut = 'refuse' AND COALESCE(btrim(p_motif),'') = '' THEN
    RAISE EXCEPTION 'Un refus se motive.';
  END IF;

  PERFORM set_config('oxv.statue_vehicule', '1', true);

  UPDATE public.vehicles
  SET statut_validation = p_statut,
      validation_motif = p_motif,
      validation_le = now(),
      validation_manuelle = true,
      histovec_statut = CASE WHEN p_statut = 'valide' THEN 'verifiee' ELSE histovec_statut END,
      histovec_verifie_le = CASE WHEN p_statut = 'valide' THEN now() ELSE histovec_verifie_le END
  WHERE id = p_vehicle_id;

  PERFORM set_config('oxv.statue_vehicule', '0', true);

  IF NOT FOUND THEN RAISE EXCEPTION 'Vehicule introuvable.'; END IF;
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.oxv_statuer_vehicule(uuid, text, text) TO authenticated;

-- ------------------------------------------------------------
-- 5. Les réservations en cours suivent la voiture
-- ------------------------------------------------------------
-- Le STATUT de l'inscription n'est jamais défait automatiquement : c'est la
-- voiture qu'on instruit. Seul le motif se pose, pour que rien ne passe
-- inaperçu, et il s'efface dès que la voiture est validée.
CREATE OR REPLACE FUNCTION public.vehicles_validation_apres_reservation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
BEGIN
  IF NEW.statut_validation IS DISTINCT FROM OLD.statut_validation THEN
    IF NEW.statut_validation = 'valide' THEN
      UPDATE public.registrations r SET motif_examen = NULL, examen_ouvert_le = NULL
      FROM public.sessions s
      WHERE r.session_id = s.id AND r.vehicle_id = NEW.id
        AND s.date >= CURRENT_DATE AND r.motif_examen IS NOT NULL;
    ELSE
      UPDATE public.registrations r
      SET motif_examen = COALESCE(NEW.validation_motif, 'Vehicule non valide.'),
          examen_ouvert_le = now()
      FROM public.sessions s
      WHERE r.session_id = s.id AND r.vehicle_id = NEW.id
        AND s.date >= CURRENT_DATE
        AND r.status IN ('pending','pending_payment','confirmed','en_examen');
    END IF;
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_vehicles_validation_apres_reservation ON public.vehicles;
CREATE TRIGGER trg_vehicles_validation_apres_reservation
  AFTER UPDATE ON public.vehicles
  FOR EACH ROW EXECUTE FUNCTION public.vehicles_validation_apres_reservation();

-- ------------------------------------------------------------
-- 6. La révision du référentiel rend la main au rapprochement
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.vehicules_eligibles_revision()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
BEGIN
  IF NEW.classe IS NOT DISTINCT FROM OLD.classe
     AND NEW.statut IS NOT DISTINCT FROM OLD.statut THEN
    RETURN NEW;
  END IF;
  -- Toucher la ligne suffit : le declencheur du vehicule refait le
  -- rapprochement, et la decision humaine anterieure ne tient plus.
  UPDATE public.vehicles
  SET validation_manuelle = false, updated_at = now()
  WHERE referentiel_id = NEW.id;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_vehicules_eligibles_revision ON public.vehicules_eligibles;
CREATE TRIGGER trg_vehicules_eligibles_revision
  AFTER UPDATE ON public.vehicules_eligibles
  FOR EACH ROW EXECUTE FUNCTION public.vehicules_eligibles_revision();

-- ------------------------------------------------------------
-- 7. Clore une réservation à revoir
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.oxv_clore_examen(
  p_registration_id uuid, p_admis boolean, p_note text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE v_statut registration_status_enum;
BEGIN
  IF NOT public.oxv_is_admin() THEN
    RAISE EXCEPTION 'Reserve a l''administration.';
  END IF;

  SELECT status INTO v_statut FROM public.registrations WHERE id = p_registration_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Inscription introuvable.'; END IF;

  IF p_admis THEN
    UPDATE public.registrations
    SET status = CASE WHEN status = 'en_examen' THEN 'pending'::registration_status_enum ELSE status END,
        motif_examen = NULL,
        examen_ouvert_le = NULL,
        notes = concat_ws(E'\n', notes, 'Examen clos : ' || COALESCE(p_note, 'vehicule admis'))
    WHERE id = p_registration_id;
  ELSE
    IF p_note IS NULL OR btrim(p_note) = '' THEN
      RAISE EXCEPTION 'Un refus se motive.';
    END IF;
    UPDATE public.registrations
    SET status = 'cancelled'::registration_status_enum,
        cancelled_at = now(),
        cancelled_by = auth.uid(),
        cancellation_reason = p_note,
        motif_examen = NULL,
        examen_ouvert_le = NULL
    WHERE id = p_registration_id;
  END IF;
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.oxv_clore_examen(uuid, boolean, text) TO authenticated;

-- ------------------------------------------------------------
-- 8. Ce que la validation du véhicule a remplacé
-- ------------------------------------------------------------
-- `oxv_statuer_plaque` ne statuait que sur l'immatriculation. Elle est
-- remplacée par `oxv_statuer_vehicule`, qui statue sur la voiture entière.
-- Plus aucun appelant : on la retire plutôt que de laisser deux portes.
DROP FUNCTION IF EXISTS public.oxv_statuer_plaque(uuid, text, text, text);

-- Ces trois-là ont perdu leurs déclencheurs quand l'examen est passé de la
-- RÉSERVATION au VÉHICULE. `vehicles_validation_apres_reservation` fait
-- désormais le travail ; laisser deux chemins vers le même effet invite à
-- rebrancher l'ancien en croyant qu'il vit encore.
DROP FUNCTION IF EXISTS public.vehicles_modification_apres_reservation() CASCADE;
DROP FUNCTION IF EXISTS public.vehicles_plaque_apres_reservation() CASCADE;
DROP FUNCTION IF EXISTS public.oxv_ouvrir_examen(uuid, text) CASCADE;
