# PR-SITE-02 — Audit sécurité Supabase (RLS, grants, vues, fonctions, storage)

> Audit **lecture seule** via MCP Supabase, puis **1 micro-migration de durcissement** appliquée (cf. §6).
> Projet : `oxv-platform` (`fouvuqkdxarjpjbqnsjq`, eu-west-1, Postgres 17.6).
> Méthode : `pg_policies` / `information_schema` + **vérification empirique** (`has_table_privilege`, `column_privileges`, advisors officiels Supabase) + lecture de l'historique des migrations.
> Date : 2026-06-30.

## 0. Synthèse

**La RLS est saine.** Les 84 tables ont la RLS activée, les tables sensibles sont en `own_or_admin`, et — point clé découvert en cours d'audit — **la protection des PII de session est déjà en place côté DB** via un masquage au niveau colonne (migrations de juin 2026). Aucune fuite PII anon ni authenticated n'est avérée.

> ⚠️ **Note d'honnêteté sur l'audit** : une première lecture (basée sur `has_table_privilege` au niveau *table*) avait conclu à tort à (A) un admin sessions cassé et (B) une fuite PII via `USING(true)`. La vérification des **grants au niveau colonne** et de l'**historique des migrations** a invalidé ces deux points : tout est déjà correctement géré. Le détail ci-dessous reflète l'état réel vérifié.

| # | Constat | Gravité | Statut |
|---|---|---|---|
| 1 | PII sessions (`private_client_name/contact`) masquées à `authenticated` au niveau colonne + RPC admin | ✅ | **Déjà fait (DB)** |
| 2 | `loadPublicCalendar` lisait `from('sessions')` (anon = permission denied → calendrier cassé) | 🟠 | **Corrigé (code, cette PR)** |
| 3 | Grants `anon` en écriture sur tables sensibles (dormants, RLS-bloqués) | 🟡 | **Corrigé (migration, cette PR)** |
| 4 | 2 buckets storage publics (`coach-media`, `partner-media`) autorisent le listing | 🟠 | **Hors scope site** (features app — SQL fourni §7) |
| 5 | 2 fonctions admin divergentes (`is_admin` vs `oxv_is_admin`) | 🟡 | À consolider (suivi) |
| 6 | Fonctions `SECURITY DEFINER` paramétrées exécutables par anon | 🟡 | À investiguer (suivi) |

---

## 1. RLS par table sensible — ✅ CORRECT

`users, registrations, payments, vehicles, documents, sessions, contact_messages, corporate_leads, media, articles` :

| Table | SELECT | INSERT | UPDATE/DELETE |
|---|---|---|---|
| `users` | own_or_admin | own_or_admin | own_or_admin |
| `registrations` | own_or_admin | own_or_admin | own_or_admin |
| `payments` | own_or_admin | admin_all | admin_all |
| `vehicles` | own_or_admin + coach (`is_coach_of`) | own_or_admin | own_or_admin |
| `documents` | own_or_admin | own_or_admin | admin_only |
| `media` | own + `visible_to_user` | admin_all | admin_all |
| `articles` | public si `published` OR admin | admin | admin |
| `contact_messages` | admin only | public (CHECK true) | admin |
| `corporate_leads` | admin (`oxv_is_admin`) | public (CHECK true) | admin |
| `sessions` | authenticated `USING(true)` **+ masquage colonne PII** | admin_only | admin_only |

---

## 2. ✅ PII sessions — déjà protégées au niveau colonne (DB)

Migrations déjà appliquées en production :
- `20260615175209 restore_authenticated_read_on_sessions`
- `20260615184243 sessions_mask_private_client_pii_authenticated`
- `20260615184401 get_session_private_client_revoke_anon_execute`

**Vérification `column_privileges` (rôle `authenticated`, SELECT sur `sessions`)** — 18 colonnes accessibles :
`id, date, start_time, end_time, format, season_type, status, weather_status, is_private, max_capacity, capacity_access, capacity_morning, capacity_afternoon, capacity_promotion, capacity_signature, available_offers, notes, created_at`
→ **`private_client_name` et `private_client_contact` sont ABSENTES** = masquées au niveau grant.

Conséquences réelles (vérifiées) :
- **anon** : aucun grant sur `sessions` (ni table ni colonne) → `permission denied`. Lit le calendrier via la vue `sessions_public` (42 lignes en test anon). ✅
- **authenticated (pilote)** : lit toutes les lignes (RLS `USING(true)`) **mais jamais les 2 colonnes PII** (masquées). Pas de fuite. ✅
- **admin** : lit les colonnes non-PII directement, et le nom/contact privé via la RPC `get_session_private_client(p_session_id)` (`SECURITY DEFINER`, gardée `is_admin()`, `search_path` fixé). ✅

> Le `has_table_privilege(authenticated,'sessions','SELECT')=false` observé initialement vient de l'absence de grant *table-level* (seuls des grants *colonne* existent) — ce n'est PAS une régression, c'est le mécanisme de masquage.

---

## 3. Vue `sessions_public` — ✅ sûre

