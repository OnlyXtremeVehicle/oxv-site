-- ============================================================
-- Le plancher d'accès du référentiel — état courant : 6,00 kg/ch
-- ============================================================
-- APPLIQUÉE en production le 2026-08-30.
--
-- Historique de la décision, pour que personne ne refasse le chemin :
--   · 6,00 à l'origine ;
--   · porté à 6,30 le 30/08 après lecture de l'axe des 532 véhicules ;
--   · REMIS à 6,00 le même jour, décision fondateur.
--
-- 6,30 avait une justification technique — c'est une coupure réelle dans la
-- donnée, plus aucune voiture entre 6,30 et 6,53. Le fondateur a tranché
-- autrement : le plancher reste à 6,00. La justification technique ne décide
-- pas d'une politique commerciale.
--
-- Effet à 6,00 sur 532 lignes : 449 admises, 83 hors critères, zéro classe
-- nulle.
--
-- ⚠️ TROIS ENDROITS PORTENT LE CHIFFRE. Les changer ensemble, toujours :
--   1. l'expression de la colonne GÉNÉRÉE `classe` ci-dessous ;
--   2. `vehicules_eligibles_hors_criteres()` ;
--   3. le motif de `oxv_evaluer_vehicule()`, plus la mention côté site
--      (index.html, « Le référentiel admet jusqu'à X kg/ch »).
--
-- ⚠️ `classe` est GÉNÉRÉE : son expression NE SE MODIFIE PAS en place. Il
-- faut la reposer, et recréer l'index partiel qui la porte dans la même
-- transaction — sinon on le perd en silence.

DROP INDEX IF EXISTS public.vehicules_eligibles_actif_classe_idx;
ALTER TABLE public.vehicules_eligibles DROP COLUMN IF EXISTS classe;

ALTER TABLE public.vehicules_eligibles
  ADD COLUMN classe text GENERATED ALWAYS AS (
    CASE
      WHEN masse_kg > 2400::numeric THEN NULL::text
      WHEN ratio_kg_ch > 6.0 THEN NULL::text
      WHEN ratio_kg_ch < 3.5 THEN 'III'::text
      WHEN ratio_kg_ch < 5.0 THEN 'II'::text
      ELSE 'I'::text
    END
  ) STORED;

CREATE INDEX vehicules_eligibles_actif_classe_idx
  ON public.vehicules_eligibles USING btree (classe) WHERE (statut = 'actif');

-- Le déclencheur rejoue le seuil DANS LES DEUX SENS : au-delà, exclu ; en
-- deçà, admis. Sans le second sens, déplacer le seuil vers le haut laissait
-- des lignes exclues à tort.
CREATE OR REPLACE FUNCTION public.vehicules_eligibles_hors_criteres()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $fn$
BEGIN
  IF NEW.masse_kg > 2400 OR NEW.ratio_kg_ch > 6.0 THEN
    NEW.statut := 'exclu';
  ELSIF NEW.statut = 'exclu' THEN
    NEW.statut := 'actif';
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_vehicules_eligibles_hors_criteres ON public.vehicules_eligibles;
CREATE TRIGGER trg_vehicules_eligibles_hors_criteres
  BEFORE INSERT OR UPDATE ON public.vehicules_eligibles
  FOR EACH ROW EXECUTE FUNCTION public.vehicules_eligibles_hors_criteres();

-- Alignement des lignes existantes, dans les deux sens.
UPDATE public.vehicules_eligibles
SET statut = 'exclu'
WHERE statut = 'actif' AND (masse_kg > 2400 OR ratio_kg_ch > 6.0);

UPDATE public.vehicules_eligibles
SET statut = 'actif'
WHERE statut = 'exclu' AND masse_kg <= 2400 AND ratio_kg_ch <= 6.0;

COMMENT ON COLUMN public.vehicules_eligibles.statut IS
  'actif = admis au referentiel. exclu = hors criteres d acces (masse > 2400 kg ou rapport > 6,00 kg/ch), pose automatiquement.';

-- Le motif lu par le pilote porte le même chiffre. `oxv_evaluer_vehicule` est
-- définie en entier dans migration_validation_vehicule.sql ; seule la ligne
-- du seuil change ici.
--   'Hors des criteres d acces : %s kg/ch. Le referentiel admet jusqu a 6,00 kg/ch.'
