# Décision d'architecture — Option A : dépréciation `events` / `event_registrations`

> Surface : 🗄️ Supabase partagée (+ 📱 code app). Date : 2026-06-30. **Décision produit prise (Option A).** Statut : ✅ côté site & marquage DB ; ⏳ migration code app à planifier.

## Décision
Le **modèle canonique** des journées de roulage et des inscriptions est **`sessions` / `registrations`** (modèle site, source de vérité, doctrine « le site vend l'expérience »). Les tables **`events` / `event_registrations`** (modèle app, quasi vides) sont **dépréciées**.

## Constat (live, 2026-06-30)
| Table | Lignes | Rôle |
|---|---|---|
| `sessions` / `registrations` | 44 / 5 | **canonique** (données réelles, utilisé par le site) |
| `events` / `event_registrations` | 1 (test) / 0 | déprécié |
| `telemetry_sessions` | 16 | lien réservation par **`user_id`** (la colonne `event_id` est **non alimentée : 0/16**) |

- **Le site ne référence pas du tout** `events`/`event_registrations` (0 occurrence dans `index.html`) → côté site, Option A est **déjà** satisfaite.
- **Bloqueurs d'un `DROP`** : 4 FK pointent vers `events` — `b2b_event_reports.event_id`, `event_partners.event_id`, `event_registrations.event_id`, `telemetry_sessions.event_id`. Tous **côté app**.

## Fait dans cette PR (sûr, non destructif)
- Migration `deprecate_events_model_option_a` appliquée : **`COMMENT ... IS 'DEPRECATED …'`** sur `events`, `event_registrations`, `telemetry_sessions.event_id`. Aucun impact comportemental, réversible (`COMMENT … IS NULL`).
- Vérifié : indépendance totale du site.

## Plan de migration (côté app — à exécuter par l'équipe app)

**Phase 1 — Code app** (aucune perte de données, events est vide)
1. `eventsService.ts`, `adminAnalyticsService.ts`, `dataExportService.ts`, tests RLS `events*` → lire `sessions` / `registrations` (mapper : `events.starts_at`→`sessions.date`+`start_time`, `max_pilots`→`max_capacity`, `pricing`→`available_offers`, `event_registrations.pilot_id`→`registrations.user_id`, `checked_in_at`→`registrations.attended_at`).
2. **Sous-décision B2B** : `b2b_event_reports` / `event_partners` référencent `events`. Deux options :
   - (A1) Repointer le B2B sur `sessions` (`is_private=true` + `private_client_name`) → dépréciation totale d'`events`.
   - (A2) Conserver `events` **uniquement** pour le B2B (dépréciation partielle : events = événements corporate, sessions = journées pilotes). À trancher selon l'usage réel du B2B dans l'app.

**Phase 2 — Télémétrie**
3. `telemetry_sessions.event_id` non alimenté → le **retirer** (ou le repointer vers `session_id` si un lien dur est souhaité ; la spec connexion utilise déjà `user_id` + corrélation temporelle, donc retrait recommandé).

**Phase 3 — Base (après déploiement app, dans l'ordre)**
4. Si A1 retenu : migrer/abandonner la 1 ligne test `events`, drop FK + `DROP TABLE event_registrations`, repointer ou drop `b2b_event_reports`/`event_partners`, puis `DROP TABLE events`.
5. Si A2 retenu : ne garder qu'`events` pour le B2B, drop `event_registrations` seule.

**Rollback** : tant que Phase 3 n'est pas faite, tout est réversible (les COMMENT s'annulent ; aucun code site impacté).

## Action requise
Trancher la **sous-décision B2B (A1 vs A2)**, puis exécuter Phase 1→3 côté app. Référence : [audit connexions](PR_SITE_22-27_AUDIT_CONNEXIONS.md), [connexion progression](PR_SITE_CONNEXION_PROGRESSION.md).

**Verdict : ✅ Option A actée et marquée en base ; site indépendant ; reste = migration code app (effort app, données nulles à migrer).**
