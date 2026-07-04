# PR-HUB-06 — Partenaires : annuaire, espace léger, pipeline

> Surface : 🌐 site. Date : 2026-07-01. **Statut : ✅ livrée.** Zéro migration — branché sur l'écosystème app existant (`partners`, `partner_leads`, `partner_accounts`), même réflexe que HUB-05.

## 1. Audit préalable
L'app a déjà : **`partners`** (annuaire publiable : nom, type, logo, ville, url, `is_published`/`is_premium`/`is_official_partner`, **`owner_id`**), **`partner_leads`** (contacts pilotes→partenaire avec consentement), `partner_offers`, `partner_accounts`. RLS complète : annuaire publié lisible par tous, le partenaire gère SA fiche (`owner_id`), leads protégés, admin tout. 0 fiche publiée aujourd'hui → états vides honnêtes.

## 2. Livré
- **Annuaire public** (page Partenaires) : fiches publiées (logo, type, ville, badge officiel/premium, lien site) — la section n'apparaît que s'il y a des fiches. Preuve d'écosystème au service de la page « vendeuse » (COMP-04).
- **Espace partenaire** (`/partenaire-espace`, noindex) : réservé aux comptes propriétaires d'une fiche (`owner_id`) — garde honnête sinon. Contenu : **ma fiche** (statut publication/premium), **contacts reçus** (RLS : uniquement les siens, consentis), **kit de marque** (insigne SVG + visuel, règles d'usage), **prochaines sessions publiques** (`sessions_public`). Mention explicite : *jamais d'accès aux médias privés des pilotes* + stats détaillées « après le lancement » (honnête).
- **Admin** : bloc « Partenaires signés » sur le tableau de bord (statut publié/brouillon/premium, compte lié ou non) + lien direct vers les **prospects** (inbox CRM, pipeline COMP-07 : lead → … → gagné). Prospect→signé = création de la fiche `partners` (app ou admin).
- Entrée « Déjà partenaire ? Mon espace » sur la page publique.

## 3. Vérifications
- RLS réutilisées (aucune nouvelle policy nécessaire) ; garde espace = possession d'une fiche, pas le rôle seul.
- 54 pages, 0 nav cassée, 64/64 sections, noindex OK, `node --check` OK.

## 4. Critères d'acceptation
- [x] Page publique vendeuse + annuaire réel (preuves d'écosystème).
- [x] Espace partenaire léger : kit marque, calendrier public, contacts — jamais les médias privés clients.
- [x] Pipeline admin : prospects via inbox CRM, signés via `partners`.
