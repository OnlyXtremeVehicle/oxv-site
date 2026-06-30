# PR-SITE-21 — Contrat commun comptes / rôles / consentements (site ↔ app)

> Surface : 🗄️ Supabase partagé + 🌐 site + 📱 app. Date : 2026-06-30. **Statut : ✅ vérifié** (contrat satisfait par construction — aucun code à changer).

## 1. Auth & comptes — UN seul Supabase

| | Valeur |
|---|---|
| Site (`index.html`) | `SUPABASE_URL = https://fouvuqkdxarjpjbqnsjq.supabase.co` |
| App (`oxv-app/.env`) | `EXPO_PUBLIC_SUPABASE_URL = https://fouvuqkdxarjpjbqnsjq.supabase.co` |

➡️ **Même projet Supabase** → même Supabase Auth, même table `public.users`, même `user_id = auth.uid()`. **Un compte créé sur le site se connecte dans l'app avec le même `user_id`** — critère d'acceptation PR-21 **satisfait par construction**. Aucune synchronisation à coder.

## 2. Rôles — source unique

Enum partagé `public.user_role = {pilot, admin, coach, partner, pro_pilot}` (sur `users.role`) + flag `users.is_admin`.

### Matrice rôle × accès
| Rôle | Site | App |
|---|---|---|
| **pilot** | espace pilote (booking, véhicules, documents, sessions, paiements, progression) | OXV Trace complet (Pass, Trace, Bilan, Data Lab, Carnet, Passeport, garage, club) |
| **admin** | back-office (inbox, paiements, sessions, documents, médias, articles, stats, sécurité) | route `(admin)` app |
| **coach** | — (vu comme pilote sur le site) | route `(coach)` : pilotes assignés (lecture seule, consentie) |
| **partner** | — (page Corporate publique pour prospecter) | route `(partner)` : médias/offres partenaires |
| **pro_pilot** | — | route `(pro)` |

Note : un coach/partner/pro_pilot qui se connecte au **site** retombe dans l'espace pilote (le site ne teste que `role='admin'` pour le back-office) — pas de blocage ni de fuite (RLS own_or_admin). Cohérent.

## 3. Consentements — colonnes partagées sur `users`
`cgu_accepted_at`/`cgu_version`, `privacy_accepted_at`/`privacy_version`, `pact_accepted_at`/`pact_version` (site) · `coach_pact_accepted_at`/`version`, `ai_debrief_enabled`, `coach_ai_enabled` (app, opt-in) · `accepts_marketing`, `notif_newsletter`, `notif_offers`, `notification_preferences`, `push_notif_enabled`, `ritual_jminus7/2/1_enabled`, `two_factor_enabled`.

➡️ Tous sur la **même ligne `users`** : un consentement posé sur une surface est lu par l'autre. Les opt-in IA/coach (défaut OFF) sont respectés des deux côtés. **Pas de contradiction de consentement** possible (données uniques).

## 4. Divergences relevées (à corriger, non bloquantes)
1. **Deux fonctions admin** : `is_admin()` (`role='admin' OR is_admin=true`) vs `oxv_is_admin()` (`role='admin'` seul, utilisée par RLS `corporate_leads`). Un compte `is_admin=true` mais `role≠'admin'` serait admin partout **sauf** `corporate_leads`. → Consolider sur `is_admin()` (cf. PR-02). **Action : 1 migration** (réécrire les policies `corporate_leads`).
2. **CGV** : le site parle de CGV mais `users` n'a pas de `cgv_accepted_at` distinct (seulement `cgu`/`privacy`/`pact`). Vérifier si l'acceptation CGV est couverte par `pact`/`cgu` ou s'il faut une colonne dédiée (impact juridique — à arbitrer).
3. **Centre de consentement** unifié (UI) : les données sont partagées, mais il n'existe pas d'écran unique « gérer mes consentements » côté site reprenant les opt-in app (IA, coach, push). Amélioration UX (non bloquante).

## 5. Critères d'acceptation
- [x] Un compte créé sur le site fonctionne dans l'app avec le même `user_id` (même Supabase Auth).
- [x] Rôles et permissions centralisés (enum `user_role` unique + RLS `is_admin()`/own).
- [x] Matrice rôle × accès documentée (§2).
- [x] Consentements cohérents (colonnes uniques sur `users`).

## 6. Conséquence pour la suite (PR-22 → 27)
La fondation est saine : pas de pont d'identité à construire. Les PR suivantes sont donc du **câblage de lecture/écriture sur des tables déjà partagées** + des écrans app :
- **PR-22** (résa visible app) / **PR-23** (Pass OXV depuis registration) / **PR-24** (sessions↔events) / **PR-25** (docs/véhicules) / **PR-26** (paiement→Pass) : lecture des tables `registrations`/`sessions`/`payments`/`documents`/`vehicles` côté app (RLS own déjà en place) + écrans app.
- **PR-27** (flux média) : tables `media`/`session_media` + buckets existants + écran galerie app.

**Verdict : ✅ PR-SITE-21 — contrat commun vérifié et documenté.** 1 micro-migration à prévoir (consolidation `oxv_is_admin`→`is_admin`).
