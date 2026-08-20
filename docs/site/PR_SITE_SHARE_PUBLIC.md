# PR-SITE — Page de partage publique `/share/{jeton}` (chantier 1)

> Surface : 🌐 site (`index.html`, `robots.txt`, `vercel.json`). Date : 2026-08-01.
> **Statut : ✅ livrée et vérifiée en local sur données réelles. Aucune migration.**

## 1. Ce qui manquait, et rien d'autre

L'app pose déjà le lien (`src/services/sharesService.ts:58` → `oxvehicle.fr/share/<jeton>`).
La couche serveur existait déjà en production : **trois fonctions `security definer`
accordées à `anon`**, dont `share_public_view(p_token text) → jsonb`, celle qui est
utilisée ici. Il manquait uniquement **la page**. Zéro occurrence de `/share` dans
`index.html` avant cette PR ; zéro migration écrite pour elle.

## 2. Contrat, revérifié en réel le 2026-08-01

Appel unique, clé **anon**, via PostgREST :
`POST /rest/v1/rpc/share_public_view` avec `{ "p_token": "<jeton>" }`.

La fonction valide (longueur 16–128, non révoqué, non expiré), filtre sur
`included_metrics`, compte la consultation (`view_count`, `last_viewed_at`) et ne
rend jamais `user_id` ni la ligne de partage.

| Cas | Réponse observée (HTTP 200) |
|---|---|
| jeton court / inconnu / révoqué / expiré | `{"status":"inactive"}` — forme unique |
| jeton actif | `{"status":"active","scope","metrics","session_count","expires_at"}` |

Mesuré via la clé anon sur un lien actif temporaire :
`{"status":"active","scope":"last_5_sessions","metrics":{"best_lap":null,"lap_count":1,"regularity":null,"progression":null,"signature":null},"session_count":5,"expires_at":"…"}`

## 3. Les trois règles, telles qu'implémentées

1. **N'afficher que les métriques présentes** — `Object.hasOwnProperty` sur `metrics`.
   Une clé absente n'existe pas pour la page ; une clé présente à `null` s'affiche « — ».
   `signature` est **exclue de la liste d'affichage** : la fonction rend toujours `null`
   (calcul non implémenté), on n'affiche pas une case vide pour une mesure inexistante.
2. **Refuser sans culpabiliser** — « Ce lien n'est plus actif. » + « Aucune donnée n'est
   consultable à cette adresse. » Pas de durée, pas de motif, pas de bouton.
3. **Aucune donnée d'un autre pilote** — la page ne lit aucune table, seulement la RPC.
   Aucune comparaison, aucune moyenne de plateau, aucun rang.

**Une panne réseau n'est pas un lien mort.** Une erreur de transport affiche « Lien
momentanément illisible », jamais le refus — le dire serait faux.

## 4. Libellés (mesures, pas jugements)

| Clé | Libellé | Format | Précision affichée |
|---|---|---|---|
| `best_lap` | Meilleur tour | `m:ss.mmm` (`oxvFmtLap`) | sessions retenues |
| `lap_count` | Tours bouclés | entier | total des sessions retenues |
| `regularity` | Régularité | `0,412 s` | écart-type des meilleurs tours |
| `progression` | Évolution du meilleur tour | `−1,234 s` / `+0,870 s` | dernier meilleur tour comparé au premier |

Le signe de l'évolution est **une mesure, pas un verdict** : aucun « gagné », aucun
« amélioré ». Signe moins typographique (U+2212). Sous le tableau, mention fixe :
« Mesures issues de la télémétrie enregistrée pendant les sessions du pilote,
restituées telles quelles. Aucune comparaison avec d'autres pilotes. »

Portées : `last_session` → Dernière session · `last_5_sessions` → Cinq dernières
sessions · `full_history` → Historique complet · `progression_only` → Évolution seule.
**Une portée inconnue est omise, jamais devinée.**

## 5. Confidentialité

- `share` ajouté à `OXV_NOINDEX_PAGES` → `<meta name="robots" content="noindex, nofollow">`.
- `robots.txt` : `Disallow: /share/`.
- `vercel.json` : `X-Robots-Tag: noindex, nofollow` **et `Referrer-Policy: no-referrer`**
  sur `/share/:token*` — un jeton dans l'URL ne doit pas fuir par l'en-tête `Referer`.
  *(En-têtes non vérifiés en déploiement : la règle n'existe pas encore en production.)*
- Le canonical de la page est `/share` **sans le jeton** (vérifié : `https://www.oxvehicle.fr/share`).
- Titre de l'onglet volontairement muet : « Lien de partage · OXV ».

## 6. Vérifications faites (local, serveur imitant le rewrite Vercel)

| Cas | Résultat |
|---|---|
| Lien actif, 5 métriques cochées | 4 cartes (`signature` absente), nulls en « — », `lap_count` = 1 |
| Lien actif, **1 seule** métrique cochée (`regularity`) | 1 carte, rien d'autre |
| Lien actif, portée `progression_only` | « Aucune mesure n'est partagée par ce lien. » + « Aucune session retenue à ce jour. » |
| **Le lien réel de la base, expiré le 14/07/2026** | « Ce lien n'est plus actif. » |
| `/share` sans jeton | même refus (jamais la home) |
| Jeton mal formé (`zzzz`), clé anon en HTTPS réel | `{"status":"inactive"}` |
| Console au chargement | 0 erreur |
| `node --check` du module applicatif | OK |
| `meta robots` / canonical | `noindex, nofollow` / `/share` sans jeton |

**Non vérifié** : le rendu d'une métrique **non nulle** autre que `lap_count`.
`telemetry_sessions.best_lap_seconds` est NULL sur les 18 captures existantes
(10 `completed`, `sum(lap_count)` = 1) — aucune donnée réelle ne permet de l'observer.
Les formateurs ont donc été vérifiés unitairement hors page (`1:42.318`, `0,412 s`,
`−1,234 s`, `+0,870 s`). Aucune capture d'écran : le panneau navigateur n'était pas
affiché — les vérifications ci-dessus portent sur le DOM rendu, pas sur des pixels.

**Ligne de test** : un partage temporaire (`QAOXVSHARETEST…`) a été créé puis
**supprimé**. La table est revenue à sa ligne unique d'origine, `view_count` = 0 et
`last_viewed_at` = null — les consultations du lien expiré n'ont rien incrémenté
(la fonction rend `inactive` avant le comptage, comportement confirmé).

## 7. Reste

- `signature` : à afficher le jour où la fonction la calcule (ajouter l'entrée dans
  `OXV_SHARE_METRICS`, rien d'autre).
- Aperçu de lien (OG) : le crawler lit le `<head>` statique, pas les meta réécrites en
  JS. L'aperçu est donc générique — ce qui, pour un lien de partage, est souhaitable.
