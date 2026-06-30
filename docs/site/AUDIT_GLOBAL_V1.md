# OXV — Audit global V1 (état des lieux avant chantier)

> Audit en **lecture seule**. Aucune ligne du site n'a été modifiée.
> Branche auditée : `claude/focused-lalande-d05140` (basée sur `main` / commit `28566e9`).
> Fichier principal : `index.html` (29 065 lignes). Backend Supabase. Paiement par virement.
> Date : 2026-06-30.

> **MàJ** : PR-SITE-01 et PR-SITE-02 ont depuis été traitées — voir `PR_SITE_01_AUDIT_PII.md` et `PR_SITE_02_AUDIT_RLS.md` (autoritatifs). Le §1 ci-dessous reflète l'état initial ; le diagnostic PII a évolué (protection déjà en place côté DB via masquage colonne, seul le code du calendrier restait à aligner).

## 0. Verdict express

Le site est **beaucoup plus avancé qu'il n'y paraît** : auth, booking, paiements, sessions, documents, articles et médias sont réellement branchés sur Supabase. Le travail restant n'est pas une refonte, c'est de la **fiabilisation** :

1. **1 fuite PII résiduelle** sur le calendrier public (le correctif existe déjà dans `hotfix`, pas porté ici).
2. **Faux succès** sur les formulaires (le toast « envoyé » s'affiche même si l'insert Supabase échoue).
3. **Emails transactionnels non opérationnels** (aucune Edge Function déployée — tout est en placeholder).
4. **Admin inbox absente** (la table `contact_messages` reçoit les leads, mais aucun écran admin ne les lit).
5. Quelques **faux modules / libellés trompeurs** à nettoyer (faux upload B2B, toasts « email envoyé » mensongers, commentaires périmés).

| Bloc | PR | Verdict | Gravité |
|---|---|---|---|
| PII calendrier public | 01 | ⚠️ Partiel — fuite résiduelle | **P0** |
| Audit RLS Supabase | 02 | ❓ Non vérifiable depuis le repo | **P0** |
| Contact réel | 03 | ⚠️ Insert réel mais faux succès si erreur | **P0** |
| Corporate leads | 04 | ⚠️ Insert réel mais metadata non structurée + source incohérente | **P0** |
| Emails transactionnels | 05 | ❌ Aucune Edge Function déployée | **P0** |
| Booking | 06 | ✅ Réel — RIB factice, pas d'anti-doublon | **P0** |
| Admin inbox | 07 | ❌ Absent (table prête, lecture à construire) | **P1** |
| Admin paiements | 08 | ✅ Réel (nom « MOCK » trompeur) | **P1** |
| Admin sessions | 09 | ✅ Quasi complet | **P1** |
| Admin documents | 10 | ✅ Réel | **P1** |
| Médias | 11 | ⚠️ Table OK, pas d'upload Storage (URL collée) | **P2** |
| Articles | 12 | ✅ Réel (Supabase + draft/published) — libellés trompeurs | **P2** |
| Page App OXV Trace | 13 | (non audité ici) | **P1** |
| Offres / FAQ | 14/15 | (non audité ici) | **P1** |
| SEO JSON-LD | 16 | ⚠️ Partiel | **P2** |
| Analytics | 17 | ❌ Absent | **P2** |
| Inventaire mocks | 18 | — voir §5 | **P1** |

---

## 1. Sécurité PII / sessions (PR-SITE-01) — ⚠️ PARTIEL

### Lectures de la table privée `sessions`
13 lectures `from('sessions')`. **Toutes en contexte admin authentifié sauf une** :

| Ligne | Fonction | Contexte | Risque |
|---|---|---|---|
| **28342** | **`loadPublicCalendar`** (`/calendrier`) | **ANONYME / PUBLIC** | **CRITIQUE** |
| 21905 | `loadAdminMedias` | Admin | Lit `private_client_name` en clair (sans RPC) |
| 25368, 25475, 27313, 27374, 27415, 27713, 27963, 27982, 28032, 28051, 28066, 28342 | diverses fonctions admin | Admin | OK |

**Point critique — ligne 28342** : `loadPublicCalendar` fait `from('sessions').select('*')` côté visiteur non authentifié. `select('*')` rapatrie toutes les colonnes (dont `private_client_name`, `notes`) ; la sécurité repose entièrement sur la RLS de la table. C'est exactement la lecture que la vue `sessions_public` doit remplacer.

### Vue sûre & RPC
- `sessions_public` n'est utilisée qu'à 2 endroits déjà migrés : `OXVApi.sessions.list()` (l.19332) et `bkLoadDatesForOffer()` (l.20542).
- RPC `get_session_private_client` : **ABSENTE** de la branche actuelle (présente uniquement dans `hotfix`). Le nom privé est lu en clair l.21906 et rendu l.21955.

