# PR-COMP-06 — Contenu SEO (6 articles à intention de recherche)

> Surface : 🌐 site (`index.html` seed articles + sitemap). Date : 2026-06-30. **Statut : ✅ livré.**

## 1. Objectif
Capter du trafic qualifié (V2.1 §6) via des articles répondant à de vraies intentions de recherche, on-brand, qui convertissent vers les offres / la sécurité / le corporate. L'infra SEO articles existait déjà (JSON-LD `Article` dynamique, title/description/OG/canonical par article) — il manquait le contenu.

## 2. Livré — 6 articles dans `OXV_ARTICLES_SEED`
| id | Intention ciblée | Catégorie | CTA |
|---|---|---|---|
| `premiere-fois-circuit` | première fois sur circuit / débuter | Technique | Access (offers) |
| `equipement-papiers-rouler-circuit` | que faut-il pour rouler sur circuit | Technique | securite |
| `track-day-ou-stage-pilotage` | track day vs stage de pilotage | Technique | offers |
| `progresser-pilotage-telemetrie` | progresser avec la télémétrie | Technique | apres-journee |
| `assurance-circuit-rc-piste` | assurance circuit / RC piste | Technique | securite |
| `journee-circuit-entreprise` | journée circuit entreprise / B2B | Coulisses | corporate |

- Chaque article : 500-700 mots, structure SEO (mot-clé dans title/lead/H2, sections `##`, listes, citation), liens internes en texte, CTA de conversion (`ctaPage`/`ctaLabel`).
- **SEO automatique** (infra existante) : route `/actualites/{id}`, `<title>`/meta/OG/canonical dynamiques, **JSON-LD `Article`** par article. **Sitemap** : 6 URLs ajoutées.

## 3. Cohérence (faits OXV, voix)
- Faits vérifiés : 20 pilotes, offres 390/690/2490 € TTC, télémétrie 25 Hz, tracé Beltoise (Haute Saintonge), doctrine « miroir / silence en roulage / données UE chiffrées / opt-in », documents (permis, RC piste, contrôle technique), Corporate (devis 5 j, délai 3 sem, Standard/Signature).
- **Aucune mention « virement » ni « Stripe »** (aligné sur le paiement par lien). Article assurance : factuel + disclaimer « ne remplace pas un conseil personnalisé ».
- Voix OXV (sobre, premium, vouvoiement, mantra). Catégories `Technique`/`Coulisses` déjà dans `OXV_CATEGORIES` → filtrables.

## 4. Méthode & vérification
- Production prévue en workflow (draft → raffinage adversarial) ; **sous-agents indisponibles (limite de session)** → repli en **rédaction directe** (faits + voix maîtrisés en session).
- Validation **JS réelle** : `node --check` → `PARSE_OK articles=12` ; 24 backticks pairs, 12/12 accolades, ids uniques, 0 `${`. Sitemap +6.

## 5. Critères d'acceptation
- [x] Articles à intention de recherche, on-brand, sans contradiction factuelle.
- [x] SEO complet (JSON-LD Article + meta + sitemap) sans nouvelle infra.
- [x] Chaque article convertit (CTA vers offre/securite/corporate/apres-journee).

## 6. Suivi
- Quand des données de mots-clés réelles seront dispo, prioriser/étendre (ex. modèles éligibles, météo circuit, comparatif offres).
- Itérer le ton avec l'équipe si besoin (les articles restent éditables en base via l'admin).

**Verdict : ✅ PR-COMP-06 livrée.** V2.1 restante : COMP-05 (Preuves — nécessite assets réels).
