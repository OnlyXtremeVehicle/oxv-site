# Décision d'architecture — Option A1 : un seul modèle (`sessions`/`registrations`)

> Surface : 🗄️ Supabase partagée (+ 📱 code app). Date : 2026-06-30. **Décision verrouillée : A1 — dépréciation totale d'`events`.** Statut : ✅ côté site & marquage DB ; ⏳ migration code app à exécuter (greenfield, 0 donnée à migrer).

## Décision
**Un seul modèle canonique** : `sessions` (l'événement) + `registrations` (la participation). Toute la famille `events` est **supprimée** : `events`, `event_registrations`. Les tables B2B utiles (`b2b_event_reports`, `event_partners`) sont **conservées mais repointées** sur `sessions`.

**Critère décisif : « un seul modèle ».** C'est ce qui rend la prod surveillable (une source de vérité, moitié moins de RLS/admin/surface) et le développement futur rapide (on construit sur une fondation complète — auth, paiement, emails, média, télémétrie déjà reliés à `sessions` — pas sur un modèle parallèle ni à cheval sur deux).

## Constat (live, 2026-06-30) — tout est greenfield
| Table | Lignes | Décision |
|---|---|---|
| `sessions` / `registrations` | 44 / 5 | **canonique** (données réelles + toute la plomberie de prod) |
| `events` | 1 (test) | **à supprimer** |
| `event_registrations` | 0 | **à supprimer** |
| `b2b_event_reports` | 0 | conserver, **repointer `event_id` → `sessions.id`** |
| `event_partners` | 0 | conserver, **repointer `event_id` → `sessions.id`** |
| `telemetry_sessions` | 16 | lien réservation par **`user_id`** ; `event_id` non alimenté (0/16) → **drop colonne** |

- Le **site ne référence pas** `events`/`event_registrations` (0 occurrence) → côté site, déjà conforme.
- Coût quasi nul **aujourd'hui** (toute la famille events est vide) ; il augmente après le lancement de l'app → décider/migrer maintenant.

## Forme cible (un seul monde)
- **`sessions`** = l'événement. Ajouter au besoin `session_type` enum (`public` par défaut | `corporate`) pour distinguer le B2B des journées pilotes, + `metadata` jsonb pour l'extensibilité future (échappatoire souple, comme `available_offers` déjà en jsonb). *Règle future : nouvelle idée = une colonne / clé jsonb / petite table satellite reliée à `session_id` ou `user_id`, jamais un nouvel univers de tables.*
- **`registrations`** = la participation pilote (déjà : user_id, offer, price, insurance, attended, annulation…).
- **`b2b_event_reports` / `event_partners`** = add-ons B2B, repointés sur `sessions.id`. Le B2B devient « une session privatisée » (`is_private=true` + `session_type='corporate'`).
- **Télémétrie** reliée par `user_id` (+ corrélation temporelle, cf spec connexion app).

## Fait dans cette PR (sûr, non destructif)
- Migration `deprecate_events_model_option_a` appliquée : `COMMENT … IS 'DEPRECATED …'` sur `events`, `event_registrations`, `telemetry_sessions.event_id`. Réversible, aucun impact comportemental.
- Site vérifié indépendant.

## Plan de migration (côté app — greenfield, ordre sûr)

**Phase 1 — Code app** (events est vide : aucune perte)
1. `eventsService.ts`, `adminAnalyticsService.ts`, `dataExportService.ts`, tests RLS `events*` → lire `sessions` / `registrations`. Mapping : `events.starts_at`→`sessions.date`+`start_time` · `max_pilots`→`max_capacity` · `pricing`→`available_offers` · `event_registrations.pilot_id`→`registrations.user_id` · `checked_in_at`→`registrations.attended_at`.
2. `b2bReportService.ts` → lire/écrire `b2b_event_reports` et `event_partners` via `sessions.id` (le repoint FK arrive en Phase 3).

**Phase 2 — Schéma additif (non bloquant, réversible)**
3. (si distinction B2B voulue) `ALTER TABLE sessions ADD COLUMN session_type … DEFAULT 'public'` + `metadata jsonb`. Additif, n'affecte pas le site.

**Phase 3 — Bascule FK + suppression (après déploiement app)**
4. Repointer : `b2b_event_reports.event_id` et `event_partners.event_id` → FK vers `sessions.id` (drop ancienne FK → events, add nouvelle FK → sessions).
5. `ALTER TABLE telemetry_sessions DROP COLUMN event_id` (non alimenté).
6. `DROP TABLE event_registrations;` puis `DROP TABLE events;` (migrer/abandonner la 1 ligne test au préalable).

**Rollback** : tant que Phase 3 n'est pas faite, tout est réversible (COMMENT annulables, colonnes additives, aucun code site impacté).

## Seule micro-question de design (côté app)
Un participant B2B (invité d'une concession) est-il un **compte `users`** ou un **invité sans compte** ?
- Compte → il rentre dans `registrations` (qui exige `user_id`).
- Invité sans compte → petite table satellite `session_guests(session_id, name, email…)` plutôt que `registrations`.
C'est le seul vrai choix restant, et il est mineur.

## Action requise
Exécuter Phase 1→3 côté app (effort code, 0 donnée à migrer) + trancher la micro-question B2B guests. Réf : [audit connexions](PR_SITE_22-27_AUDIT_CONNEXIONS.md), [connexion progression](PR_SITE_CONNEXION_PROGRESSION.md).

**Verdict : ✅ A1 verrouillé — un seul modèle canonique. Côté site terminé ; reste = migration code app (greenfield).**
