-- ============================================================
-- OXV — La réservation d'un pilote écrit vraiment ce qu'elle annonce
-- ============================================================
-- Trouvé le 2026-08-25 en cherchant si le défaut de `documents` était isolé.
-- Il ne l'était pas : `bkConfirmBooking()` — le bouton « Enregistrer ma
-- pré-inscription », côté pilote — écrit dans deux tables qui ne l'acceptent
-- que d'un administrateur :
--
--   payments        INSERT  payments_admin_all        :: is_admin()
--   heritage_packs  UPDATE  heritage_packs_update_... :: is_admin()
--
-- Ni l'un ni l'autre ne lève d'erreur : PostgREST répond sans broncher quand
-- une écriture ne touche aucune ligne, et le code n'attendait pas le résultat.
--
-- Conséquences, les deux encore LATENTES en base au 2026-08-25 :
--   1. Paiement — aucune ligne `payments` pour un pilote payant. La seule qui
--      existe (390 €, réf. OXV-A36CB11E) appartient à administration@oxvehicle.fr,
--      compte admin : elle est passée pour cette raison. Le premier vrai pilote
--      payant réserverait sans trace de paiement, sans référence, invisible au
--      suivi. À corriger avant l'ouverture des paiements (~janvier 2027).
--   2. Heritage — `sessions_used` jamais incrémenté : un pack de quatre
--      sessions à 2 490 € en autoriserait un nombre illimité. Aucun pack
--      n'existe encore en base, la fuite n'a donc rien coûté à ce jour.
--
-- Parti pris : on n'ouvre PAS ces tables en écriture au pilote. L'argent ne se
-- déclare pas depuis le navigateur — deux fonctions SECURITY DEFINER calculent
-- les montants côté serveur à partir de l'inscription, et vérifient
-- l'appartenance. Même mécanique que oxv_redeem_referral / oxv_name_my_crew.
--
-- Application : Supabase Studio → SQL Editor, ou `supabase db execute`.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Le paiement d'une inscription, créé par son propriétaire
-- ------------------------------------------------------------
-- Le montant vient de `registrations.price_deposit`, jamais du client :
-- un navigateur ne dicte pas ce qu'il doit. Idempotent — deux clics sur
-- « Enregistrer » ne créent pas deux lignes.
CREATE OR REPLACE FUNCTION public.oxv_create_my_payment(
  p_registration_id uuid,
  p_method public.payment_method_enum DEFAULT 'card'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_reg      public.registrations;
  v_existant public.payments;
  v_ref      text;
  v_id       uuid;
BEGIN
  SELECT * INTO v_reg FROM public.registrations WHERE id = p_registration_id;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'raison', 'inscription_introuvable');
  END IF;

  IF v_reg.user_id <> auth.uid() AND NOT public.is_admin() THEN
    RETURN json_build_object('ok', false, 'raison', 'inscription_autrui');
  END IF;

  SELECT * INTO v_existant FROM public.payments
   WHERE registration_id = p_registration_id
   LIMIT 1;
  IF FOUND THEN
    RETURN json_build_object('ok', true, 'deja_creee', true,
                             'reference', v_existant.reference);
  END IF;

  -- Une journée offerte ou déjà couverte par un pack : rien à encaisser.
  IF coalesce(v_reg.price_deposit, 0) <= 0 THEN
    RETURN json_build_object('ok', true, 'sans_objet', true);
  END IF;

  v_ref := 'OXV-' || upper(left(v_reg.id::text, 8));

  INSERT INTO public.payments
    (user_id, registration_id, amount, currency, payment_method, status, reference)
  VALUES
    (v_reg.user_id, v_reg.id, v_reg.price_deposit, 'EUR', p_method, 'pending', v_ref)
  RETURNING id INTO v_id;

  RETURN json_build_object('ok', true, 'id', v_id,
                           'montant', v_reg.price_deposit, 'reference', v_ref);
END $$;

REVOKE ALL ON FUNCTION public.oxv_create_my_payment(uuid, public.payment_method_enum) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_create_my_payment(uuid, public.payment_method_enum) TO authenticated;

-- ------------------------------------------------------------
-- 2. La consommation d'un crédit Heritage
-- ------------------------------------------------------------
-- Le pilote ne peut pas écrire `sessions_used` (il pourrait le remettre à
-- zéro) : il demande la consommation d'un crédit, le serveur l'accorde ou la
-- refuse. `FOR UPDATE` sérialise deux réservations simultanées — sans lui,
-- deux onglets consommeraient le même crédit.
CREATE OR REPLACE FUNCTION public.oxv_consume_heritage_session(p_pack_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_pack public.heritage_packs;
BEGIN
  SELECT * INTO v_pack FROM public.heritage_packs
   WHERE id = p_pack_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'raison', 'pack_introuvable');
  END IF;
  IF v_pack.user_id <> auth.uid() AND NOT public.is_admin() THEN
    RETURN json_build_object('ok', false, 'raison', 'pack_autrui');
  END IF;
  IF v_pack.status <> 'active' THEN
    RETURN json_build_object('ok', false, 'raison', 'pack_inactif');
  END IF;
  IF v_pack.sessions_used >= v_pack.sessions_total THEN
    RETURN json_build_object('ok', false, 'raison', 'pack_epuise',
                             'utilisees', v_pack.sessions_used,
                             'total', v_pack.sessions_total);
  END IF;

  UPDATE public.heritage_packs
     SET sessions_used = sessions_used + 1,
         status = CASE WHEN sessions_used + 1 >= sessions_total
                       THEN 'completed'::heritage_pack_status_enum
                       ELSE status END
   WHERE id = p_pack_id;

  RETURN json_build_object('ok', true,
                           'utilisees', v_pack.sessions_used + 1,
                           'total', v_pack.sessions_total);
END $$;

REVOKE ALL ON FUNCTION public.oxv_consume_heritage_session(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.oxv_consume_heritage_session(uuid) TO authenticated;

COMMIT;

-- ============================================================
-- Vérification après application (connecté en tant que PILOTE — le service
-- contourne RLS et ne prouverait rien).
-- ============================================================
-- 1. Réserver une journée payante : une ligne `payments` existe, au montant
--    de price_deposit, référence OXV-XXXXXXXX, statut pending.
-- 2. Rappuyer sur « Enregistrer » : toujours UNE seule ligne (idempotence).
-- 3. Réserver avec un pack Heritage : sessions_used passe de n à n+1, et le
--    pack bascule en 'completed' au quatrième.
-- 4. Depuis la console du navigateur, tenter la fraude — elle doit échouer :
--      supabase.rpc('oxv_consume_heritage_session', { p_pack_id: <pack d'un autre> })
--        → { ok: false, raison: 'pack_autrui' }
--      supabase.from('heritage_packs').update({ sessions_used: 0 }).eq('id', <le sien>)
--        → aucune ligne modifiée (l'UPDATE reste réservé à l'administration)
-- ============================================================
