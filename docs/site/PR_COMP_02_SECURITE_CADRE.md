# PR-COMP-02 — Page Sécurité & Cadre

> Surface : 🌐 site (`index.html` nouvelle page + footer + sitemap). Date : 2026-06-30. **Statut : ✅ livré.**

## 1. Objectif
Page de réassurance (V2.1 §3) pour pilotes, proches, circuit, assureurs et entreprises : poser le cadre de sécurité **et** la place exacte de la donnée/app (cohérence avec la doctrine « miroir »).

## 2. Livré
Nouvelle page publique **`page-securite`** (route `goTo('securite')`), pattern page-hero + section :
- **6 principes** (cartes bento) : briefing obligatoire · documents vérifiés (+ contrôle technique véhicule) · **silence total en roulage** (aucun coaching live) · lecture après session (miroir, pas d'ordre) · données protégées (chiffrées, UE, pas d'accès partenaire sans consentement) · pas de compétition sauvage (pas de classement public, 20 pilotes).
- **TrustBlock « Ce qu'OXV ne fera jamais »** (5 engagements : pas de consigne live, pas de classement imposé, pas d'accès télémétrie sans consentement, pas de vente de données, jamais plus de 20 pilotes).
- CTA contact.
- **Footer** : lien « Sécurité & cadre » ajouté (colonne Découvrir). **Sitemap** : `/securite` ajouté (indexable). Pas dans robots Disallow (page publique).

## 3. Cohérence
- Contenu strictement aligné sur la doctrine réelle de l'app (silence en roulage, miroir/post-session, données UE, opt-in) — mêmes formulations que la section App (PR-13).
- Réutilise classes existantes (page-hero, bento, kicker, section-title, cal-cta-block, btn) + styles inline (aucune CSS manquante).
- Structure vérifiée : 1 `page-securite`, 46/46 `<section>` équilibrés, lien footer + sitemap OK.

## 4. Critères d'acceptation
- [x] Page de réassurance couvrant briefing, documents, silence en roulage, observation post-session, données protégées, absence de classement, respect règlement.

**Verdict : ✅ PR-COMP-02 livrée.** Restantes V2.1 site-only : COMP-04 (Partenaires + form), COMP-05 (Preuves — besoin d'assets réels), COMP-09 (Après-journée), COMP-03 (Presse), COMP-06 (contenu SEO), COMP-07 (CRM statuts).
