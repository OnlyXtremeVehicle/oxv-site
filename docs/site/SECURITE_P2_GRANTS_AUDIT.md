# Sécurité P2 — Audit des GRANT EXECUTE sur les fonctions SECURITY DEFINER

> Date : 2026-07-04. Audit live : **36 fonctions** SECURITY DEFINER du schéma `public` exécutables par `anon`. **✅ APPLIQUÉ le 2026-07-04 sur « oui » fondateur** (migration `definer_grants_hardening_p2_ab`) : catégories A+B révoquées, vérifié 36 → 14 fonctions anon-exécutables restantes (= C conservées par conception + D à traiter avec l'équipe app). Policy `contact_messages` également durcie (`contact_messages_insert_hardening_site30`, usurpation bloquée testée).

## Catégorie A — Révocation anon+authenticated SANS risque (15 fonctions trigger)
Les fonctions trigger s'exécutent comme propriétaire de la table quand le trigger se déclenche ; le GRANT EXECUTE du rôle appelant n'y joue aucun rôle. Les révoquer ne change rien au fonctionnement, mais ferme un appel RPC direct inutile.
`audit_user_role_change, coach_objectives_capture_baseline, coach_objectives_log_event, guard_partner_account_status, notify_corporate_lead, notify_document_status, notify_payment_confirmed, notify_payment_invoice, notify_registration_inserted, pilot_goals_capture_baseline, pilot_goals_log_event, trg_fn_docs_to_eligibility, trg_fn_feedback_guard, trg_fn_referral_validate, trg_fn_seed_eligibility`

## Catégorie B — Révocation anon seulement (7 fonctions auto-scopées `auth.uid()`)
Sans session, `auth.uid()` est null → elles ne renvoient rien d'utile à un anonyme ; on garde `authenticated`.
`get_or_create_my_affiliation_code, my_goal_progress, my_objective_progress, my_session_annotations, my_session_objectives, rotate_my_affiliation_code, redeem_affiliation_code`

## Catégorie C — GARDER anon (public par conception)
- `get_shared_progression(p_token)`, `get_shared_progression_values(p_token)` : partage de progression par lien/token — le destinataire n'est pas connecté.
- `coach_public_card(p_coach_id)` : carte coach publique.

## Catégorie D — NE PAS TOUCHER sans audit app (helpers utilisés dans des policies RLS)
Une fonction appelée dans une policy s'exécute avec le rôle de la requête : si une table lisible en anon référence l'un de ces helpers, révoquer `anon` casse la lecture.
`is_partner, is_pro_pilot, is_detailed_coach_of, is_subscription_current, owns_partner_account, oxv_is_admin` + lecteurs coach (`pilot_sessions_for_coach, pilot_sheet_for_coach, objective_progress_for_pilot, measure_metric_now, ping_attendees`) — auto-gardés en interne, exposition anon faible risque, à traiter avec l'équipe app.

## Migration proposée (à appliquer sur « oui » fondateur)
```sql
-- Catégorie A : fonctions trigger
revoke execute on function audit_user_role_change(), coach_objectives_capture_baseline(),
  coach_objectives_log_event(), guard_partner_account_status(), notify_corporate_lead(),
  notify_document_status(), notify_payment_confirmed(), notify_payment_invoice(),
  notify_registration_inserted(), pilot_goals_capture_baseline(), pilot_goals_log_event(),
  trg_fn_docs_to_eligibility(), trg_fn_feedback_guard(), trg_fn_referral_validate(),
  trg_fn_seed_eligibility()
from public, anon, authenticated;

-- Catégorie B : anon seulement
revoke execute on function get_or_create_my_affiliation_code(), my_goal_progress(),
  my_objective_progress(), my_session_annotations(uuid), my_session_objectives(uuid),
  rotate_my_affiliation_code(), redeem_affiliation_code(text)
from public, anon;
```

## Autres points P2 liés (non appliqués, même logique d'accord)
1. **Policy insert `contact_messages`** : passer de `with check (true)` à `with check (user_id is null or user_id = auth.uid())` — cf [PR_SITE_30_CRM_USER_LINK.md](PR_SITE_30_CRM_USER_LINK.md) §4.
2. **Buckets `coach-media` / `partner-media` publics** : listing public → passer en privé + URLs signées. Impact app direct (affichage galeries) → coordonner avec l'équipe app.
3. **Consolidation `oxv_is_admin()` → `is_admin()`** : deux implémentations du même test admin ; à fusionner quand l'équipe app confirme quels objets référencent chacune.
