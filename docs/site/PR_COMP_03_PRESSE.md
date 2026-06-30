# PR-COMP-03 — Page Presse & médias + contact journaliste

> Surface : 🌐 site (`index.html` page + footer + sitemap + SEO map + admin inbox). Date : 2026-06-30. **Statut : ✅ livré.**

## 1. Objectif
Donner à la presse un point d'entrée crédible (V2.1 §4) : faits vérifiés, kit média et contact journaliste — sans publier de faux assets.

## 2. Livré
- Nouvelle page publique **`page-presse`** (route `goTo('presse')`) :
  - **« OXV en bref »** — 4 faits vérifiés (lieu, format 20 pilotes, doctrine miroir/silence, donnée UE chiffrée).
  - **« Kit média sur demande »** — logos HD, photothèque, dossier, porte-parole **sur demande via le formulaire** (honnête : aucun lien de téléchargement factice).
  - **Formulaire journaliste** : `submitPress()` → insert réel `contact_messages`, `source='press'`, `metadata { media_outlet, request_type, deadline, details }`, fallback mailto, `track('submit_press')`.
- **Admin inbox** : `press` (label « Presse » déjà présent) + **filtre dédié** ajouté.
- **Footer** : lien « Presse ». **Sitemap** : `/presse`.
- **SEO** : entrées `OXV_PAGE_SEO` pour **presse + securite + partenaires** (titres/descriptions indexables dédiés — securite/partenaires étaient sur le titre par défaut, c'est corrigé).

## 3. Vérification
- page-presse (1), submitPress (def + onclick), 8 ids `pr-*`, refs `press` (filtre + option + payload), **50/50 `<section>`**.
- Routing : `goTo('presse')` fonctionne par toggle d'`id="page-presse"` (pas d'allowlist) ; meta dynamiques via `OXV_PAGE_SEO['presse']`.
- Chemin d'insert identique aux formulaires vérifiés (contact/corporate/waitlist/partenaire).

## 4. Critères d'acceptation
- [x] Page presse avec faits clés + accès kit média + contact journaliste.
- [x] Demandes presse structurées dans l'inbox (média, type, échéance).
- [x] Aucun asset factice ; titres SEO propres.

**Verdict : ✅ PR-COMP-03 livrée.** V2.1 restantes : COMP-09 (Après-journée), COMP-06 (contenu SEO/articles), COMP-05 (Preuves — assets réels), COMP-10 (gate go-live).
