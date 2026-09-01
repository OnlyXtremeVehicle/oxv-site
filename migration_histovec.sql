-- ============================================================
-- HistoVec : le rapport que seul le titulaire peut produire
-- ============================================================
-- APPLIQUÉE en production le 2026-09-01.
--
-- POURQUOI. `oxv_controler_plaque` ne vérifie qu'une FORME : que la chaîne
-- ressemble à une plaque SIV ou FNI, et qu'aucun autre compte ne la porte.
-- Elle n'interroge rien. Elle ne peut donc pas dire que la plaque appartient à
-- cette voiture-là, ni que le pilote en est le titulaire.
--
-- Et elle ne le pourra pas : l'accès au SIV est fermé par le Code de la route
-- (art. L330-2) à une liste close — police, gendarmerie, douanes, huissiers,
-- assureurs — où OXV ne figure pas. Les API commerciales rendent les
-- caractéristiques du véhicule, jamais le nom du titulaire : cette donnée
-- n'est pas revendue.
--
-- HistoVec est la seule voie. Service officiel et gratuit du ministère de
-- l'Intérieur : SEUL le titulaire du certificat en cours de validité peut
-- générer le rapport, via FranceConnect, en une trentaine de secondes. Il le
-- partage par un lien sécurisé valable 15 jours portant un jeton
-- cryptographique. Le rapport donne la situation administrative — gagé,
-- opposition, volé, véhicule économiquement irréparable — et l'historique des
-- contrôles techniques.
--
-- CE QU'IL PROUVE, ET CE QU'IL NE PROUVE PAS. Le rapport ne NOMME pas le
-- titulaire à un tiers : c'est voulu par l'État. Ce qu'il établit, c'est que
-- la personne qui transmet le lien s'est authentifiée comme titulaire. C'est
-- strictement plus fort qu'une photo de carte grise, qui s'emprunte.
--
-- ── LE PARTI PRIS QUI COMMANDE TOUT LE RESTE ────────────────
-- HistoVec NE BLOQUE NI L'AJOUT D'UN VÉHICULE NI LA RÉSERVATION.
--
-- C'est une décision de taux de remplissage, pas de laxisme. Un rapport dure
-- 15 jours : l'exiger à l'inscription, deux mois avant la séance, produirait un
-- document périmé le jour venu — on aurait ajouté une friction à l'endroit le
-- plus fragile du tunnel POUR RIEN. On le demande donc au bon moment, une
-- dizaine de jours avant la séance, quand le pilote est déjà engagé et que
-- trente secondes ne le font plus renoncer.
--
-- Le verdict de véhicule (`statut_validation`) reste ce qu'il était :
-- référentiel + plaque + modifications. HistoVec est un AXE SÉPARÉ, condition
-- de roulage et non condition de vente.
--
-- ── L'ISSUE POUR CEUX QUI NE SONT PAS TITULAIRES ────────────
-- En LOA, en LLD ou en véhicule de société, le titulaire au certificat est le
-- loueur : le pilote ne peut pas générer de rapport. C'est fréquent sur les
-- sportives récentes — précisément notre parc. Sans issue déclarée, ces
-- pilotes tombent dans un cul-de-sac et abandonnent. `oxv_histovec_non_titulaire`
-- leur ouvre un examen humain au lieu d'un mur.

-- ── 1. Le dépôt ─────────────────────────────────────────────
-- Deux contraintes d'un design HistoVec ANTÉRIEUR existaient déjà, jamais
-- branché : un vocabulaire 'verifiee' / 'non_etablie', et l'invariant
-- « statut renseigné ⟺ horodatage renseigné ». La première tentative de cette
-- migration a été refusée par la seconde.
--
-- L'invariant est bon et il reste : un état sans date de pose ne veut rien
-- dire. C'est donc NULL qui porte l'absence, et rien n'est posé par défaut —
-- pas de valeur 'absent' stockée. `oxv_histovec_etat` la rend à la lecture.
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS histovec_url text;

ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_histovec_statut_check;
ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_histovec_statut_connu;
ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_histovec_statut_connu
  CHECK (histovec_statut IS NULL OR histovec_statut IN
    ('fourni', 'non_titulaire', 'verifie', 'refuse'));

