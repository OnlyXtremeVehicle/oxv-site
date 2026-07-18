# PROMPT CLAUDE CODE — LOT ÉCRANS PAVILLON (SITE WEB)

**Projet :** oxvehicle.fr — repo `OnlyXtremeVehicle/oxv-site` (SPA vanilla JS mono-fichier `index.html`, Vercel)
**Backend :** Supabase — projet `fouvuqkdxarjpjbqnsjq` (Frankfurt)
**Date du prompt :** 17 juillet 2026
**Références visuelles :** `references/tv-accueil.html` · `references/tv-coach.html`
**Migration associée :** `migrations/20260717_pavillon_vues.sql`
**Dépendance :** migration `20260717_profil_pavillon.sql` (lot PROFIL_CARTES) appliquée au préalable.

---

## 0. RÈGLES ABSOLUES

1. **Lisez `CLAUDE.md` à la racine du repo avant toute modification.** Ses règles permanentes priment en cas de conflit avec ce prompt — signalez alors le conflit et arrêtez-vous.
2. **Les fichiers de `references/` sont la spécification visuelle exacte.** Le CSS de référence est réutilisable quasi tel quel (même cible : navigateur). Transposez les valeurs, ne réinterprétez pas.
3. **Doctrine Miroir + arbitrages verrouillés :**
   - **A7 (écran accueil, PUBLIC)** : identités pseudonymisées (N° voiture + pseudo). Nom affiché — prénom + initiale seulement — uniquement si `pavilion_name_optin = true`. **AUCUN chrono, AUCUN classement, AUCUNE donnée QDI** sur cet écran.
   - **Écran coach (RÉSERVÉ)** : chronos du pilote suivi (self vs self), QDI **en axes, jamais de score composite**, annotations coach en bande séparée sous le tracé.
   - Couleurs QDI = couleurs de **données** uniquement (traits, points, segments) — jamais de fonds, jamais hors contexte QDI.
4. **La pseudonymisation est serveur** (vues SQL de la migration), jamais un filtre côté client. Le navigateur de l'écran accueil ne doit jamais recevoir un nom complet non opt-in, même dans une réponse réseau.
5. **Aucun refactoring hors périmètre. Un lot = un commit. Greps avant push (§8).**
6. **Vous n'exécutez pas les migrations.** Code avec repli propre si vues absentes (message « Configuration Pavillon incomplète », pas de crash).

---

## 1. PÉRIMÈTRE

**Inclus :**
- Route **`/pavillon/accueil`** — écran public 1920×1080 (réf. `tv-accueil.html`).
- Route **`/pavillon/coach`** — écran réservé 1920×1080 (réf. `tv-coach.html`).
- Intégration au routeur existant de la SPA (grep le mécanisme de routes dans `index.html` — hash ou history — et suivez-le ; ne créez pas de second routeur).
- Abonnements Supabase Realtime (§5), requêtes, états vides/erreur/reconnexion.
- Garde d'accès des deux routes (§4).

**Exclus :**
- La publication des positions live côté app mobile (§5.2 — dépendance externe, mode démo fourni en attendant).
- Le calcul du QDI (contrat défini, pipeline hors lot).
- Toute modification des écrans app (lot PROFIL_CARTES).
- Tout contenu marketing du site.

---

## 2. IDENTITÉ VISUELLE — TOKENS

Identiques au lot précédent : `#0A0A0A` fond · `#FFFFFF` texte · `#C8102E` accents · surfaces `#121212`/`#1A1A1A` · lignes `#242424` · gris `#8A8A8A`/`#555555`. Or `#C4A459` **interdit** dans ce lot.

**Couleurs de données QDI** (écran coach uniquement) :
`--qdi-trajectoire:#60A5FA` · `--qdi-fluidite:#FFB703` · `--qdi-freinage:#E63946` · `--qdi-acceleration:#4ADE80` · `--qdi-regularite:#C084FC`

