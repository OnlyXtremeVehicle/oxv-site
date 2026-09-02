-- ============================================================
-- La classe devient fonction de la vocation ET du rapport
-- ============================================================
-- APPLIQUÉE en production le 2026-09-02. Étape 2 de la vocation
-- (étape 1 : migration_vocation.sql).
--
-- Le rapport masse/puissance ne classe plus seul : il GRADUE À L'INTÉRIEUR
-- d'une vocation, avec des bornes propres à chacune. C'est ce qui met une
-- 308 GTi et une Ferrari dans deux boîtes différentes — ce qu'aucun quotient
-- ne savait faire, puisqu'un quotient jette l'échelle.
--
--   vocation      Classe I                      Classe II        Classe III
--   serie         ratio >= 4,0                  3,0 <= r < 4,0   r < 3,0
--   gt            ratio >= 4,0 ET ch < 300      r >= 3,0         r < 3,0
--   supersport    —                             r >= 3,5         r < 3,5
--   barquette     —                             r >= 2,5         r < 2,5
--   suv           ratio >= 4,0                  r < 4,0          —
--
-- ── POURQUOI LES `gt` PORTENT UNE CONDITION DE PUISSANCE ────
-- Le fondateur a demandé que l'Alpine A110, l'Alfa 4C et la Civic Type R
-- passent en Classe I. La Civic est en `serie` : le seuil de 4,0 suffit. Les
-- deux autres sont en `gt`, et là AUCUN seuil de rapport ne les prend sans
-- emmener les 911 Carrera de base — la 997 Carrera est à 4,29, la 996 à 4,40,
-- l'A110 à 4,40 et la 4C à 4,27. Il n'y a pas de trou entre elles.
--
-- Ce qui les sépare réellement se lit ailleurs : 252 et 240 ch contre 300 à
-- 355. La condition de puissance ne s'applique donc QU'AUX `gt`. Dans les
-- `serie`, une voiture à 4,3 kg/ch est une compacte quelle que soit sa
-- puissance : la Civic Type R FL5 (329 ch) est en Classe I, décision fondateur.
--
-- Effet collatéral assumé et vérifié : les 911 refroidies par air (964 et 993
-- Carrera, 250 à 285 ch, 4,7 à 5,4 kg/ch) descendent en Classe I. C'est juste —
-- elles roulent au rythme d'une 308 GTi, pas d'une 992.
--
-- Résultat : 449 actives, I 157 · II 177 · III 115, zéro classe nulle.
-- Effet en clientèle au moment de l'application : 0 journée restreinte,
-- 3 inscriptions, 1 véhicule désigné. Rien n'a été bousculé.

-- La vocation devient obligatoire. Une ligne active sans vocation aurait une
-- classe NULLE, et une classe nulle ouvre TOUTES les offres côté réservation
-- (`bkOffreOuverte` rend vrai faute de classe — c'est un piège déjà rencontré).
-- Le référentiel doit déclarer.
ALTER TABLE public.vehicules_eligibles ALTER COLUMN vocation SET NOT NULL;

-- ⚠️ `classe` est GÉNÉRÉE : son expression NE SE MODIFIE PAS en place. Il faut
-- la reposer, et recréer dans la même transaction l'index partiel qui la porte
-- — sinon on le perd en silence.
DROP INDEX IF EXISTS public.vehicules_eligibles_actif_classe_idx;
ALTER TABLE public.vehicules_eligibles DROP COLUMN IF EXISTS classe;

ALTER TABLE public.vehicules_eligibles
  ADD COLUMN classe text GENERATED ALWAYS AS (
    CASE
      -- Les deux gardes d'accès, inchangées et prioritaires.
      WHEN masse_kg > 2400::numeric THEN NULL::text
      WHEN ratio_kg_ch > 6.0 THEN NULL::text

      WHEN vocation = 'serie' THEN
        CASE WHEN ratio_kg_ch >= 4.0 THEN 'I'
             WHEN ratio_kg_ch >= 3.0 THEN 'II'
             ELSE 'III' END

      WHEN vocation = 'gt' THEN
        CASE WHEN ratio_kg_ch >= 4.0 AND puissance_ch < 300 THEN 'I'
             WHEN ratio_kg_ch >= 3.0 THEN 'II'
             ELSE 'III' END

      WHEN vocation = 'supersport' THEN
        CASE WHEN ratio_kg_ch >= 3.5 THEN 'II' ELSE 'III' END

      WHEN vocation = 'barquette' THEN
        CASE WHEN ratio_kg_ch >= 2.5 THEN 'II' ELSE 'III' END

      WHEN vocation = 'suv' THEN
        CASE WHEN ratio_kg_ch >= 4.0 THEN 'I' ELSE 'II' END

      ELSE NULL::text
    END
  ) STORED;

CREATE INDEX vehicules_eligibles_actif_classe_idx
  ON public.vehicules_eligibles USING btree (classe) WHERE (statut = 'actif');

COMMENT ON COLUMN public.vehicules_eligibles.classe IS
  'Generee : fonction de la vocation ET du rapport masse/puissance. Le rapport gradue A L INTERIEUR d une vocation, il ne classe plus seul. Les gt portent en plus un plafond de puissance a 300 ch pour la Classe I.';

-- ⚠️ TROIS CHIFFRES SE DÉPLACENT ENSEMBLE, TOUJOURS : le plancher d'accès
-- (6,00 kg/ch) vit ici, dans `vehicules_eligibles_hors_criteres()` et dans le
-- motif de `oxv_evaluer_vehicule()`. Voir migration_referentiel_seuil.sql.