### Écart `main` ↔ `hotfix/sessions-public-pii`
La branche `hotfix` contient 2 correctifs PII **non portés** sur la base de travail actuelle :

| Correctif | hotfix | branche actuelle |
|---|---|---|
| `loadPublicCalendar` → `sessions_public` (commit `6c8c2f0`) | ✅ | ❌ **manque** |
| RPC `get_session_private_client` + lecture admin conditionnelle (commit `a7b7b98`) | ✅ | ❌ **manque** |

> **Décision retenue : réconcilier le hotfix** (porter ces 2 commits) plutôt que recoder.

### robots.txt / sitemap.xml
✅ RAS. Routes privées en `Disallow`, sitemap = pages publiques uniquement. Aucune incohérence.

### Actions PR-SITE-01
1. **[P0]** Porter `loadPublicCalendar` → `sessions_public` (l.28342).
2. **[P0]** Porter la lecture admin du nom privé via `rpc('get_session_private_client')` (l.21906/21955).
3. **[P0]** Côté DB : confirmer que la RPC existe (SECURITY DEFINER, gardée `is_admin()`) et que la RLS de `sessions` n'autorise pas la lecture anon de `private_client_name`.

---

## 2. Audit RLS Supabase (PR-SITE-02) — ❓ NON VÉRIFIABLE DEPUIS LE REPO

Les politiques RLS vivent côté serveur Supabase, pas dans le repo. À auditer via le dashboard / MCP Supabase : `users`, `registrations`, `payments`, `vehicles`, `documents`, `sessions`, `sessions_public`, `contact_messages`. Objectif : `anon` limité au strict public, tout le reste gardé `is_admin()` ou propriétaire.

---

## 3. Formulaires de conversion (PR-SITE-03 / 04) — ⚠️ PARTIEL

### Contact (`submitContact`, l.22585-22626)
- ✅ Insert réel dans `contact_messages` (l.22611).
- ❌ **Faux succès** : en cas d'erreur, l'insert est seulement `console.warn` (l.22614) puis le toast de succès s'affiche quand même (l.22623, hors `catch`) → **perte de leads silencieuse**.
- ⚠️ `source` absent du payload (prend le DEFAULT SQL `contact_form`). Loading = `pointerEvents` seulement.

### Corporate (`submitCorporate`, l.21304-21361)
- ✅ Insert réel (l.21338).
- ⚠️ `source='corporate-form'` (tiret) alors que la convention SQL prévoit `corporate_form` (underscore) → **mismatch** qui cassera les filtres admin par source. Idem `founding-form`.
- ⚠️ **metadata non structurée** : company, role, phone, event_type, guests, dates sont concaténés en texte dans `message` au lieu d'aller dans la colonne `metadata JSONB`. `budget_range` non collecté.
- ❌ Fonction morte `submitB2B` (l.21288-21301) : IDs `corp-*` rattachés à aucun formulaire → pur faux succès. À supprimer.

### Schéma `migration_contact_messages.sql`
✅ Bien conçu : `source` + `metadata JSONB` + `status` (new/read/replied/spam/archived) + RLS (insert public, lecture/modif `is_admin()`). **Supporte le pattern table partagée** — mais le code ne l'exploite pas (metadata vide, source incohérente).

### Actions PR-03/04
1. **[P0]** Contact : déplacer le toast succès dans le `try` après vérif `!error` + toast d'erreur explicite.
2. **[P0]** Ajouter `source` explicite et harmoniser (`corporate_form`, `founding_form`).
3. **[P1]** Remplir `metadata` JSONB (corporate) ; ajouter champ `budget_range`.
4. **[P1]** Supprimer `submitB2B` morte + `fakeUpload`.
5. Vrai état loading (spinner) sur les deux formulaires.

---

## 4. Emails transactionnels (PR-SITE-05) — ❌ NON OPÉRATIONNEL

- ✅ **Aucune clé API email en clair côté client** (bon point — pas de fuite Resend/SendGrid).
- ❌ **Dossier `supabase/functions/` inexistant** : aucune Edge Function déployée.
- Déclencheurs côté client présents mais sans backend : `send-confirmation-email` (l.21237), `send-email` (l.22233), `validate-inscription` (l.25716).
- `triggerPaymentConfirmedEmail` (l.28131) = **placeholder** : juste `console.log('[OXV Email queued]')` (l.28161).
- Emails **totalement absents** même côté front : `contact_confirmation`, `corporate_lead_admin`, `admin_new_booking`.