Typographies : Syncopate 400/700, Inter 400/500/600, JetBrains Mono 400/500/700 — réutilisez le chargement de polices existant du site s'il couvre ces familles ; sinon ajoutez les `<link>` Google Fonts des fichiers de référence.

**Mise à l'échelle** : reprenez le mécanisme `scale()` des fichiers de référence (scène fixe 1920×1080, transform scale sur resize). Les deux écrans sont conçus pour un affichage HDMI plein écran ; la mise à l'échelle sert uniquement à la revue sur un écran quelconque.

---

## 3. STRUCTURE DANS LA SPA

La SPA est mono-fichier. Suivez la convention existante (grep la façon dont les pages actuelles sont déclarées : templates, fonctions de rendu, sections). Cible :

- Deux fonctions de rendu `renderPavillonAccueil()` / `renderPavillonCoach()` + leurs styles dans le bloc CSS du fichier, préfixés `.pav-` pour éviter toute collision avec les styles marketing existants (grep les préfixes en usage avant de choisir).
- Un module logique commun `pavillonLive` (abonnements, état, reconnexion) — en fonction/objet dans le fichier, conformément au style du repo.
- Si `CLAUDE.md` autorise des fichiers séparés pour des routes techniques, préférez `pavillon.js` + import — sinon tout reste dans `index.html`. Documentez le choix en commentaire.

---

## 4. ACCÈS & AUTHENTIFICATION

| Route | Accès |
|---|---|
| `/pavillon/accueil` | Compte utilisateur **dédié affichage** (créé manuellement par le staff, `users.role = 'display'` — vérifiez les valeurs réelles de `role` par select distinct et adaptez ; si aucune valeur d'affichage n'existe, gardez la garde sur un compte authentifié standard et remontez `TODO_ARBITRAGE: rôle display`). Session persistante (le téléviseur ne doit pas se déconnecter). |
| `/pavillon/coach` | Compte coach authentifié. Garde : l'utilisateur possède une ligne `coach_permissions` avec `can_view_pilots = true`. Sinon : redirection accueil du site avec message neutre. |

Aucune de ces routes n'apparaît dans la navigation publique du site.

---

## 5. DONNÉES & TEMPS RÉEL

### 5.1 Sources vérifiées (schéma inspecté le 17/07/2026)

| Élément UI | Source |
|---|---|
| Pilotes du jour (accueil) | vue `pavillon_pilotes_jour` (migration) — jamais `users` en direct |
| Météo (accueil + coach) | vue `pavillon_meteo` ; si vide : bloc masqué, pas de valeurs inventées |
| Planning du jour (accueil) | `sessions` du jour (`date = CURRENT_DATE`) : `start_time`, `end_time`, `format`, `notes` — mise en avant du créneau courant côté client |
| Compteur présents (accueil) | count des lignes de `pavillon_pilotes_jour` + `sessions.max_capacity` |
| Tracé | `circuits.track_svg_path` (+ `centerline_latlon` pour la projection des positions, voir 5.2) |
| Pilote suivi (coach) | `telemetry_sessions` en cours (`status` — valeurs réelles : `completed`, `aborted` ; une session live est une session sans `ended_at`) du pilote sélectionné |
| Derniers tours (coach) | `laps` de la session (`lap_number`, `duration_seconds`, `is_best_lap`) |
| Mesures (coach) | `telemetry_sessions.max_speed_kmh`, `max_g_lateral`, `laps.max_g_braking`, `distance_km` |
| Référence personnelle (coach) | `circuits.best_lap_seconds` (ligne du pilote) ou min des `laps` — même règle que le lot PROFIL_CARTES |
| QDI (coach) | `app_session_analyses.qdi` selon le **contrat jsonb** défini en migration §4. **Le champ est NULL partout à ce jour** : l'UI doit gérer l'absence (radar masqué + mention « QDI en attente de calcul ») et le rendu est validable via le mode démo §5.3 |
| Segments colorés du tracé (coach) | `app_segment_analyses` (`segment_index`, `kind`, `margin_zone`) — mapping segment → couleur QDI documenté en commentaire |
| Dispersion régularité (coach) | `laps.duration_seconds` de la session (min/max/médiane calculés client) |
| Annotations (coach) | `coach_annotations` du coach connecté pour la session affichée (`corner_index`, `body`, `created_at`), Realtime INSERT |
| File des pilotes (coach) | `coach_pilots` actifs du coach + dernière `telemetry_session` de chaque pilote ce jour → états : En piste (session sans `ended_at`) / Post-session (`completed` ce jour) / À venir (aucune) |

