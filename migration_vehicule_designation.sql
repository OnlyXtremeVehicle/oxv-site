-- ============================================================
-- La désignation appartient au VÉHICULE, pas à la réservation
-- ============================================================
-- Décision fondateur du 2026-08-29 : marque / modèle / génération et la
-- déclaration de modifications se font à l'ajout du véhicule au garage, ou à
-- sa modification. La réservation ne fait plus que CHOISIR un véhicule connu.
--
-- Motif : déclarées à chaque réservation, les mêmes modifications pouvaient
-- être déclarées différemment d'une journée à l'autre pour la même voiture.
-- Une propriété du véhicule doit être stockée sur le véhicule.

ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS modifie boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS modifications_detail text;

COMMENT ON COLUMN public.vehicles.modifie IS
  'Modifications déclarées du moteur, échappement, suspension ou freinage. Déclaré au garage, repris par la réservation.';
COMMENT ON COLUMN public.vehicles.modifications_detail IS
  'Nature et portée des modifications. Exigé dès que modifie = true.';

-- Un détail sans modification n'a pas de sens, une modification sans détail
-- non plus : la contrainte dit la règle une fois, pour tous les clients.
ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_modifications_detaillees;
ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_modifications_detaillees
  CHECK (NOT modifie OR (modifications_detail IS NOT NULL AND length(btrim(modifications_detail)) > 0));

-- ------------------------------------------------------------
-- Reprise de l'existant : ce que les réservations savent déjà
-- ------------------------------------------------------------
-- Les modifications déclarées au tunnel jusqu'ici vivaient sur la
-- réservation. On les remonte sur le véhicule pour ne pas repartir d'une
-- page blanche — sans jamais écraser une déclaration plus récente.
UPDATE public.vehicles v
SET modifie = true,
    modifications_detail = COALESCE(v.modifications_detail, r.detail)
FROM (
  SELECT DISTINCT ON (vehicle_id) vehicle_id,
         NULLIF(btrim(modifications_detail), '') AS detail
  FROM public.registrations
  WHERE modifications_declarees IS TRUE AND vehicle_id IS NOT NULL
  ORDER BY vehicle_id, created_at DESC
) r
WHERE r.vehicle_id = v.id
  AND v.modifie IS FALSE
  AND r.detail IS NOT NULL;

-- ------------------------------------------------------------
-- Déclarer des modifications APRÈS avoir réservé
-- ------------------------------------------------------------
-- La déclaration vit désormais dans le temps, pas dans un tunnel. Un pilote
-- peut donc modifier sa voiture entre la réservation et la journée.
--
-- Une inscription non encore payée repasse en examen : c'est une diligence
-- d'OXV, elle reste visible et annulable par le pilote.
--
-- Une inscription CONFIRMÉE n'est pas touchée : revenir sur un engagement
-- payé est une décision commerciale, pas une conséquence automatique. Elle
-- est signalée au tableau de bord, pas défaite ici.
CREATE OR REPLACE FUNCTION public.vehicles_modification_apres_reservation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NEW.modifie IS TRUE AND COALESCE(OLD.modifie, false) IS FALSE THEN
    UPDATE public.registrations r
    SET status = 'en_examen'
    FROM public.sessions s
    WHERE r.session_id = s.id
      AND r.vehicle_id = NEW.id
      AND s.date >= CURRENT_DATE
      AND r.status IN ('pending', 'pending_payment');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vehicles_modification_apres_reservation ON public.vehicles;
CREATE TRIGGER trg_vehicles_modification_apres_reservation
  AFTER UPDATE OF modifie ON public.vehicles
  FOR EACH ROW EXECUTE FUNCTION public.vehicles_modification_apres_reservation();
