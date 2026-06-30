# PR-SITE-13 — Page / section App OXV Trace

> Objectif : promesse app claire et **cohérente avec le produit réel**.
> Surface : 🌐 site (`index.html`). Date : 2026-06-30. **Statut : ✅ livré.** Vérif workflow (2 lentilles) PASS.

## 1. Constat

Le site n'avait **pas de page App** — seulement un teaser dans l'espace pilote (`compte-progression`) avec des claims **faux** contredisant le produit : « Analyse en temps réel », « HUD temps réel », « Ghost LIVE ». Or l'app OXV Trace (vérifiée dans le repo `oxv-app`) est un **miroir post-session**, **silencieux en roulage** (aucun HUD, aucun coaching live).

## 2. Livré

### 2.1 Section publique « OXV Trace » (home)
Nouvelle section `home-app` insérée dans le récit de la home (entre la préparation et la promesse finale), avec :
- **Positionnement exact** : « un miroir, pas un coach » · silence total en roulage · restitution **après** la session.
- **6 features réelles** (depuis le code de l'app) : Pass OXV, Trace du jour, Bilan & Data Lab, Carnet, Passeport & Saison, Coach & IA (post-session, validé humain, **opt-in**, accès RGPD).
- **Note honnête** : capture via boîtier 25 Hz, analyses détaillées dès la 1ʳᵉ session équipée, **sortie printemps 2027**.
- Réutilise les classes existantes (`wrap`, `kicker`, `reveal`, `bento`) + styles inline (aucune CSS manquante ; `.reveal` révélé par l'IntersectionObserver existant comme les autres sections).

### 2.2 Correction du bloc promo pilote
`compte-progression` : claims faux remplacés par la vraie promesse (Trace du jour, Bilan, Data Lab, Carnet/Passeport ; « miroir, pas un coach — silencieuse en roulage »). Plus de « temps réel / HUD / Ghost LIVE ».

## 3. Vérification (workflow, 2 lentilles) — PASS
- **HTML/rendu** : structure home intègre (44 `<section>` équilibrés), classes existantes, vars CSS valides, `.reveal` cohérent, grid responsive (auto-fit minmax 260px). Aucun bug.
- **Exactitude** : 0 claim faux résiduel (sweep complet) ; 6 features correctes ; positionnement miroir/silence/post-session présent ; promo corrigé.

## 4. Suivis identifiés (hors scope PR-13)
- **Mockup « Recommandations Coach IA »** (`compte-progression`, l.~16171-16209) : ton **prescriptif** (« Travaillez… », « Visualisez… ») + scores QDI présentés comme opérationnels → contredit la doctrine « miroir, pas coach » (le vrai produit interdit les verbes directifs via un filtre de sécurité) **et** présente une feature non encore sortie comme active. À reformuler en ton descriptif/observation et/ou marquer « aperçu » → **PR-SITE-18** (mocks) ou une passe doctrine.
- **QDI vs « marge »** : le site parle de « QDI » (indice) ; l'app remplace « limite » par « marge ». Harmoniser le vocabulaire produit (passe éditoriale / V2).
- **Footer « App mobile — prochainement »** (toast) : pourrait pointer vers la section App. Mineur.
- **Numérotation des kickers** de la home incohérente (N°05 puis N°02) — éditorial, sera revu en refonte V2.
- La grande **page App premium** (mise en page léchée) reste prévue en **PR-DESIGN-06** (phase V2) ; PR-13 fournit le contenu exact qui sera restylé.

## 5. Critères d'acceptation
- [x] Promesse app claire et cohérente avec le produit final (miroir, post-session, silence en roulage).
- [x] Features alignées avec l'app réelle (Pass, Trace, Data Lab, Carnet, Passeport, Saison, Coach+IA opt-in).
- [x] Suppression des claims faux (temps réel / HUD / Ghost LIVE).

**Verdict : ✅ PR-SITE-13 livrée.**