### 5.2 Positions live — architecture imposée

Ne PAS s'abonner aux INSERT de `telemetry_frames` (25 Hz × n pilotes : intenable). Architecture :

- Canal **Supabase Realtime Broadcast** : `pavillon:{circuit_id}:live`.
- Message : `{ user_id, car_number, lat, lon, ts }`, cadence 1 Hz maximum par pilote.
- **L'émission est côté app mobile et HORS de ce lot.** Vous implémentez la réception + interpolation linéaire entre deux messages (les pastilles glissent, elles ne sautent pas) + disparition d'une pastille après 20 s sans message.
- Projection lat/lon → coordonnées SVG : homographie simple depuis `circuits.bbox_*` vers le viewBox du tracé. Fonction utilitaire `projectToTrack(lat, lon, circuit)` testée (§7.3).
- En tête de module : `// DEPENDANCE_APP: émission Broadcast pavillon:{circuit_id}:live — lot app à planifier`.

### 5.3 Mode démo (obligatoire)

Paramètre `?demo=1` sur les deux routes : données factices identiques aux références (mêmes noms, mêmes chronos, pastilles animées sur le tracé, QDI rempli selon le contrat). C'est le mode de recette visuelle, de démonstration commerciale (Pépite, Réseau Entreprendre) et de test tant que l'émission app n'existe pas. Le mode démo n'effectue AUCUNE requête Supabase.

### 5.4 Résilience (écrans allumés 8 h+)

- Reconnexion automatique Realtime avec backoff (1 s → 30 s max) ; bandeau discret « Reconnexion… » en JetBrains Mono 11px, coin bas droit, jamais de modale.
- Rafraîchissement complet des données froides (pilotes, planning, météo) toutes les 5 min + au retour de reconnexion.
- Aucune fuite : les `setInterval`/abonnements sont créés une fois et nettoyés au changement de route (grep le mécanisme de teardown du routeur existant).
- Horloge : `setInterval` 1 s, tolérance dérive nulle (relire `Date` à chaque tick, comme la référence).

---

## 6. TRANSPOSITION DEPUIS LES RÉFÉRENCES

- Le CSS des références est repris à l'identique (sélecteurs renommés avec le préfixe choisi §3). Écarts tolérés : néant sur couleurs/typos, ±2px espacements.
- Les `animateMotion` SVG des références sont des démonstrations : en production les pastilles sont positionnées par `projectToTrack` + interpolation JS (`requestAnimationFrame`). En mode démo, réutilisez `animateMotion` tel quel.
- Radar QDI : générez les points des polygones depuis les valeurs du contrat (fonction `radarPoints(values, rayonMax)` — 5 axes, ordre figé Cap, Trajectoire, Visée, Plongée, Anticipation). Pointillé = `reference`, plein rouge = `value`.
- Formatage chronos : reprenez `formatLapTime` à l'identique du lot PROFIL_CARTES (spécification §6 de ce lot) — mêmes règles, mêmes tests.

---

## 7. CONTRÔLES QUALITÉ — OBLIGATOIRES

