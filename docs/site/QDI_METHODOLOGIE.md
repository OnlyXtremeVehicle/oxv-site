# QDI — Méthodologie de référence (PR-HUB-11)

> Décision fondateur (2026-07-01, Q3) : « on crée un QDI complet sur 5 branches mais il faut être capable de l'assumer. Il sera visionnable par tout le monde au choix du pilote. Utilise de vraies références. »
> Ce document est la base méthodologique **assumable publiquement**. Le calcul effectif vit côté app (`app_session_analyses`, champ `algo_version`) ; toute évolution doit rester cohérente avec ce cadre et incrémenter la version.

## 1. Principe
Le **Quality Driving Index** mesure la **maîtrise**, pas la vitesse. Score 0–100, calculé **après la session** à partir de la télémétrie 25 Hz (GPS + inertiel). Il ne compare jamais deux pilotes entre eux : c'est une lecture personnelle, versionnée, réfutable (données brutes exportables).

## 2. Les 5 branches et leurs fondements

| Branche | Ce qui est mesuré (télémétrie) | Fondement documenté |
|---|---|---|
| **Trajectoire** | Répétabilité de la ligne (dispersion latérale GPS aux points de corde), placement vs référence de virage | La géométrie de la ligne comme premier déterminant du potentiel de virage : Taruffi (1958), ch. lignes ; Segers (2014), analyse position/vitesse en virage |
| **Fluidité** | Régularité des entrées volant et pédales (dérivée des inputs, absence de corrections brusques), transitions latéral↔longitudinal | « Smoothness » mesurable par l'analyse des traces volant/accélérateur : Segers (2014), ch. évaluation du pilote ; Bentley (1998) |
| **Freinage** | Point d'attaque, montée en pression, dégressivité (trail braking), relâche au point de corde — position sur le cercle de friction | Cercle de friction / G-G diagram : Milliken & Milliken (1995) ; exploitation du G-G pour juger le freinage : Segers (2014) |
| **Accélération** | Progressivité de la remise des gaz, continuité longitudinale en sortie, exploitation traction | Même cadre G-G (Milliken & Milliken 1995 ; Segers 2014) — la sortie de virage comme transition sur le cercle de friction |
| **Régularité** | Écart-type des temps au tour (tours valides, hors in/out laps), stabilité des vitesses de passage | La consistance (σ des lap times) comme métrique standard d'évaluation pilote : Segers (2014) |

**Références complètes** :
- W. F. Milliken & D. L. Milliken, *Race Car Vehicle Dynamics*, SAE International, 1995 — dynamique du véhicule, cercle de friction, fondement des branches Freinage/Accélération/Trajectoire.
- J. Segers, *Analysis Techniques for Racecar Data Acquisition*, 2ᵉ éd., SAE International, 2014 — LA référence de l'analyse télémétrique du pilote : G-G diagram, consistance, traces volant/pédales, comparaison de tours.
- R. Bentley, *Speed Secrets: Professional Race Driving Techniques*, 1998 — fluidité, technique de freinage, régularité (vulgarisation professionnelle).
- P. Taruffi, *The Technique of Motor Racing*, 1958 — le classique des trajectoires.

## 3. Garde-fous (non négociables)
1. **Pas de classement** : aucune vue ne trie par score ; l'affichage public est ordonné par récence. La vue `qdi_public` ne porte aucune colonne de rang.
2. **Opt-in pilote** (`users.community_visibility`) : `private` (invisible) · `anonymous_only` (« Pilote OXV ») · `nominative` (nom/handle). Défaut : anonyme.
3. **Anonymat réel** : la vue publique n'expose jamais `user_id` ni email.
4. **Versionné & réfutable** : `algo_version` sur chaque analyse ; données brutes exportables par le pilote ; une évolution de calcul ne réécrit pas l'historique.
5. **Restitution factuelle** : le QDI décrit, il ne prescrit pas — aucune consigne dérivée en roulage.

## 4. Implémenté côté site (2026-07-01)
- Vue **`qdi_public`** (definer, opt-in, anonymisée, testée en anon : 4 pilotes anonymes, données réelles, 0 fuite d'identité).
- **Préférences pilote** : choix Privé / Anonyme / Avec mon nom (écrit `community_visibility`, RLS own-row).
- **Page Plateau** : bloc « Le QDI du plateau » (tri par récence, mention explicite « jamais un classement »).
- **Page Application** : encart public « Méthodologie & références » (cercle de friction, σ des tours, versionnage, les 4 références citées).

## 5. À porter côté app
Publier la correspondance exacte branche → formule dans le repo app (avec `algo_version`), en pointant ce document comme cadre. Toute nouvelle branche ou pondération = incrément de version + note de changement.