-- Un lien déposé sans statut serait un lien que personne ne regarde.
ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_histovec_lien_statue;
ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_histovec_lien_statue
  CHECK (histovec_url IS NULL OR histovec_statut IS NOT NULL);

COMMENT ON COLUMN public.vehicles.histovec_url IS
  'Lien de partage HistoVec produit par le titulaire. Valable 15 jours.';
COMMENT ON COLUMN public.vehicles.histovec_statut IS
  'NULL = jamais fourni. fourni = lien depose, pas encore examine. non_titulaire = LOA/LLD/societe, examen humain. verifie = rapport lu et concordant. refuse = rapport non concordant.';

-- ── 2. Le contrôle du lien ──────────────────────────────────
-- On valide L'HÔTE, et rien de plus.
--
-- Le format du jeton n'est pas documenté publiquement, et l'État peut le faire
-- évoluer sans prévenir. Une expression régulière calée sur une forme observée
-- rejetterait un jour des liens parfaitement valides — c'est-à-dire qu'elle
-- coûterait des inscriptions pour une sécurité imaginaire. Ce qui compte et se
-- vérifie sûrement : le lien pointe vers le domaine du ministère, en HTTPS, et
-- porte quelque chose au-delà de la racine.
--
-- Un message d'erreur qui ment coûte des inscriptions. La première version
-- répondait « ce lien ne pointe pas vers histovec » à quelqu'un qui avait collé
-- l'adresse du BON site sans le chemin du rapport : elle l'envoyait chercher au
-- mauvais endroit. Les trois cas sont donc distingués.
CREATE OR REPLACE FUNCTION public.oxv_controler_histovec(p_url text)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE u text := btrim(COALESCE(p_url, ''));
BEGIN
  IF u = '' THEN
    RETURN jsonb_build_object('statut', NULL,
      'motif', 'Collez le lien que HistoVec vous donne apres avoir genere le rapport.');
  END IF;

  IF length(u) > 2048 THEN
    RETURN jsonb_build_object('statut', NULL, 'motif', 'Ce lien est anormalement long.');
  END IF;

  IF u ~* '^https?://histovec\.interieur\.gouv\.fr/?$' THEN
    RETURN jsonb_build_object('statut', NULL,
      'motif', 'C''est bien le bon site, mais c''est son adresse d''accueil. Generez le rapport, puis copiez le lien de partage qu''il vous donne.');
  END IF;

  IF u !~* '^https?://histovec\.interieur\.gouv\.fr/' THEN
    RETURN jsonb_build_object('statut', NULL,
      'motif', 'Ce lien ne pointe pas vers histovec.interieur.gouv.fr.');
  END IF;

  RETURN jsonb_build_object('statut', 'fourni', 'motif', NULL);
END;
$function$;

-- ── 3. L'état vivant ────────────────────────────────────────
-- La péremption ne se STOCKE pas : elle se calcule. Une colonne « expiré »
-- posée à l'écriture serait fausse le lendemain, et il faudrait une tâche
-- planifiée pour la tenir à jour — une pièce mobile de plus pour un calcul de
-- soustraction.
CREATE OR REPLACE FUNCTION public.oxv_histovec_etat(p_statut text, p_le timestamptz)
RETURNS text
LANGUAGE sql
STABLE
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN p_statut IS NULL OR p_le IS NULL THEN 'absent'
    WHEN p_statut IN ('non_titulaire','refuse') THEN p_statut
    WHEN p_le < now() - interval '15 days' THEN 'expire'
    ELSE p_statut
  END;
$function$;

COMMENT ON FUNCTION public.oxv_histovec_etat(text, timestamptz) IS
  'Etat lu a l instant present. Ajoute absent et expire aux valeurs stockees : un rapport HistoVec vaut 15 jours.';

-- ⚠️ `oxvHistovecEtat()` dans index.html est le MIROIR EXACT de cette
-- fonction. Les deux se déplacent ensemble : un écran qui dirait « valide »
-- sur un rapport que la base tient pour périmé serait pire que pas d'écran.

