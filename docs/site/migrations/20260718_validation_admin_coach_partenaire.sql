-- ============================================================
-- OXV — Validation admin par élément (arbitrages fondateur 2026-07-18)
-- ✅ APPLIQUÉE le 2026-07-18 (GO fondateur « applique et continue »),
-- migration `validation_admin_coach_partenaire_site`. TESTÉE PAR RÔLE :
-- partenaire→auto-validation bloquée (pending) · offre→auto-publication
-- bloquée (draft) · coach non-admin→auto-ouverture bloquée (closed) ·
-- admin→transitions OK · 0 ligne de test restante. NB : le compte coach
-- artefact administration@ a is_admin=true → bypass légitime (à nettoyer,
-- cf SECURITE_P2). Les vues+photos Pavillon ont été appliquées le même
-- jour (`pavillon_vues_et_photos`, policy staff résolue en is_admin()).
-- « Rien n'apparaît dans l'app avant approbation admin » :
--   · partner_accounts   : seul un admin peut passer status='validated'
--     (l'INSERT force déjà 'pending' via policy — ce trigger ferme l'UPDATE)
--   · partner_offers     : seul un admin peut publier ; toute modification
--     non-admin d'une offre publiée la repasse en 'draft' (re-validation
--     par élément), sauf archivage volontaire
--   · coach_availability : seul un admin peut ouvrir un créneau ('open')
-- Ces règles s'appliquent à TOUS les clients (site ET app) — cohérent avec
-- la décision fondateur. Aucun changement de schéma, aucune valeur nouvelle.
-- À TESTER après application : en rôle partenaire, UPDATE status='validated'
-- → reste 'pending' ; en rôle coach, INSERT status='open' → stocké 'closed' ;
-- en admin, les transitions passent.
-- ============================================================

CREATE OR REPLACE FUNCTION public.oxv_partner_accounts_validation_gate()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin() THEN
    IF TG_OP = 'INSERT' AND NEW.status = 'validated' THEN
      NEW.status := 'pending';
    ELSIF TG_OP = 'UPDATE' AND NEW.status = 'validated' AND OLD.status IS DISTINCT FROM 'validated' THEN
      NEW.status := OLD.status; -- pas d'auto-validation
    END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_partner_accounts_validation_gate ON public.partner_accounts;
CREATE TRIGGER trg_partner_accounts_validation_gate
  BEFORE INSERT OR UPDATE ON public.partner_accounts
  FOR EACH ROW EXECUTE FUNCTION public.oxv_partner_accounts_validation_gate();

CREATE OR REPLACE FUNCTION public.oxv_partner_offers_publish_gate()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin() THEN
    IF TG_OP = 'INSERT' THEN
      IF NEW.status = 'published' THEN NEW.status := 'draft'; END IF;
    ELSIF TG_OP = 'UPDATE' THEN
      IF OLD.status = 'published' THEN
        -- validation PAR ÉLÉMENT : toute modification non-admin d'une offre
        -- publiée exige une re-validation (sauf archivage volontaire).
        IF NEW.status <> 'archived' THEN NEW.status := 'draft'; END IF;
      ELSIF NEW.status = 'published' THEN
        NEW.status := OLD.status; -- pas d'auto-publication
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_partner_offers_publish_gate ON public.partner_offers;
CREATE TRIGGER trg_partner_offers_publish_gate
  BEFORE INSERT OR UPDATE ON public.partner_offers
  FOR EACH ROW EXECUTE FUNCTION public.oxv_partner_offers_publish_gate();

CREATE OR REPLACE FUNCTION public.oxv_coach_availability_open_gate()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin() THEN
    IF TG_OP = 'INSERT' AND NEW.status = 'open' THEN
      NEW.status := 'closed'; -- créneau proposé → en attente de validation OXV
    ELSIF TG_OP = 'UPDATE' AND NEW.status = 'open' AND OLD.status IS DISTINCT FROM 'open' THEN
      NEW.status := OLD.status; -- ouverture réservée à l'admin
    END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_coach_availability_open_gate ON public.coach_availability;
CREATE TRIGGER trg_coach_availability_open_gate
  BEFORE INSERT OR UPDATE ON public.coach_availability
  FOR EACH ROW EXECUTE FUNCTION public.oxv_coach_availability_open_gate();
