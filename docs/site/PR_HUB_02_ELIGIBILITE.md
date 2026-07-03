# PR-HUB-02 — Check-up d'éligibilité pré-circuit

> Surface : 🌐 site + 🗄️ DB (+ ⏰ relances). Date : 2026-07-01. **Statut : socle DB ✅ livré et vérifié · UI admin/client + relances = suite immédiate.** Checklist validée fondateur (Q4) : validation ADMIN après chaque réservation.

## 1. Audit (vérifié live)
- ✅ `documents` couvre déjà **permis** (`driving_license`), **CNI** (`id_card`), **assurance circuit** (`insurance_track`) avec statuts + validation admin + emails (PR-SITE-10) → réutilisés tels quels.
- ❌ `vehicles` : rien pour CT / pneus-freins / sonore → items **déclaratifs** validés par l'admin.
- ✅ **pg_cron installé** → relances J-14/J-7/J-2 faisables nativement.
- ❌ Aucune table d'éligibilité existante.

## 2. Livré (migration `eligibility_items_hub02`, vérifiée)
- **`eligibility_items`** : 9 items par réservation (`permis, cni, assurance_circuit, controle_technique, pneus_freins, niveau_sonore, casque, decharge, briefing`), statuts `pending/ok/refused/na`, note, lien document, traçabilité `validated_by/at`.
- **Seed automatique** : trigger à chaque nouvelle réservation (+ **backfill** des 4 réservations actives = 36 items).
- **Synchro documents** : un permis/CNI/assurance validé ou refusé dans `documents` met à jour l'item automatiquement (trigger) — **une décision admin manuelle prime toujours**. Constaté sur données réelles : 6 items auto-passés à `ok`.
- **Vue `registration_eligibility`** (security invoker) : agrégat **GO** (tout ok/na) / **NO_GO** (≥1 refus) / **EN_ATTENTE** — lisible par le pilote (les siens), l'admin (tout) **et l'app** (même base, RLS identique).
- **RLS testée 4/4** : anon = 0 · propriétaire non-admin = ses 9 items seulement · admin = tout · **client ne peut PAS s'auto-valider** (UPDATE → 0 ligne). Fonctions seed/sync non exécutables par les clients.

## 3. Suite immédiate (même PR)
1. **UI admin** (détail session) : colonne Éligibilité par inscrit (badge GO/EN ATTENTE/NO-GO) + modale checklist 9 items (OK / Refus / N.A. + note) → écrit `eligibility_items` (policy admin).
2. **UI client** (compte-sessions) : badge par réservation + liste des pièces manquantes + CTA « Compléter mes documents ».
3. **Relances J-14/J-7/J-2** : Edge Function `eligibility-reminders` + pg_cron quotidien — email des items manquants si statut ≠ GO, idempotent via `email_log`.

## 4. Critères d'acceptation
- [x] Checklist 9 items par réservation, créée automatiquement (+ backfill).
- [x] Items documentaires branchés sur `documents` (aucune double saisie).
- [x] Statut agrégé GO/EN ATTENTE/NO-GO calculé, RLS stricte, exposé à l'app.
- [ ] Admin : validation par item depuis le détail session.
- [ ] Client : bandeau statut + pièces manquantes.
- [ ] Relances automatiques J-14/J-7/J-2.