### Actions PR-05
1. **[P0]** Créer `supabase/functions/` et déployer `send-confirmation-email`, `send-email`, `validate-inscription`.
2. **[P0]** Brancher Resend avec clé **uniquement en secret Supabase** (jamais côté client).
3. **[P1]** Implémenter `contact_confirmation`, `corporate_lead_admin`, `admin_new_booking`.
4. **[P1]** Remplacer le `console.log` placeholder par un vrai envoi.
5. Idéalement : déclencher via trigger DB / webhook sur insert plutôt que depuis le client.

---

## 5. Booking & Admin (PR-SITE-06 à 10)

### Booking (PR-06) — ✅ RÉEL avec réserves
- Wizard 5 étapes (`bkState`), cœur `bkConfirmBooking` (l.21043) : insert réel `registrations` (l.21132) + `payments` (l.21142).
- Statuts registration : `pending`→`confirmed`→`attended`/`cancelled`. Paiement : `pending`→`succeeded` **OU** `paid` selon le chemin → **incohérence d'enum** (deux valeurs pour « validé »).
- ✅ Garde-fou documents (permis + assurance) avant réservation (l.21068-21096).
- ⚠️ **RIB en dur factice** (`FR76 XXXX...`, BIC `XXXXXXXX`, l.18425-18427) → **inutilisable en prod**.
- ⚠️ Référence `OXV-...` générée côté client depuis l'UUID mais **jamais persistée** (colonne `payments.reference` lue mais pas écrite).
- ❌ **Aucun garde-fou anti-double-inscription** (même user + même session possible plusieurs fois).
- Stub mort `OXVApi.sessions.book` (l.19338, `depositUrl:'#stripe'`).

**Actions P06 :** renseigner le vrai RIB ; anti-doublon (contrainte unique `(user_id, session_id)`) ; harmoniser l'enum paiement ; persister `payments.reference` ; supprimer le stub.

### Admin paiements (PR-08) — ✅ RÉEL (« MOCK » = nom trompeur)
`MOCK_PAYMENTS` (l.21460) est un tableau **alimenté depuis la vraie table `payments`**. `loadAdminPaiements` lit Supabase avec jointures, KPIs via vue `stats_dashboard`, file d'attente + historique + export CSV. Validation `paymentConfirmValidate` (l.21774) écrit `status='paid'` + audit.
- ⚠️ Ce chemin **ne confirme pas la registration liée** (contrairement à `adminMarkPaymentReceived`, l.28084) → incohérence possible paiement `paid` / inscription `pending`.
- ⚠️ Pas d'upload de **preuve de virement** (seulement date + note libre).

**Actions P08 :** renommer `MOCK_PAYMENTS` ; unifier les 2 chemins de validation (confirmer aussi la registration) ; optionnel : upload preuve.

### Admin sessions (PR-09) — ✅ QUASI COMPLET
Créer (`confirmAddSession` l.27253), lister + remplissage (`loadAdminSessions` l.27396), détail + inscrits + places (`loadAdminSessionDetail` l.27700), cycle de vie complet (confirmer/annuler/restaurer/privatiser), impression liste pilotes.
- ⚠️ Pas d'édition fine post-création (date/capacités/offres → il faut recréer).
- ⚠️ Pas de toggle « publier/dépublier » explicite (publication implicite via `status`/`is_private` + définition de la vue `sessions_public`, à confirmer côté DB).

### Admin documents (PR-10) — ✅ RÉEL
Validation (`adminValidateDoc` l.26509), refus avec motif obligatoire (l.26546), reset (l.26585), recalcul KYC global, consultation fichier. Storage `documents` réellement utilisé.
- ⚠️ Pas de file d'attente centralisée cross-pilotes (validation par pilote uniquement). Mineur.
- ⚠️ Email de notification = placeholder.

### Admin inbox (PR-07) — ❌ ABSENT
La table `contact_messages` reçoit bien contact (l.22611), corporate (l.21338) et founding (l.28936), **mais aucun écran admin ne lit les messages** : les seuls SELECT sont des `count` (compteur founding). Aucune nav « Messagerie », aucun affichage de corps, aucune gestion de statut.

**Actions P07 (tout à construire côté front) :** page « Boîte de réception », `loadAdminInbox()` (`SELECT * ORDER BY created_at DESC` + filtres par source), affichage corps + transitions de statut (`new`→`read`→`replied`/`spam`/`archived`), badge non-lus.

---

## 6. Contenu / SEO / Analytics

### Articles (PR-12) — ✅ RÉEL
Table Supabase `articles` (hydratation l.19991, upsert l.20349, publish l.20223, delete l.20367), seed mémoire de 6 articles en fallback, statut `draft`/`published` fonctionnel.
- ⚠️ **Libellés/commentaires trompeurs** : texte admin « enregistrés dans ce navigateur (localStorage) » (l.17696) et commentaires périmés (l.19742, 20133) alors que c'est en base.
- Newsletter Brevo = log + toast « à brancher » (l.20253).