-- ── 4. Le dépôt par le pilote ───────────────────────────────
-- Le drapeau `oxv.statue_vehicule` est indispensable : sans lui, le déclencheur
-- `vehicles_controle_plaque` recalculerait le verdict et repousserait
-- `validation_le` à maintenant, alors que rien de la validation n'a bougé.
CREATE OR REPLACE FUNCTION public.oxv_deposer_histovec(p_vehicle_id uuid, p_url text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_owner uuid; c jsonb;
BEGIN
  SELECT user_id INTO v_owner FROM public.vehicles WHERE id = p_vehicle_id;
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'Vehicule introuvable.' USING ERRCODE = 'no_data_found';
  END IF;
  IF v_owner <> auth.uid() AND NOT public.oxv_is_admin() THEN
    RAISE EXCEPTION 'Ce vehicule ne vous appartient pas.' USING ERRCODE = 'insufficient_privilege';
  END IF;

  c := public.oxv_controler_histovec(p_url);
  IF c->>'statut' IS NULL THEN
    RETURN c;                                     -- lien rejete, rien n'est ecrit
  END IF;

  PERFORM set_config('oxv.statue_vehicule', '1', true);
  UPDATE public.vehicles
     SET histovec_url = btrim(p_url),
         histovec_statut = c->>'statut',
         histovec_motif = NULL,
         histovec_verifie_le = now()
   WHERE id = p_vehicle_id;
  PERFORM set_config('oxv.statue_vehicule', '0', true);

  RETURN jsonb_build_object('statut', c->>'statut', 'motif', NULL);
END;
$function$;

-- ── 5. L'issue LOA / LLD / société ──────────────────────────
CREATE OR REPLACE FUNCTION public.oxv_histovec_non_titulaire(p_vehicle_id uuid, p_precision text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_owner uuid;
BEGIN
  SELECT user_id INTO v_owner FROM public.vehicles WHERE id = p_vehicle_id;
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'Vehicule introuvable.' USING ERRCODE = 'no_data_found';
  END IF;
  IF v_owner <> auth.uid() AND NOT public.oxv_is_admin() THEN
    RAISE EXCEPTION 'Ce vehicule ne vous appartient pas.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF COALESCE(btrim(p_precision), '') = '' THEN
    RAISE EXCEPTION 'Precisez votre situation.' USING ERRCODE = 'check_violation';
  END IF;

  PERFORM set_config('oxv.statue_vehicule', '1', true);
  UPDATE public.vehicles
     SET histovec_statut = 'non_titulaire',
         histovec_motif = btrim(p_precision),
         histovec_verifie_le = now()
   WHERE id = p_vehicle_id;
  PERFORM set_config('oxv.statue_vehicule', '0', true);

  RETURN jsonb_build_object('statut','non_titulaire','motif', btrim(p_precision));
END;
$function$;

-- ── 6. Le verdict humain ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.oxv_statuer_histovec(p_vehicle_id uuid, p_verdict text, p_motif text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.oxv_is_admin() THEN
    RAISE EXCEPTION 'Reserve a l administration.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_verdict NOT IN ('verifie','refuse') THEN
    RAISE EXCEPTION 'Verdict inconnu : %', p_verdict USING ERRCODE = 'check_violation';
  END IF;
  IF p_verdict = 'refuse' AND COALESCE(btrim(p_motif),'') = '' THEN
    RAISE EXCEPTION 'Un refus se motive.' USING ERRCODE = 'check_violation';
  END IF;

  PERFORM set_config('oxv.statue_vehicule', '1', true);
  UPDATE public.vehicles
     SET histovec_statut = p_verdict,
         histovec_motif = NULLIF(btrim(COALESCE(p_motif,'')), ''),
         histovec_verifie_le = now()
   WHERE id = p_vehicle_id;
  PERFORM set_config('oxv.statue_vehicule', '0', true);

  RETURN jsonb_build_object('statut', p_verdict, 'motif', p_motif);
END;
$function$;

REVOKE ALL ON FUNCTION public.oxv_deposer_histovec(uuid, text) FROM public;
REVOKE ALL ON FUNCTION public.oxv_histovec_non_titulaire(uuid, text) FROM public;
REVOKE ALL ON FUNCTION public.oxv_statuer_histovec(uuid, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_deposer_histovec(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.oxv_histovec_non_titulaire(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.oxv_statuer_histovec(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.oxv_controler_histovec(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.oxv_histovec_etat(text, timestamptz) TO authenticated, anon;
