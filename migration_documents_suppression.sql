-- ============================================================
-- OXV — Le pilote peut supprimer et remplacer SES pièces
-- ============================================================
-- Constat du 2026-08-25 (signalé par le fondateur) : cliquer sur « Supprimer »
-- dans l'espace pilote n'effaçait pas le document. La cause n'était pas dans le
-- site mais dans la politique RLS de la table `documents` :
--
--   documents_delete_admin_only   DELETE  USING (is_admin())
--   documents_update_admin_only   UPDATE  USING (is_admin())
--
-- Un pilote qui supprime sa pièce ne touche donc AUCUNE ligne. PostgREST ne
-- considère pas cela comme une erreur : il répond 204, et le site — qui ne
-- testait que `error` — annonçait « Document supprimé » sans rien avoir supprimé.
-- Le fichier Storage, lui, partait bien (sa propre politique l'autorise) : on
-- perdait le fichier tout en gardant la ligne, avec une URL devenue morte.
--
-- Le même défaut frappait le remplacement d'une pièce (UPDATE) : ancien fichier
-- effacé, nouveau fichier déposé, puis mise à jour silencieusement refusée.
--
-- Cette migration est PUREMENT ADDITIVE : aucun objet existant n'est supprimé.
-- Les politiques permissives s'additionnent, les anciennes « admin_only »
-- deviennent simplement redondantes.
--
-- La validation reste la prérogative de l'administration. Ouvrir l'UPDATE au
-- pilote sans garde-fou lui permettrait de passer sa propre assurance circuit
-- en `validated` : deux triggers l'en empêchent.
--
-- Application : Supabase Studio → SQL Editor, ou `supabase db execute`.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Garde-fou d'abord — un pilote ne se valide jamais lui-même.
-- ------------------------------------------------------------
-- Créé AVANT la politique UPDATE qui l'exige : à aucun moment le pilote
-- ne peut écrire sans que ce garde soit en place.
CREATE OR REPLACE FUNCTION public.trg_fn_documents_garde_pilote()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Admin, ou écriture de service (auth.uid() nul, cas des edge functions) :
  -- aucune contrainte, le circuit de validation doit rester libre.
  IF auth.uid() IS NULL OR public.is_admin() THEN
    RETURN new;
  END IF;

  -- Le pilote ne change ni de propriétaire, ni de nature de pièce.
  new.id            := old.id;
  new.user_id       := old.user_id;
  new.document_type := old.document_type;

  -- Toute modification réelle de sa part remet la pièce en attente : une
  -- assurance dont on prolonge la date doit repasser devant l'administration.
  -- Un enregistrement sans changement préserve la décision déjà prise.
  IF new.file_url       IS DISTINCT FROM old.file_url
  OR new.file_name      IS DISTINCT FROM old.file_name
  OR new.file_size_kb   IS DISTINCT FROM old.file_size_kb
  OR new.validity_start IS DISTINCT FROM old.validity_start
  OR new.validity_end   IS DISTINCT FROM old.validity_end THEN
    new.status           := 'pending';
    new.validated_at     := NULL;
    new.validated_by     := NULL;
    new.rejection_reason := NULL;
    new.uploaded_at      := now();
  ELSE
    new.status           := old.status;
    new.validated_at     := old.validated_at;
    new.validated_by     := old.validated_by;
    new.rejection_reason := old.rejection_reason;
  END IF;

  RETURN new;
END $$;

DROP TRIGGER IF EXISTS trg_documents_garde_pilote ON public.documents;
CREATE TRIGGER trg_documents_garde_pilote
  BEFORE UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_documents_garde_pilote();

-- ------------------------------------------------------------
-- 2. Suppression — l'éligibilité doit suivre.
-- ------------------------------------------------------------
-- `oxv_sync_eligibility_docs` ne sait pas retomber à « à fournir » quand la
-- DERNIÈRE pièce d'un type disparaît : sa jointure ne trouve plus de ligne et
-- l'item resterait « ok » sans document. La clé étrangère met bien
-- document_id à NULL (ON DELETE SET NULL) mais ne touche pas au statut.
CREATE OR REPLACE FUNCTION public.trg_fn_documents_apres_suppression()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_reg record;
BEGIN
  IF old.document_type IN ('driving_license','id_card','insurance_track')
     AND NOT EXISTS (
       SELECT 1 FROM public.documents
        WHERE user_id = old.user_id AND document_type = old.document_type
     ) THEN
    -- Une décision admin manuelle (validated_by non nul) prime toujours,
    -- même convention que oxv_sync_eligibility_docs.
    UPDATE public.eligibility_items ei
       SET status = 'pending', document_id = NULL, updated_at = now()
      FROM public.registrations r
     WHERE ei.registration_id = r.id
       AND r.user_id = old.user_id
       AND r.status NOT IN ('cancelled')
       AND ei.validated_by IS NULL
       AND ei.item_key = CASE old.document_type::text
             WHEN 'driving_license' THEN 'permis'
             WHEN 'id_card'         THEN 'cni'
             WHEN 'insurance_track' THEN 'assurance_circuit' END;
  END IF;

  -- Puis on repointe sur la pièce restante la plus récente, s'il y en a une.
  FOR v_reg IN SELECT id FROM public.registrations
               WHERE user_id = old.user_id AND status NOT IN ('cancelled') LOOP
    PERFORM public.oxv_sync_eligibility_docs(v_reg.id);
  END LOOP;

  RETURN old;
EXCEPTION WHEN others THEN
  -- Même parti pris que les triggers existants : la suppression ne doit
  -- jamais échouer à cause d'un effet de bord d'éligibilité.
  RAISE WARNING '[documents_apres_suppression] %', sqlerrm;
  RETURN old;
END $$;

DROP TRIGGER IF EXISTS trg_documents_apres_suppression ON public.documents;
CREATE TRIGGER trg_documents_apres_suppression
  AFTER DELETE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_documents_apres_suppression();

-- ------------------------------------------------------------
-- 3. Politiques — le propriétaire rejoint l'admin.
-- ------------------------------------------------------------
DROP POLICY IF EXISTS documents_delete_own_or_admin ON public.documents;
CREATE POLICY documents_delete_own_or_admin ON public.documents
  FOR DELETE USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS documents_update_own_or_admin ON public.documents;
CREATE POLICY documents_update_own_or_admin ON public.documents
  FOR UPDATE USING (user_id = auth.uid() OR public.is_admin())
         WITH CHECK (user_id = auth.uid() OR public.is_admin());

COMMIT;

-- ============================================================
-- Vérification après application (à exécuter connecté en tant que pilote,
-- pas en tant que service : le service contourne RLS et ne prouve rien).
-- ============================================================
-- 1. Les quatre politiques attendues sont là :
--      SELECT policyname, cmd FROM pg_policies
--       WHERE tablename = 'documents' ORDER BY cmd, policyname;
-- 2. Un pilote supprime sa pièce depuis l'espace pilote : la ligne disparaît,
--    le fichier Storage aussi, et l'item d'éligibilité repasse « à fournir ».
-- 3. Un pilote qui remplace une pièce validée la voit repasser « en attente ».
-- 4. Un pilote ne peut pas se valider : depuis la console du navigateur,
--    supabase.from('documents').update({status:'validated'}).eq('id', <id>)
--    doit laisser le statut inchangé (le trigger le rétablit).
-- ============================================================
