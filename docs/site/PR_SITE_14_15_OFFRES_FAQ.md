# PR-SITE-14 (Offres claires) + PR-SITE-15 (FAQ conversion)

> Surface : 🌐 site (`index.html`, page Offres). Date : 2026-06-30. **Statut : ✅ livré** (revue OK).

## PR-14 — Offres claires

La page Offres était déjà solide (3 cartes Access/Signature/Heritage avec format, capacité, inclus, « pour qui », prix, CTA + comparateur + « Comment ça marche »). Ajouts pour compléter les critères :
- **« Non inclus dans toutes les offres »** : encart explicite (véhicule, équipement pilote homologué, assurance dommages de votre véhicule ; RC organisateur **incluse**) → fixe les attentes, réduit les frictions.
- **Corporate** : callout dédié (4ᵉ piste) avec CTA vers la page `corporate` — le visiteur voit désormais les 4 options (Access, Signature, Heritage, Corporate).
- **Cohérence doctrine** : Heritage « Coaching IA **pré-session** » → « Débrief IA **post-session** (opt-in) » (l'app est post-session, jamais en live).

## PR-15 — FAQ conversion

Section **FAQ** ajoutée à la page Offres (réutilise le style existant `.founding-faq`), 6 freins clients levés :
niveau requis · voiture admise · assurance · données · paiement · annulation.
- Contenu **crawlable** (vrai HTML, indexable). Le `FAQPage` JSON-LD (rich results) sera ajouté en **PR-SITE-16** (SEO).
- Aligné sur la doctrine (« miroir, pas une compétition ») et sur les CGV.

## Revue (agent dédié) — OK
- HTML/structure : blocs bien formés et bien placés (encart + corporate après la grille, avant le comparateur ; FAQ après « Comment ça marche », dans la section). 44/44 `<section>` équilibrés. Page se ferme proprement.
- Classes `.founding-faq*` définies en CSS ✅ ; CTA Corporate → `goTo('corporate')` cible `#page-corporate` ✅.
- Aucun claim faux, doctrine respectée.

## 🔴 Contradiction préexistante détectée (décision métier requise — HORS scope PR-14/15)

Le site contient **deux politiques d'annulation incompatibles** :
| Source | Barème |
|---|---|
| **CGV art. 4** (l.~18770) + checkbox réservation (l.~18644) + **cette FAQ** | > 7 j : remboursement **intégral** · < 7 j : **aucun** remboursement · annulation OXV : intégral/report |
| « Mes sessions » (l.~15704) + **logique `cancelRegistration`** (l.~24726) | **J-14** : intégral · **J-14→J-7 : 50 %** · **< J-7 : 10 %** |

→ Le **code de remboursement** (`cancelRegistration`) **contredit les CGV**. Exemple : à J-10, la FAQ/CGV promettent un remboursement intégral, mais le code n'en verse que 50 %. C'est un risque **juridique/commercial** (le contrat fait foi).

Ma FAQ suit fidèlement les **CGV** (le document contractuel). **À arbitrer par toi** : soit corriger `cancelRegistration` + le texte « Mes sessions » pour honorer les CGV (7 j), soit mettre à jour CGV + FAQ vers le barème à paliers (J-14/50%/10%). **Je n'ai pas tranché seul** (décision métier). À traiter dans une PR dédiée.

## Critères d'acceptation
- [x] PR-14 : un visiteur comprend Access, Signature, Heritage **et Corporate** (pour qui, format, inclus, **non inclus**, prix, CTA).
- [x] PR-15 : FAQ qui lève les freins, indexable (HTML crawlable ; JSON-LD en PR-16).

**Verdict : ✅ PR-14 + PR-15 livrées.** ⚠️ Contradiction barème annulation à arbitrer (séparément).