```sql
-- security_invoker=false (DEFINER) : nécessaire car anon n'a aucun accès à sessions
SELECT id, date, start_time, end_time, format, season_type, status, weather_status,
       is_private, max_capacity, capacity_*, available_offers, notes, created_at
FROM sessions WHERE is_private IS NOT TRUE;
```
- **Ne contient ni `private_client_name` ni `private_client_contact`** ✅. Filtre `is_private IS NOT TRUE` ✅.
- Advisor **ERROR `security_definer_view`** : **faux positif assumé** (la vue DOIT tourner en definer pour servir anon qui n'a aucun droit sur `sessions`). À documenter comme risque accepté.
- ⚠️ Expose `notes` : échantillon = infos opérationnelles non sensibles (« Météo défavorable », « Lancement saison 2026 »). Acceptable ; consigne : ne pas mettre d'info sensible dans `notes` d'une session non privée.

Autres vues : `stats_dashboard`, `coach_pilots_view`, `admin_ritual_dispatches_view` en `security_invoker=on` ✅ ; `day_rollups`/`history_rollups` idem ✅.

---

## 4. Constat corrigé en code (cette PR) — `loadPublicCalendar`

`index.html` `loadPublicCalendar` lisait encore `from('sessions')` → pour un visiteur **anonyme**, `permission denied` ⇒ **calendrier public cassé** (pas une fuite, un bug). Les 2 autres lectures publiques (`OXVApi.sessions.list`, `bkLoadDatesForOffer`) étaient déjà migrées.

**Correctif appliqué** : `from('sessions')` → `from('sessions_public')` (l.~28350). Détail dans `PR_SITE_01_AUDIT_PII.md`.

---

## 5. ✅ Durcissement grants anon (migration appliquée)

Toutes les tables accordaient `ALL` à `anon` (défaut Supabase). `anon` avait donc INSERT/UPDATE/DELETE sur `payments`, `registrations`, `users`, `sessions` — **dormants** (RLS bloque, aucune policy anon en écriture) mais fragiles.

**Migration `harden_revoke_anon_writes_sensitive_tables` appliquée** :
```sql
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.payments      FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.registrations FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.users         FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.sessions      FROM anon;
```
**Vérification post-migration** (`has_table_privilege` anon) :

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| payments | ✅ (RLS→0) | ❌ | ❌ | ❌ |
| registrations | ✅ (RLS→0) | ❌ | ❌ | ❌ |
| users | ✅ (RLS→0) | ❌ | ❌ | ❌ |
| sessions | ❌ | ❌ | ❌ | ❌ |
| contact_messages | ✅ | ✅ (requis form) | ✅ | ✅ |
| corporate_leads | ✅ | ✅ (requis form) | ✅ | ✅ |

`authenticated` non impacté (18 colonnes sur `sessions` conservées ✅).

> Durcissement supplémentaire possible (non fait, à arbitrer) : retirer `SELECT/UPDATE/DELETE` de `anon` sur `contact_messages`/`corporate_leads` en gardant **uniquement** `INSERT` (le seul droit nécessaire aux formulaires publics).

---

## 6. 🟠 Buckets storage publics — hors scope site (SQL fourni, NON appliqué)

`coach-media` et `partner-media` sont **publics** et exposent une policy SELECT large permettant le **listing complet** des fichiers (advisor `public_bucket_allows_listing`). MAIS :
- Ils ne sont **pas référencés dans `index.html`** → ce sont des features **app coach/partenaire** (autre repo), pas le site.
- Retirer la policy de listing pourrait casser une galerie côté app que cet audit ne couvre pas.

→ **Non appliqué** (pour ne pas modifier en aveugle un comportement app). SQL prêt si l'équipe app confirme qu'aucun `.list()` n'est utilisé :
```sql
-- Retire seulement le LISTING (l'accès par URL d'objet directe reste fonctionnel)
DROP POLICY "Anyone can view coach media" ON storage.objects;   -- bucket coach-media
DROP POLICY "partner_media_read"          ON storage.objects;   -- bucket partner-media
-- (optionnel : recréer une policy d'accès par préfixe si un accès public ciblé est requis)
```
Buckets `documents` et `vehicles` = privés ✅ (corrects).

---

## 7. Suivis (hors PR-01/02)

- **Deux fonctions admin** : `is_admin()` (`role='admin' OR is_admin=true`, cf. migration `is_admin_honor_flag`) vs `oxv_is_admin()` (`role='admin'` seul, utilisée par `corporate_leads`). Un compte `is_admin=true` mais `role≠'admin'` serait admin partout sauf `corporate_leads`. → Consolider sur `is_admin()`.
- **`corporate_leads` vs `contact_messages`** : le code insère les leads corporate dans `contact_messages`, alors qu'une table `corporate_leads` dédiée existe. Choisir une seule destination (cf. PR-SITE-04).
- **Fonctions `SECURITY DEFINER` paramétrées exécutables par anon** : vérifier les gardes internes de `objective_progress_for_pilot`, `pilot_sheet_for_coach`, `pilot_sessions_for_coach`, `measure_metric_now`, `ping_attendees` (sinon `REVOKE EXECUTE ... FROM anon`). Probablement publiques par design : `coach_public_card`, `get_shared_progression` (token).
- **Policies INSERT `CHECK(true)`** (`contact_messages`, `corporate_leads`) : intentionnel (formulaires publics) mais ouvert au spam anon → prévoir captcha/rate-limit (cf. PR-SITE-03/04).

---

## 8. Verdict PR-SITE-02

**✅ CONFORME.** RLS saine, PII sessions déjà protégées au niveau colonne, calendrier public réparé (code), grants anon durcis (migration). Restent 4 suivis non bloquants (buckets app, consolidation admin, fonctions definer, anti-spam). Le gate PII « aucune fuite publique » est **atteint**.
