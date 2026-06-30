# Audit connexions site ↔ app (PR-22 à 27) — décision d'architecture requise

> Audit lecture seule du repo app (`oxv-app`) + site. Date : 2026-06-30. **Statut : 🔴 bloqué sur une décision d'architecture (PR-24).**

## 1. Constat structurant : DEUX modèles de données parallèles

Site et app partagent le **même projet Supabase**, mais **chaque côté écrit/lit sa propre famille de tables** — physiquement distinctes, sans pont :

| Notion | Tables **SITE** (écrites par `index.html`) | Tables **APP** (lues par l'app) |
|---|---|---|
| Réservation | `registrations` (`session_id`, `offer_type`, `status`, `price_total`, `attended_at`) | `event_registrations` (`event_id`, `pilot_id`, `status`) |
| Calendrier | `sessions` (`date`, `season_type`, `is_private`, capacités) | `events` (`event_type`, `slug`, `starts_at`, `briefing_at`) |
| Paiement | `payments` (`registration_id`, `amount`, `status`, `paid_at`) | *(aucune lecture)* |
| Média | `media` (`session_id`, `file_url` public, `visible_to_user`, `published_at`) | `session_media` (`telemetry_session_id`, `storage_path` privé + URL signée) |

**Preuves** : côté app, `from('registrations'|'payments'|'sessions'|'media')` = **0 résultat** ; côté site, `from('events')` = 0 (les « events » sont du CSS `pointer-events`). Les deux familles coexistent dans `database.types.ts`.

➡️ Mon hypothèse PR-21 (« plus qu'à câbler ») est **corrigée** : l'identité/les comptes sont bien partagés, mais **les domaines booking/calendrier/média ne le sont pas**. Une réservation site **n'apparaît pas** dans l'app.

## 2. Verdict par PR
| PR | Verdict | Écart réel |
|---|---|---|
| **22** Résa visible app | ❌ absent (pour la résa site) | l'app lit `event_registrations`, pas `registrations` du site |
| **23** Pass OXV depuis registration | ⚠️ partiel (mauvaise registration) | Pass dérivé d'`event_registrations` ; pas de statut docs/paiement ; QR encode un `event_registrations.id` |
| **24** Sessions ↔ Events | 🔴 **deux notions à unifier** | **décision pivot** : `sessions`+`registrations` (site) vs `events`+`event_registrations` (app) |
| **26** Paiement → Pass | ❌ absent | l'app ne lit jamais `payments` |
| **27** Flux média | ⚠️ partiel (2 systèmes disjoints) | galerie app lit `session_media` ; admin site écrit `media` → jamais visibles dans l'app |

## 3. Déjà fonctionnel — NE PAS reconstruire
- Écran Pass OXV (`pass-oxv.tsx`) + génération QR ; **scan admin** (`app/(admin)/scan-checkin.tsx`) + check-in (le commentaire « scan à brancher » est périmé).
- Galerie pilote (`galerie.tsx`, `session-media/[sessionId].tsx`) + RLS own-media + URLs signées.
- Inscription à un `event`, rapport B2B, lien capture↔event (`telemetry_sessions.event_id`).

## 4. 🔴 LA décision (PR-24) — bloque 22/23/26/27

Il faut choisir **un seul modèle** :

- **Option A — l'app adopte le modèle SITE** (`sessions` + `registrations` + `payments` + `media`).
  - *Pour* : le site est la porte commerciale (réservation + paiement réels) ; tout converge vers la donnée payante. Le média admin site devient directement visible.
  - *Contre* : refonte des écrans app (Pass/QR/galerie/B2B) pour pointer sur les tables site ; le lien capture télémétrie↔event à re-mapper sur `sessions`.

- **Option B — le site adopte le modèle APP** (`events` + `event_registrations`).
  - *Pour* : l'app (Pass/QR/check-in/B2B/télémétrie) reste inchangée.
  - *Contre* : refonte du booking/paiement du site (récent et fiabilisé en PR-03→08) pour écrire `events`/`event_registrations` ; risque de régression sur le commercial qu'on vient de stabiliser.

- **Option C — pont de synchronisation** (vues/triggers mappant `registrations`↔`event_registrations`, `sessions`↔`events`).
  - *Pour* : pas de refonte des écrans ; chaque côté garde son modèle.
  - *Contre* : double-écriture/sync à maintenir, source de vérité ambiguë, complexité et bugs de cohérence (le plus risqué à long terme).

**Recommandation** : **Option A** (converger vers le modèle site = la donnée commerciale/payante fait foi), en migrant progressivement les lectures app. Mais c'est un **choix produit/technique majeur** sur deux codebases — à valider par toi.

## 5. Plan une fois la décision prise (esquisse, Option A)
1. App : `pass-oxv` / « Mes réservations » lisent `registrations` (jointe `sessions`) + `payments` (statut) → PR-22 + 26.
2. App : Pass dérivé de la `registration` validée + statut documents (`documents`) ; QR encode l'`id` de référence retenu → PR-23.
3. Média : la galerie app lit `media` (filtre `user_id` + `visible_to_user`, `file_url` public) → PR-27 ; ou l'admin site écrit `session_media`.
4. Vérifier RLS `registrations`/`payments` : lecture own-row par `authenticated` (à confirmer).

## 6. Verdict
**Phase 2 connexions = bloquée sur la décision §4.** Les écrans app existent ; le travail est du **câblage DB + reroutage de lectures**, pas de la création d'UI. Aucune ligne modifiée tant que la direction n'est pas tranchée.
