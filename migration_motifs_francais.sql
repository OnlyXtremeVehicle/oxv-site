-- ============================================================
-- Les motifs lus par le pilote s'écrivent en français
-- ============================================================
-- Ces chaînes ne sont pas des messages de journal : elles s'affichent dans le
-- garage, dans le tableau de bord admin, et depuis aujourd'hui dans le courriel
-- de statut de véhicule. « Hors des criteres d acces » n'est pas du français.
--
-- Rien d'autre ne change : même signature, même logique, mêmes branches. Seules
-- les chaînes sont réécrites.
--
-- ⚠️ PIÈGE : `oxv_evaluer_vehicule` compare `p_plaque_motif` À L'ÉGALITÉ avec
-- 'Aucune immatriculation renseignee.', chaîne produite par
-- `oxv_controler_plaque`. Accentuer l'une sans l'autre casse la branche en
-- silence — le véhicule sans plaque cesserait de passer en 'incomplet'. Les
-- deux fonctions sont donc reposées ensemble, et les lignes déjà en base sont
-- réévaluées à la fin.

-- ── 1. Le contrôle d'immatriculation ────────────────────────
CREATE OR REPLACE FUNCTION public.oxv_controler_plaque(
  p_plaque text, p_annee integer, p_vehicle_id uuid, p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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
  v_plausible := length(v_norm) BETWEEN 4 AND 12
                 AND v_norm ~ '[A-Z]' AND v_norm ~ '[0-9]';

  IF NOT (v_siv OR v_fni OR v_plausible) THEN
    RETURN jsonb_build_object('statut', 'refusee',
      'motif', 'Cette immatriculation n''a pas une forme reconnaissable.');
  END IF;

  SELECT bool_or(v.user_id IS DISTINCT FROM p_user_id),
         bool_or(v.user_id IS NOT DISTINCT FROM p_user_id)
    INTO v_autre_compte, v_meme_compte
  FROM public.vehicles v
  WHERE public.oxv_plaque_normalisee(v.license_plate) = v_norm
    AND (p_vehicle_id IS NULL OR v.id <> p_vehicle_id);

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
$function$;

-- ── 2. Le rapprochement ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.oxv_evaluer_vehicule(
  p_referentiel_id uuid, p_plaque_statut text, p_plaque_motif text,
  p_modifie boolean, p_detail text, p_annee integer)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record;
BEGIN
  IF p_referentiel_id IS NULL THEN
    RETURN jsonb_build_object('statut','incomplet',
      'motif','Désignez le véhicule au référentiel : marque, modèle, génération.');
  END IF;

  SELECT * INTO r FROM public.vehicules_eligibles WHERE id = p_referentiel_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('statut','incomplet',
      'motif','La désignation ne correspond plus à aucune ligne du référentiel.');
  END IF;

  IF r.statut = 'exclu' THEN
    RETURN jsonb_build_object('statut','refuse',
      'motif', format('Hors des critères d''accès : %s kg/ch. Le référentiel admet jusqu''à 6,00 kg/ch.', r.ratio_kg_ch));
  END IF;

  IF p_plaque_statut = 'refusee' THEN
    RETURN jsonb_build_object('statut','refuse',
      'motif', COALESCE(p_plaque_motif,'Immatriculation refusée.'));
  END IF;
  -- L'égalité porte sur la chaîne produite par oxv_controler_plaque ci-dessus.
  -- Les deux se déplacent ensemble, jamais l'une sans l'autre.
  IF p_plaque_statut IS NULL OR p_plaque_motif = 'Aucune immatriculation renseignée.' THEN
    RETURN jsonb_build_object('statut','incomplet','motif','Renseignez l''immatriculation.');
  END IF;

  IF p_modifie IS TRUE AND COALESCE(btrim(p_detail),'') = '' THEN
    RETURN jsonb_build_object('statut','incomplet',
      'motif','Précisez la nature des modifications déclarées.');
  END IF;

  IF p_plaque_statut = 'a_verifier' THEN
    RETURN jsonb_build_object('statut','en_verification',
      'motif', COALESCE(p_plaque_motif,'Immatriculation en cours de vérification.'));
  END IF;
  IF p_modifie IS TRUE THEN
    RETURN jsonb_build_object('statut','en_verification',
      'motif','Modifications déclarées : elles sont examinées avant validation.');
  END IF;
  IF p_annee IS NOT NULL AND (p_annee < r.annee_debut OR (r.annee_fin IS NOT NULL AND p_annee > r.annee_fin)) THEN
    RETURN jsonb_build_object('statut','en_verification',
      'motif', format('Millésime %s déclaré sur une génération produite %s.', p_annee,
        CASE WHEN r.annee_fin IS NULL THEN 'depuis ' || r.annee_debut
             ELSE 'de ' || r.annee_debut || ' à ' || r.annee_fin END));
  END IF;

  RETURN jsonb_build_object('statut','valide','motif',NULL);
END;
$function$;

-- ── 3. Les lignes déjà en base portent l'ancien texte ───────
-- Elles ne se réécrivent pas toutes seules : le déclencheur ne recalcule qu'au
-- changement des faits. Sans ce passage, un véhicule garderait « Hors des
-- criteres d acces » jusqu'à sa prochaine modification.
--
-- On repose d'abord le motif de plaque, puis le verdict qui en dépend.
--
-- ⚠️ SANS LE DRAPEAU, CES DEUX ÉCRITURES PARTENT EN SILENCE. Le déclencheur
-- `vehicles_controle_plaque` restaure OLD.plaque_motif dès que l'appelant n'est
-- ni admin ni porteur de `oxv.statue_vehicule` — et une écriture annulée par un
-- déclencheur ne lève aucune erreur. On pose donc le drapeau, qui fait passer
-- les deux UPDATE tels quels.
SELECT set_config('oxv.statue_vehicule', '1', true);

UPDATE public.vehicles v
SET plaque_motif = (
      public.oxv_controler_plaque(v.license_plate, v.year, v.id, v.user_id)
    )->>'motif';

-- Lit le plaque_motif que l'instruction précédente vient de poser.
UPDATE public.vehicles v
SET validation_motif = (
      public.oxv_evaluer_vehicule(v.referentiel_id, v.plaque_statut, v.plaque_motif,
                                  v.modifie, v.modifications_detail, v.year)
    )->>'motif'
WHERE COALESCE(v.validation_manuelle, false) = false;

SELECT set_config('oxv.statue_vehicule', '0', true);
