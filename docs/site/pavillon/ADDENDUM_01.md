# ADDENDUM 01 — LOT ÉCRANS PAVILLON

**S'ajoute à `PROMPT_CLAUDE_CODE_ECRANS_PAVILLON.md`. En cas de conflit, cet addendum prime (plus récent).**

## 1. Troisième référence visuelle

`references/tv-coach-restitution.html` — **second état de la route `/pavillon/coach`** (session terminée). La route coach a donc trois modes, pilotés par le canal de contrôle :

| Mode | Référence | Déclencheur |
|---|---|---|
| `idle` | écran neutre (insigne + « Stand Coach · Espace réservé » + horloge, mêmes tokens) | défaut au chargement, ou message `idle` |
| `live` | `tv-coach.html` | message `follow_pilot` |
| `restitution` | `tv-coach-restitution.html` | message `show_restitution` |

Données du mode restitution (sources identiques au §5.1 du prompt principal, session terminée) :
- Bilan : `laps` agrégés (count, min, médiane) + `telemetry_sessions.distance_km`.
- Comparaison **Session N vs Session N−1** : la session précédente `completed` du même pilote sur le même circuit. S'il n'y en a pas : colonne S.précédente remplacée par « Première session » et écarts masqués. La note de conditions (« sec / sec ») provient de `weather` des deux sessions ; si conditions différentes, l'afficher tel quel (« sec / pluie ») — c'est un fait, pas un jugement.
- Dispersion : tous les `duration_seconds` de la session, marques individuelles des tours sur la bande.
- Annotations : les 3 dernières de la session (ordre antéchronologique).
- Bloc « Prochain créneau » : premier pilote « À venir » de la file du coach.
- Mention fixe : « Restitution complète disponible sur l'application — Espace Pilote. »

## 2. Contrat temps réel

`CONTRAT_TEMPS_REEL_PAVILLON.md` remplace et précise le §5.2 du prompt principal. Il est **normatif** : schémas de messages, cadences, TTL, modes d'écran accueil (`ouverte`/`pause`/`fermee`/`veille`), dérivation d'état de repli, validations et tests de contrat (§Tests). Implémentez côté réception l'intégralité de la colonne « Lot site » du récapitulatif final.

L'état `veille` de l'écran accueil (écran épuré : insigne centré, manifeste, horloge, prochaine ouverture) ne dispose pas de maquette dédiée — construisez-le avec les tokens existants ; c'est une composition de trois éléments déjà présents dans `tv-accueil.html`.

## 3. QA supplémentaire

- [ ] Les 6 cas de test du contrat (§Tests) passent côté réception.
- [ ] Bascule live → restitution → idle sans fuite d'abonnement (vérifier le nombre de listeners après 20 bascules : constant).
- [ ] Mode restitution avec pilote sans session précédente → « Première session », pas de NaN.
- [ ] `?demo=1` couvre les trois modes coach (paramètre `&mode=live|restitution|idle`) et les quatre états accueil (`&etat=ouverte|pause|fermee|veille`).
- [ ] Grep doctrine étendu au nouveau fichier (mêmes commandes §7.6).
