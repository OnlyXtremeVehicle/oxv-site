# PR-COMP-09 — Page « Après votre journée »

> Surface : 🌐 site (`index.html` page + footer + sitemap + SEO map). Date : 2026-06-30. **Statut : ✅ livré.**

## 1. Objectif
Rendre tangible la **valeur post-session** (V2.1 §12) : ce que le pilote emporte après le drapeau à damier. Asset de conversion qui matérialise la promesse « la trace reste ».

## 2. Livré
- Nouvelle page publique **`page-apres-journee`** (route `goTo('apres-journee')`) — **timeline des livrables**, angle distinct de la section App (qui vend les fonctions) :
  - **J+0** premiers médias · **J+2** trace/télémétrie dans l'app · **J+3** bilan de session (miroir, pas de note) · **J+7** rapport Signature (Signature/Heritage) · **Saison** carnet & progression.
- **Cohérence doctrine** : « miroir, jamais un classement », données chiffrées UE jamais revendues, app en opt-in — formulations alignées sur [securite](PR_COMP_02_SECURITE_CADRE.md) et la section App ([PR-SITE-13](PR_SITE_13_APP_SECTION.md)).
- **Cross-links** (pas de duplication) : CTA *Réserver une session* + lien *Sécurité & données*.
- **Footer** : lien « Après la journée ». **Sitemap** : `/apres-journee`. **SEO** : entrée `OXV_PAGE_SEO`.

## 3. Vérification
- page-apres-journee (1), lien footer (1), SEO map (1), sitemap (1), `ctaPrimaryGo` défini, **52/52 `<section>`**.
- Aucune fonction nouvelle (page de contenu) ; réutilise classes `bento`/`btn`/`page-hero` et helpers existants (`ctaPrimaryGo`, `goTo`).

## 4. Critères d'acceptation
- [x] Valeur post-journée matérialisée (timeline J+0 → saison).
- [x] Distincte de la section App, sans contredire la doctrine.
- [x] CTA conversion + cross-link sécurité/données.

**Verdict : ✅ PR-COMP-09 livrée.** V2.1 restantes : COMP-06 (contenu SEO/articles — éditorial), COMP-05 (Preuves — assets réels), COMP-10 (gate go-live).