### Médias (PR-11) — ⚠️ PARTIEL
Table `media` réelle (CRUD + visibilité `visible_to_user`). **Mais `adminSaveMedia` (l.22139) n'insère qu'une URL externe collée à la main** — pas d'upload Storage pour les médias de session (alors que le pattern Storage existe déjà pour véhicules l.23463 et documents l.24010).

### SEO JSON-LD (PR-16) — ⚠️ PARTIEL
- ✅ Présents : `SportsActivityLocation` (l.31), `WebSite` (l.57), `Article` dynamique (l.19701).
- ❌ Manquants : `Organization` (autonome), `Event` (sessions = events datés, fort potentiel), `FAQPage`, `Offer`/`Product` (3 offres tarifées), `BreadcrumbList`.

### Analytics (PR-17) — ❌ ABSENT
Aucun gtag/plausible/posthog/segment, aucune fonction `track`. Les 6 événements cibles (view_offer, click_booking, start_booking, complete_booking, submit_contact, submit_corporate) sont à instrumenter from scratch. Points d'entrée déjà repérés : page tarifs, `bkOpen`/`bkShowStep` (l.21164), `submitContact` (l.22585), `submitCorporate` (l.21304).

---

## 7. Inventaire mocks / qualité (PR-SITE-18)

### Faux modules réellement présentés comme réels (à corriger en priorité)
| # | Ligne | Problème |
|---|---|---|
| 1 | 21276-21285 | `fakeUpload` (B2B) : affiche « Fichier reçu » via `setTimeout`, n'envoie rien |
| 2 | 28008, 28161, 21166 | Emails « queued » : toasts « email envoyé » / « pilotes notifiés » (l.28022, 28123) mentent — aucun envoi réel |
| 3 | 21288-21301 | `submitB2B` : toast succès sans aucun insert |
| 4 | 18425-18427 | RIB virement en placeholders `XXXX` — bloque le paiement réel |

### Libellés / commentaires trompeurs (nettoyage)
| Ligne | Problème |
|---|---|
| 21460 | `MOCK_PAYMENTS` contient de la **vraie** donnée — renommer |
| 17696 | UI « articles dans ce navigateur (localStorage) » → faux, c'est Supabase |
| 22629 | `TODO Supabase : remplacer setTimeout par vrais appels Auth` → périmé (auth déjà migrée) |
| 17347 | commentaire « stub coming-soon » → pages en réalité implémentées |
| 19338 | stub mort `book: #stripe` (`TODO étape 4`) |
| 19742, 20133 | commentaires « localStorage » articles périmés |

### Bénin
- ~35 `setTimeout` : délais UX légitimes (sauf `fakeUpload`).
- 18 `console.log` : diagnostics admin + branding console → nettoyer pour la prod.
- `localStorage` légitimes : token auth (l.19122), consentement cookies (l.28513).
- App mobile « BIENTÔT » (l.19066) : annonce honnête, OK.

---

## 8. Ordre d'attaque recommandé (réconciliation hotfix incluse)

1. **PR-SITE-01** — Porter les 2 commits PII de `hotfix` (calendrier + RPC nom privé) → fermer la fuite. **P0**
2. **PR-SITE-02** — Audit RLS Supabase (via dashboard/MCP). **P0**
3. **PR-SITE-03** — Contact : supprimer le faux succès + `source`. **P0**
4. **PR-SITE-04** — Corporate : metadata structurée + source harmonisée + supprimer `submitB2B`. **P0**
5. **PR-SITE-05** — Edge Functions emails (Resend en secret). **P0**
6. **PR-SITE-06** — Booking : vrai RIB + anti-doublon + enum paiement + référence. **P0**
7. **PR-SITE-07** — Admin inbox (lecture `contact_messages`). **P1**
8. **PR-SITE-08** — Admin paiements : unifier validation. **P1**
9. **PR-SITE-10** — Admin documents : emails de notif. **P1**
10. **PR-SITE-13** — Page App OXV Trace. **P1**
11. **PR-SITE-18** — Nettoyage faux modules / libellés. **P1**
12. **PR-SITE-19** — Découpage `index.html`. **P2**

### Gate avant prod (rappel du plan)
PII publique corrigée · contact & corporate enregistrés · email réservation envoyé · admin voit les demandes · paiement pending visible admin · documents validables · mocks retirés/masqués · pages privées en `robots.txt` · sitemap cohérent · aucun faux succès utilisateur.