### 7.1 QA visuelle
- [ ] Capture 1920×1080 de chaque route en `?demo=1` posée côte à côte avec la référence — zéro écart couleurs/typos, ±2px espacements.
- [ ] Test à 3840×2160 et 1366×768 : la scène se met à l'échelle sans bandes déformées ni scroll.
- [ ] Polices chargées avant affichage (pas de flash de police système : masquer la scène tant que `document.fonts.ready` n'est pas résolu).

### 7.2 QA données & erreurs
- [ ] Vues absentes (migration non appliquée) → écran « Configuration Pavillon incomplète » sobre, pas de crash console.
- [ ] Aucun pilote ce jour → tracé seul + « Aucune session en cours », planning affiché.
- [ ] `qdi` NULL → radar remplacé par « QDI en attente de calcul », le reste de l'écran coach vivant.
- [ ] Coupure réseau simulée (DevTools offline 60 s) → bandeau reconnexion, reprise propre, données rafraîchies.
- [ ] Pastille sans message depuis 20 s → disparition.
- [ ] Aucune valeur inventée en cas de donnée manquante.

### 7.3 QA logique (tests — suivez l'outillage du repo ; à défaut, page de test `?tests=1` listant les assertions)
- [ ] `projectToTrack` : coins de la bbox → coins du viewBox ; point médian → centre.
- [ ] `radarPoints` : valeurs 100 partout → pentagone extérieur exact ; 0 → centre.
- [ ] `formatLapTime` : mêmes cas que le lot PROFIL_CARTES.
- [ ] Logique d'état file pilotes (En piste / Post-session / À venir) sur jeux de données synthétiques.

### 7.4 QA doctrine (bloquante)
- [ ] Sur `/pavillon/accueil` : grep du rendu et des requêtes — aucun `duration_seconds`, `best_lap`, `qdi`, `margin` ne transite vers cette route. Aucun nom complet sans opt-in (vérifier la réponse réseau brute, pas seulement le DOM).
- [ ] Sur `/pavillon/coach` : aucun chrono d'un pilote hors `coach_pilots` actifs du coach connecté.
- [ ] Aucun score composite QDI nulle part (grep `score`, `note`, `global` dans les chaînes UI).
- [ ] Couleurs QDI absentes de `/pavillon/accueil` (grep des 5 hex dans le CSS de la route accueil).
- [ ] Or `#C4A459` absent du lot (grep).
- [ ] Bande annotations : sous le tracé, jamais superposée, mention « Espace réservé » présente en en-tête coach.

### 7.5 QA sécurité
- [ ] Clé anon uniquement.
- [ ] La garde coach est vérifiée à chaque affichage de route, pas seulement à la connexion.
- [ ] Les routes Pavillon sont absentes du sitemap et de la navigation.
- [ ] Test d'intrusion simple : compte pilote standard sur `/pavillon/coach` → redirection ; lecture directe de `users` depuis la route accueil → aucune requête de ce type dans le code.

### 7.6 Greps de pré-commit
```bash
grep -n "C4A459" index.html pavillon.js 2>/dev/null
grep -n "service_role" index.html pavillon.js 2>/dev/null
grep -niE "score|classement|podium" <fichiers du lot>      # chaînes UI uniquement, justifier toute occurrence
grep -n "telemetry_frames" <fichiers du lot>                # doit être vide (architecture §5.2)
grep -n "TODO" <fichiers du lot>                            # tags TODO_ARBITRAGE / DEPENDANCE_APP uniquement
```

---

## 8. LIVRAISON

- **Un commit unique** : `feat(pavillon): écrans accueil + coach — lot ECRANS_PAVILLON`.
- Message de commit : fichiers touchés, choix §3 documenté, résultats des greps, dépendances ouvertes (`DEPENDANCE_APP`, `TODO_ARBITRAGE: rôle display`, `TODO_ARBITRAGE: contrat QDI`).
- Migration jointe non exécutée.
- Un contrôle §7 échoue → rapport d'échec, pas de push.

## 9. CE QUE VOUS NE FAITES PAS

- Pas d'exécution de migration, pas de modification RLS, pas d'edge function.
- Pas d'abonnement à `telemetry_frames`.
- Pas de score composite, pas de classement, pas de chrono sur l'écran accueil.
- Pas de nouvelle dépendance ni de framework — la SPA reste vanilla.
- Pas d'emoji, pas d'anthropomorphisation, aucun animal nommé.
