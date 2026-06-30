# PR-COMP-05 — Page Preuves & garanties

> Surface : 🌐 site (`index.html` page + footer + sitemap + SEO map). Date : 2026-06-30. **Statut : ✅ livré (version honnête, sans fabrication).**

## 1. Objectif
Dernière page V2.1 site-only (V2.1 §… « Preuves »). Donner au prospect un point unique de **réassurance avant réservation** — « pourquoi faire confiance à OXV ». Contrainte : **aucun faux témoignage / fausse photo / faux chiffre** (même exigence que le retrait du faux RIB).

## 2. Parti pris — preuves vérifiables, pas de fabrication
N'ayant pas encore de retours clients (1ʳᵉ saison 2027), la page s'appuie sur ce qui est **réel et vérifiable aujourd'hui**, et annonce honnêtement les témoignages à venir :
- **6 preuves concrètes** (bento) : circuit Beltoise réel (→ circuit), cadre de sécurité opposable (→ securite), données chiffrées UE/opt-in, conditions claires (→ cgv), écosystème transparent (→ partenaires/presse), livrables réels (→ apres-journee). Cross-links plutôt que duplication.
- **« Ce qu'OXV ne fera jamais »** (5 engagements : pas de consigne live, pas de classement, pas d'accès télémétrie sans consentement, pas de revente, jamais +20).
- **« Ce qu'en diront les pilotes »** : emplacement témoignages **explicitement marqué « réels, jamais inventés », publiés avec la saison 2027** + CTA réserver / contact. **Aucun verbatim factice.**

## 3. Livré
- Page publique **`page-preuves`** (route `goTo('preuves')`), pattern page-hero + section, classes existantes (`bento`, `link-inline`, `btn`, `ctaPrimaryGo`).
- **Footer** : lien « Preuves & garanties ». **Sitemap** : `/preuves`. **SEO** : entrée `OXV_PAGE_SEO['preuves']` (title/description dédiés).

## 4. Vérification
- `page-preuves` (1), lien footer (1), SEO map (1), sitemap (1), **54/54 `<section>`**, **navigation : 0 lien cassé**.
- Aucune nouvelle fonction JS (page de contenu) ; CTAs sur helpers existants.

## 5. Critères d'acceptation
- [x] Page de réassurance / preuves distincte, conversion-framed.
- [x] Contenu 100 % vérifiable ; aucun témoignage/asset fabriqué.
- [x] Emplacement témoignages prêt à recevoir des retours réels (saison 2027).

## 6. Suivi
- Brancher de **vrais témoignages + photos** dès qu'ils existent (assets utilisateur) — la structure est prête.

**Verdict : ✅ PR-COMP-05 livrée. Le programme V2.1 site-only est complet** (COMP-01→10). Restent hors site : design V2 (reporté), inputs utilisateur (SIRET, assets, PSP), migration app (A1).
