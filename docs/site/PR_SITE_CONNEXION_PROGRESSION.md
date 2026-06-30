# PR-SITE — Connexion app : page « Ma progression » (Phase 2)

> Surface : 🌐 site (`index.html`) + 🗄️ Supabase partagée. Date : 2026-06-30. **Statut : ✅ connexion vérifiée + fix doctrine livré ; reste additif documenté.**

## 1. État réel des données (audit live)
Base Supabase **partagée** site ↔ app (`fouvuqkdxarjpjbqnsjq`). Deux modèles, un pivot :

| Domaine | Tables | Données | Propriétaire |
|---|---|---|---|
| **Réservation** | `sessions` (44), `registrations` (5), `payments` (2), `heritage_packs` | réelles | **site** (source de vérité) |
| **Télémétrie / progression** | `telemetry_sessions`, `laps`, `weather_snapshots`, `app_session_analyses` | vides (pré-lancement) | **app** (écrit), site (lit) |
| **Pivot** | `users` (14) | partagé | commun (champs site + app : kyc, expo_push_token, livery, coach_pact…) |
| Modèle parallèle | `events` (1 test), `event_registrations` (0) | quasi vide | app (cf §4) |

## 2. Décision d'architecture — tranchée par la spec app
Le doc app `docs/architecture/08_CONNEXION_PROGRESSION_SITE_APP.md` fixe l'architecture (donc plus en attente) :
- **Réservations = `sessions`/`registrations`** (modèle site), lues par l'app.
- **Progression = `telemetry_sessions`/`laps`/`app_session_analyses`** (modèle app), lues par le site.
- **Lien = `user_id`**. **Aucune migration de schéma** nécessaire ; RLS `auth.uid() = user_id` protège déjà.

## 3. Ce qui est DÉJÀ câblé (vérifié)
`loadProgression()` (espace pilote → « Ma progression ») **lit réellement `app_session_analyses`** du modèle app : score QDI (`margin_global`), marges pilote/véhicule/zone, évolution multi-sessions, débrief coach réel (`next_focus_phrase`, `debrief_text`), états **vide** et **en attente** honnêtes. La connexion fonctionne ; elle s'allumera dès que l'app produira des analyses.

## 4. Livré dans cette PR — conformité doctrine
La page violait la doctrine app écrite (« pas de badges, pas d'emoji, pas de classement, pas de gamification ») :
- **Retiré** les médailles emoji `👑🥇🥈🥉` et les paliers podium **Elite/Or/Argent/Bronze/Novice** (JS `oxvScoreLevel`, libellés « prochain palier », défaut HTML du hero, état vide « NIVEAU 0 »).
- **Remplacé** par une lecture **personnelle** neutre : *À découvrir · En découverte · En progression · Confirmé · Avancé · Maîtrise* (sans emoji, sans podium). Le QDI reste un score personnel (déjà cadré « pas de classement » côté home).
- Hero par défaut marqué **« EXEMPLE »** (aperçu illustratif, pas de fausse donnée présentée comme réelle).

## 5. Reste à faire (additif, non bloquant — utile quand l'app produira des données)
Aligné sur la spec app, à brancher quand des données réelles existeront (actuellement 0 télémétrie) :
- **KPI « Sessions effectuées »** depuis `registrations` (`status='attended'`) au lieu du nombre d'analyses.
- **« Mes dernières sessions »** + **records personnels** depuis `telemetry_sessions` (lap_count, best_lap_seconds, max_speed_kmh) + jointure `weather_snapshots`.
- **CTA app + deep links** `oxvcoach://bilan/{id}` (section 6 de la spec) — quand l'app sera publiée.
- **Clarifier `events`/`event_registrations`** avec l'équipe app : non utilisés par la connexion (la spec s'appuie sur `sessions`/`registrations`) → à déprécier ou à documenter comme domaine app distinct. Cf [audit connexions](PR_SITE_22-27_AUDIT_CONNEXIONS.md).

## 6. Vérification
- 0 médaille emoji résiduelle, 0 palier podium ; nouveaux libellés présents ; `loadProgression` lit `app_session_analyses`.
- Aucune modification de schéma ; lecture seule ; RLS inchangée.

**Verdict : ✅ connexion progression vérifiée + conforme doctrine.** Le gros de la Phase 2 (lecture des données app) était déjà en place ; cette PR la rend doctrine-compliant et documente l'architecture désormais tranchée + le reste additif.
