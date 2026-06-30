# PR-SITE-16 — SEO enrichi (JSON-LD) + cohérence robots/sitemap

> Surface : 🌐 site (`index.html` `<head>`, `robots.txt`). Date : 2026-06-30. **Statut : ✅ livré** (6/6 JSON-LD valides).

## 1. JSON-LD ajoutés
Le `<head>` avait déjà `SportsActivityLocation` + `WebSite`. Ajoutés :
- **Organization** (nœud autonome) : name, url, logo, email, contactPoint.
- **Product** « OXV — Track day » avec **3 Offers** (Access 390 €, Signature 690 €, Heritage 2 490 €, `priceCurrency` EUR, `availability` InStock).
- **FAQPage** : les **6 questions** de la FAQ (PR-15) — texte des réponses aligné sur le contenu visible (exigence Google). Active les *rich results* FAQ.
- **BreadcrumbList** : Accueil → Les offres.

Validation : les **6 blocs `application/ld+json` parsent sans erreur** (vérifié par parse JSON).

## 2. robots.txt / sitemap
- robots : ajout des routes admin manquantes **`/admin-inbox`** (créée en PR-07) et **`/admin-demandes`** au `Disallow` → aucune page privée indexable.
- Cohérence vérifiée : le `sitemap.xml` ne liste que des pages publiques (accueil, offers, calendrier, circuit, corporate, about, actualités + articles, contact, booking, légales, specs) ; aucune route `Disallow` n'y figure. ✅

## 3. Suivi — Event (dynamique)
Le plan liste aussi **Event** (sessions). Non ajouté en statique : les sessions sont **dynamiques** (`sessions_public`) et un Event JSON-LD figé serait faux/vide. Le faire correctement nécessite une injection avec les vraies dates — idéalement via **SSR** ou un **sitemap d'événements** généré, plutôt qu'une injection client-side (faiblement indexée). À traiter quand l'archi le permettra (lié à PR-19/20). Le modèle `Article` est déjà injecté dynamiquement sur les pages article (existant).

## 4. Résolution de la contradiction d'annulation (suite PR-14/15)
Décision : les **CGV font foi** → barème **> 7 j : remboursement intégral · < 7 j : aucun**. Aligné dans le code :
- `cancelRegistration` (confirm dialog) : barème « J-14/50%/10% » → **CGV 7 j**.
- Texte « Mes sessions » (« jusqu'à J-14 intégral ») → **CGV 7 j**.
La FAQ (PR-15), la checkbox de réservation et les CGV art.4 étaient déjà sur le barème 7 j. Plus aucune divergence.

## 5. Critères d'acceptation
- [x] Métadonnées valides (Organization, Offer, FAQPage, BreadcrumbList ajoutés ; 6/6 JSON-LD valides).
- [x] sitemap/robots cohérents (routes privées exclues, sitemap = public).
- [~] Event : à injecter dynamiquement (suivi, dépend archi SSR/sitemap events).

**Verdict : ✅ PR-SITE-16 livrée** (Event en suivi).
