# PR-DA-01 — Tokens charte (DA V3 « Premium Racing Minimal »)

> Surface : 🌐 site (`index.html` `:root` + `<head>` polices). Branche : `claude/design-v2`. Date : 2026-07-01. **Statut : ✅ tokens appliqués.** Prod (`main`) intacte.

## Objectif
Poser le socle de la refonte : appliquer la charte DA V3 via les variables CSS (re-skin par couche, pas big bang), sans toucher au fonctionnel (booking/admin/auth/Supabase) ni aux prix/offres.

## Appliqué
**Polices** (Google Fonts) : ajout **Space Grotesk** (titres) + **IBM Plex Mono** (data) ; Inter conservé (corps) ; Syncopate gardé pour compat (`.syncopate`).
- `--display` → `'Space Grotesk', 'Inter Tight', 'Inter'` (était Syncopate)
- `--mono` → `'IBM Plex Mono', 'JetBrains Mono', …` (était JetBrains)

**Palette canonique DA V3** (nouveaux tokens) :
| Token | Hex | Usage |
|---|---|---|
| `--carbon` | `#050505` | fond / hero / sections premium |
| `--anthracite` | `#0B0D10` | cartes, blocs, nav au scroll |
| `--acier` | `#1A1D22` | séparateurs, fonds secondaires |
| `--offwhite` | `#F5F2EA` | titres et textes clairs |
| `--red-oxv` | `#D80F1F` | CTA / marque (jamais fonds massifs / graph data) |
| `--blue-data` | `#4A8CFF` | app / Data Lab / trace (jamais CTA commercial) |
| `--gold-data` | `#C9A24A` | premium rare, valeur data (jamais décoratif) |

**Re-pointage des tokens existants** (le site adopte la charte sans réécrire chaque section) :
- `--cream` `#F8F9FA` → **`#F5F2EA`** (blanc cassé chaud)
- `--night-card` `#121212` → **`#0B0D10`** (anthracite)
- `--oxv-red` `#C8102E` → **`#D80F1F`** (rouge OXV V3 — CTA/badges)
- `--oxv-gold` `#C4A459` → **`#C9A24A`** (or data) · `--oxv-cream` → `#F5F2EA`
- `--carbon` = `--night` (`#050505`, inchangé)

## Préservé (intouchable)
- **Couleurs data-viz QDI** (`--qdi-trajectory/fluidity/braking/acceleration/regularity`, `--blue-tech`, `--green-perf`, `--purple-tech`, `--red`, `--gold`/`--copper`) : encodage fonctionnel des 5 piliers → **non modifiées**.
- Aucune logique JS / route / prix touchée.

## Vérification
- 7 tokens V3 présents ; valeurs appliquées (#D80F1F, #F5F2EA, #0B0D10, #4A8CFF, #C9A24A, Space Grotesk, IBM Plex Mono) ; QDI préservés ; `:root` unique et bien formé.
- Changement de rendu **voulu** (warm off-white, anthracite, rouge OXV plus vif, titres grotesk) — sans régression de structure (layout/contrastes conservés). À valider sur la preview.

## Suite (DA V3, par lots)
PR-DA-02 Navigation premium · DA-03 Hero · DA-04 Home (Avant/Pendant/Après + app + média) · DA-05 Offres · DA-06 App · DA-07 Média · DA-08 Corporate · DA-09 Mobile/perf · DA-10 Motion · DA-11 SEO visuel · DA-12 QA.

**Verdict : ✅ PR-DA-01 livrée** (socle tokens). Re-skin global disponible en preview ; les lots suivants affinent section par section.
