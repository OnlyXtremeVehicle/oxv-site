# ADDENDUM 02 — LOT ÉCRANS PAVILLON

**S'ajoute au prompt principal et à l'Addendum 01. En cas de conflit, le document le plus récent prime. Arbitrages verrouillés par M. Fillat le 18/07/2026 : A9, A11, A12, A13 (requalifié). A10 (drapeaux) NON tranché — hors périmètre, ne rien implémenter.**

---

## 1. A9 — Mode `multi` de l'écran coach

**Quatrième référence visuelle : `references/tv-coach-multi.html`.** La route `/pavillon/coach` compte désormais quatre modes : `idle` · `live` · `restitution` · `multi`.

**Contrat temps réel v2 — nouveau message canal 2 :**
```json
{ "v": 2, "action": "multi", "telemetry_session_ids": ["uuid", "..."], "ts": "…" }
```
Les récepteurs acceptent `v: 1` ET `v: 2` (le v2 ajoute, ne casse rien). L'émetteur (tablette, lot app) émettra en v2.

**Règles verrouillées (doctrine — bloquantes en QA) :**
- 2 à 4 tuiles. Chaque `telemetry_session_id` est vérifié contre `coach_pilots` du coach connecté ; toute session étrangère est écartée silencieusement (warn console).
- **Tri par `car_number` croissant, jamais par chrono.** Le tri est codé une seule fois, commenté `// DOCTRINE: tri par numéro — ne jamais trier par temps`.
- Aucune colonne partagée de temps entre tuiles, aucun alignement visuel des chronos, aucun cumul. Chaque tuile : tour en cours, dernier tour, écart **à sa propre référence**, réf. personnelle.
- Emplacements restants → tuile « Emplacement libre » avec prochain créneau de la file du coach.
- Positions live : le canal 1 alimente toutes les tuiles (filtrage par `user_id`).
- À 2 pilotes : grille 2×1 pleine hauteur ; à 3–4 : grille 2×2 (référence).

## 2. A11 — Prochaines sessions (écran accueil)

Dans la colonne latérale de `/pavillon/accueil`, le bloc **Planning du jour** alterne avec un bloc **Prochaines sessions** — cycle de 45 s, transition fondu 400 ms.

- Source : `sessions` à venir (`date > CURRENT_DATE`, statut ouvert — vérifier la colonne de statut réelle), limite 3, ordre chronologique.
- Contenu par ligne : date (format « Jeu. 22 Oct. »), format de session (libellé de l'offre : Access / Signature), places restantes (`max_capacity − count(bookings)` — vérifier la table de réservation réelle avant d'implémenter ; si incertaine, afficher la date et le format sans les places et taguer `TODO_ARBITRAGE: source places restantes`).
- **Aucun prix affiché.**
- État `veille` : le bloc Prochaines sessions est intégré à l'écran de veille (sous la prochaine ouverture).

## 3. A12 — Pagination de la liste « En piste » (écran accueil)

- Pages de 8 pilotes, rotation automatique toutes les 10 s, indicateur discret « 1/3 » en JetBrains Mono 10px à droite du titre du bloc.
- Ordre par `car_number` croissant, stable entre rotations.
- ≤ 8 pilotes : aucun indicateur, aucune rotation.

## 4. A13 (requalifié) — Bande photo prédéfinie + espace admin

**Principe :** les photos diffusées sur l'écran accueil sont exclusivement celles curatées à l'avance dans l'espace admin du site. `session_media` n'est jamais lu par les écrans Pavillon.

**Migration : `migrations/20260718_pavillon_photos.sql`** (table `pavillon_photos` + bucket privé `pavillon-photos`, URLs signées 24 h).

**Diffusion (écran accueil) :**
- État `veille` : carrousel plein écran des photos actives (ordre `sort_order`), fondu 1,2 s toutes les 8 s, insigne + manifeste + horloge en surimpression (composition de l'Addendum 01 conservée par-dessus).
- État `pause` / `fermee` : bande photo en pied de colonne latérale (une photo à la fois, mêmes transitions), le reste de l'écran inchangé.
- État `ouverte` : **aucune photo** — l'écran est opérationnel.
- Table vide ou bucket inaccessible : les états retombent sur leur version sans photo (Addendum 01), sans erreur visible.

**Espace admin (nouvelle route `/pavillon/admin`) :**
- Garde : compte staff (même mécanisme de rôle que la garde coach — vérifier `users.role` / table staff réelle ; policy d'écriture de la migration volontairement fermée tant que `TODO_ARBITRAGE: rôle staff` n'est pas tranché).
- Fonctions minimales : téléversement (jpg/webp, 5 Mo max, compression client à 1920px de large avant upload), liste des photos avec vignettes, activation/désactivation, réordonnancement (boutons monter/descendre — pas de drag&drop, sobriété du code), légende optionnelle, suppression avec confirmation.
- Identité visuelle : mêmes tokens, formulaire minimal. Cette route est un outil, pas une vitrine — aucune sur-conception.
- Hors navigation publique et sitemap, comme les autres routes Pavillon.

## 5. QA supplémentaire (s'ajoute aux blocs §7 du prompt et Addendum 01)

- [ ] Mode multi : injection d'un `telemetry_session_id` étranger → tuile absente, warn, écran stable.
- [ ] Mode multi : vérification par revue que le tri est `car_number` et qu'aucun sélecteur CSS n'aligne les chronos entre tuiles (pas de grid commune des valeurs).
- [ ] Alternance Planning/Prochaines sessions : aucun saut de layout (les deux blocs ont la même hauteur réservée).
- [ ] Pagination En piste : 20 pilotes factices en `?demo=1` → 3 pages, cycle correct.
- [ ] Carrousel veille : 0 photo → veille Addendum 01 ; 1 photo → statique sans transition ; URLs signées renouvelées avant expiration (re-signature à 23 h de vie).
- [ ] Admin : upload d'un PNG de 12 Mo → refus propre avec message ; compte pilote sur `/pavillon/admin` → redirection.
- [ ] `?demo=1&mode=multi` disponible.
- [ ] Greps doctrine étendus aux nouveaux fichiers ; grep supplémentaire : `session_media` doit être ABSENT du code Pavillon.
