-- ============================================================
-- Référentiel : l'exclusion se pose seule, et elle se dit
-- ============================================================
-- APPLIQUÉE le 2026-08-29.
--
-- Deux défauts corrigés, découverts en élargissant le parc.
--
-- 1. Une ligne hors critères restait 'actif' avec une classe nulle. Or
--    `bkOffreOuverte()` renvoie VRAI faute de classe : la voiture ouvrait
--    TOUTES les offres au lieu d'aucune. Le classement étant une colonne
--    GÉNÉRÉE — donc invisible d'un déclencheur BEFORE — on rejoue le seuil.
--
-- 2. La politique de lecture filtrait `statut = 'actif'`. Les lignes exclues
--    étaient invisibles, et le site ne pouvait donc pas dire POURQUOI une
--    voiture est refusée : il disait « pas dans la liste », ce qui envoyait
--    le pilote déposer une demande d'examen qui ne pouvait pas aboutir.
--    Le référentiel est l'application des conditions d'accès PUBLIÉES : ses
--    lignes exclues ne sont pas un secret, elles sont la réponse.

CREATE OR REPLACE FUNCTION public.vehicules_eligibles_hors_criteres()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $fn$
BEGIN
  IF NEW.masse_kg > 2400 OR NEW.ratio_kg_ch > 6.0 THEN
    NEW.statut := 'exclu';
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_vehicules_eligibles_hors_criteres ON public.vehicules_eligibles;
CREATE TRIGGER trg_vehicules_eligibles_hors_criteres
  BEFORE INSERT OR UPDATE ON public.vehicules_eligibles
  FOR EACH ROW EXECUTE FUNCTION public.vehicules_eligibles_hors_criteres();

COMMENT ON COLUMN public.vehicules_eligibles.statut IS
  'actif = admis au referentiel. exclu = hors criteres d acces (masse > 2400 kg ou rapport > 6,0 kg/ch), pose automatiquement.';

DROP POLICY IF EXISTS vehicules_eligibles_select_public ON public.vehicules_eligibles;
CREATE POLICY vehicules_eligibles_select_public
  ON public.vehicules_eligibles FOR SELECT
  TO anon, authenticated
  USING (true);
