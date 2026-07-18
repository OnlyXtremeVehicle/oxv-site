-- ============================================================
-- OXV — Migration : bande photo Pavillon (A13 requalifié)
-- Lot : ECRANS_PAVILLON — Addendum 02
-- Photos PRÉDÉFINIES, curatées à l'avance dans l'espace admin
-- du site. Aucune photo live de session_media n'est diffusée.
-- À exécuter APRÈS validation par M. Fillat.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pavillon_photos (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  storage_path text NOT NULL,            -- chemin dans le bucket 'pavillon-photos'
  legende      text CHECK (char_length(legende) <= 120),
  sort_order   integer NOT NULL DEFAULT 0,
  is_active    boolean NOT NULL DEFAULT true,
  created_by   uuid REFERENCES public.users(id),
  created_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.pavillon_photos ENABLE ROW LEVEL SECURITY;

-- Lecture : tout compte authentifié (les écrans TV sont authentifiés)
CREATE POLICY pavillon_photos_select ON public.pavillon_photos
  FOR SELECT TO authenticated
  USING (is_active = true);

-- Écriture : réservée au staff — ADAPTER la condition au mécanisme
-- de rôle réel (users.role / staff_members) après vérification.
-- Condition placeholder volontairement RESTRICTIVE (aucune écriture)
-- tant que le mécanisme n'est pas confirmé :
CREATE POLICY pavillon_photos_write ON public.pavillon_photos
  FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
-- TODO_ARBITRAGE: remplacer par la condition staff réelle avant mise en service admin.

-- ------------------------------------------------------------
-- BUCKET STORAGE (à créer via le dashboard ou l'API admin) :
--   nom : 'pavillon-photos'
--   public : false (URLs signées 24 h côté écran)
--   taille max : 5 Mo / fichier · formats : jpg, webp
-- ------------------------------------------------------------
