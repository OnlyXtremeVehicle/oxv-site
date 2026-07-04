# PR-DESIGN-01 — Fondations : audit du système de design

> Surface : 🌐 site (`index.html`, `:root`). Branche : `claude/design-v2`. Date : 2026-07-01. **Statut : audit livré ; refonte visuelle en attente de la DA V2.**

## Contexte
La fiabilisation V1 + V2.1 est **en production** (`main` déployé sur oxvehicle.fr). La phase 5 (Design V2, DESIGN-01→12) démarre sur une branche dédiée `claude/design-v2` (prod stable, refonte isolée).

## Système de tokens actuel (DA « Executive Dashboard »)
**Couleurs**
- Fonds : `--night #050505`, `--night-deep #000`, `--night-soft #0E0E0E`, `--night-card #121212`
- Textes : `--cream #F8F9FA`, `--cream-soft`, `--cream-mute #A1A1AA`, `--cream-faint`, lignes `--cream-line`/`--cream-edge`
- Or / perf : `--copper #FFB703`, `--copper-glow #FFC93C`, `--copper-deep #C68B00`, `--gold #FFB703`
- Rouge : `--red #E63946`
- Marque : `--oxv-red #C8102E`, `--oxv-gold #C4A459`, `--oxv-night #0A0A0A`, `--oxv-cream #F8F9FA`

**Typographie** : `--sans` Inter · `--display` Syncopate (titres/chiffres) · `--mono` JetBrains Mono · `--serif` Georgia (mappé).

## Incohérences à rationaliser (refonte)
1. **`--gold` == `--copper` == `#FFB703`** (doublon) — un seul or à conserver, idéalement aligné sur l'or marque `--oxv-gold #C4A459` (Heritage) vs l'or « perf » jaune. Clarifier : or marque vs accent data.
2. **Deux rouges** : `--red #E63946` (adrénaline) vs `--oxv-red #C8102E` (insigne). Décider lequel est canonique (le rouge insigne `#C8102E` est la couleur de marque).
3. **`--serif` = Georgia** mais commentaire indique un mapping historique ; la DA mélange Syncopate (display) et sans. Clarifier le rôle du serif (probablement à retirer).
4. **Échelles spacing / radius / shadow** non tokenisées (valeurs en dur dans le CSS) → à extraire en tokens pour cohérence et passage mobile/motion.

## Plan de la phase Design (DESIGN-01→12)
| Lot | Objet |
|---|---|
| **01** | Fondations : tokens (couleurs/typo/espacements/rayons/ombres), nettoyage doublons — *ce doc* |
| 02 | Hero home + identité premium |
| 03 | Sections home (offres, data, circuit, app…) |
| 04 | Pages offres / pricing premium |
| 05 | Pages App / Média |
| 06 | Pages contenu (about, circuit, sécurité, preuves…) |
| 07 | Composants (boutons, cartes bento, formulaires) |
| 08 | Mobile / responsive |
| 09 | Motion / micro-interactions |
| 10 | SEO visuel (OG, favicons, images) |
| 11 | Accessibilité / contrastes |
| 12 | QA visuelle transverse |

## Prérequis bloquant pour DESIGN-02+
La refonte visuelle est **pilotée par la DA V2** (`Refonte_Esthetique_Premium_V2.docx`). Avant de toucher au rendu, il faut **la direction artistique** : palette cible, références, ton visuel, ce qui change vs l'actuel. Sans elle, DESIGN-01 se limite à l'audit + la consolidation non-destructive des tokens.

**Verdict : ✅ audit DESIGN-01 livré.** En attente de la DA V2 pour engager les lots visuels.
