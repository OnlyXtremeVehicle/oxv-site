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

## 5. Branché « avant la sortie de l'app » (livré)
Lectures réelles + UI câblées, prêtes à s'allumer dès que l'app produira des données (aujourd'hui 0 télémétrie → états vides honnêtes) :
- **KPI « Sessions effectuées »** = `registrations.status='attended'` (vraie donnée site), à la place du nombre d'analyses.
- **Bloc « Sessions enregistrées par l'app »** : lit `telemetry_sessions` (8 dernières), affiche par session date · circuit · tours · meilleur tour, + récap **records personnels** (tours bouclés, meilleur tour, vitesse max — pas de classement). État vide honnête avant la sortie de l'app.
- **Deep links** `oxvcoach://bilan/{id}` par session (« Ouvrir dans l'app ») — inertes avant publication, fonctionnels au lancement. L'encart « OXV Trace arrive » (printemps 2027) reste la promo store.
- `oxvFmtLap()` (format m:ss.mmm), `renderTelemetrySessions()` ; `node --check` du module : OK.

## 6. Reste (hors périmètre site / décision app)
- **Clarifier `events`/`event_registrations`** avec l'équipe app : non utilisés par la connexion (la spec s'appuie sur `sessions`/`registrations`) → à déprécier ou à documenter comme domaine app distinct. Cf [audit connexions](PR_SITE_22-27_AUDIT_CONNEXIONS.md).
- Marge moyenne V2, graphique long terme : déjà couverts par le moteur QDI (`app_session_analyses`) existant.
- Deep links opérationnels : dépend de la publication de l'app + du schéma d'URL `oxvcoach://`.

## 7. Vérification
- 0 médaille emoji résiduelle, 0 palier podium ; nouveaux libellés présents.
- `loadProgression` lit `app_session_analyses` + `telemetry_sessions` + `registrations` (attended) ; `renderTelemetrySessions` + conteneurs présents ; `node --check` du module applicatif : OK.
- Aucune modification de schéma ; lecture seule ; RLS inchangée.

**Verdict : ✅ connexion progression doctrine-compliant + tout le pré-lancement branché.** Côté site, la Phase 2 est prête : dès que l'app produira de la télémétrie, la page « Ma progression » s'allume sans intervention. Reste un point app (statut de `events`/`event_registrations`).
