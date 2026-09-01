-- ============================================================
-- Une journée ne mélange que des classes voisines
-- ============================================================
-- APPLIQUÉE en production le 2026-09-01.
--
-- Trois cases indépendantes offraient huit combinaisons, dont deux qui n'ont
-- pas de sens : aucune classe, et I+III sans II. La seconde mettait une Sport
-- et une Supersport sur le même plateau en sautant le palier qui les relie, et
-- elle était à un clic.
--
-- La règle est posée dans la BASE, pas seulement à l'écran : l'administration
-- n'est pas le seul chemin d'écriture, et une règle qui ne vit que dans une
-- interface n'est pas une règle.
--
-- Six combinaisons restent, toutes contiguës :
--   I · II · III · I+II · II+III · I+II+III
--
-- ⚠️ LE PIÈGE QUI A FAILLI PASSER. La première écriture testait
-- `array_length(classes_admises, 1) >= 1`. Or array_length d'un tableau VIDE
-- vaut NULL, pas 0 : le AND devenait NULL, et une contrainte CHECK PASSE sur
-- NULL. Une journée n'admettant aucune classe serait entrée sans bruit — le
-- cas même que la contrainte prétendait fermer. coalesce ferme le trou.

ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_classes_contigues;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_classes_contigues CHECK (
  classes_admises <@ ARRAY['I','II','III']::text[]
  AND coalesce(array_length(classes_admises, 1), 0) >= 1
  AND NOT ('I' = ANY(classes_admises)
           AND 'III' = ANY(classes_admises)
           AND NOT ('II' = ANY(classes_admises)))
);

COMMENT ON CONSTRAINT sessions_classes_contigues ON public.sessions IS
  'Les classes admises forment une plage continue et non vide. I et III sans II est refuse : ce sont les deux extremes du parc, sans le palier qui les relie.';

-- Côté écran, les trois cases sont remplacées par une liste des six plateaux
-- nommés (index.html, `oxvLireClassesAdmises` / `oxvPoserClassesAdmises`). Une
-- journée d'avant ce champ, ou une plage héritée qu'aucune option ne porte,
-- retombe sur les trois classes : c'est ce qu'elle admettait de fait, et la
-- seule valeur qui n'écarte personne à tort.
