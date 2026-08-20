-- ============================================================
-- OXV — Migration : publication Realtime du canal 3 Pavillon
-- Lot : ECRANS_PAVILLON — appliquée le 2026-08-01
-- Nom en base : pavillon_realtime_coach_annotations
-- ------------------------------------------------------------
-- Contexte : le site s'abonne déjà à postgres_changes INSERT sur
-- coach_annotations (canal 3 du CONTRAT_TEMPS_REEL_PAVILLON), mais
-- la table n'appartenait à aucune publication → aucun événement
-- n'était jamais émis. L'écran coach ne recevait les annotations
-- qu'au chargement initial (lecture .select()), jamais en direct.
--
-- RLS reste active sur coach_annotations (3 policies) : la diffusion
-- Realtime est filtrée par utilisateur, aucune ouverture de données.
-- Réversible : ALTER PUBLICATION supabase_realtime DROP TABLE …
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.coach_annotations;

-- Vérification :
--   select c.relname from pg_publication p
--     join pg_publication_rel pr on pr.prpubid = p.oid
--     join pg_class c on c.oid = pr.prrelid
--   where p.pubname = 'supabase_realtime';
--   → coach_annotations
