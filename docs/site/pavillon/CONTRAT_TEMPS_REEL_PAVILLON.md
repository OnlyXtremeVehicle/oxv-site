# CONTRAT TEMPS RÉEL PAVILLON — v2

**Statut :** spécification d'interface partagée — v2 (18/07/2026) : ajout action `multi` au canal 2, voir ADDENDUM_02 §1. Les récepteurs acceptent v1 et v2. Ce document lie le lot app (émission) et le lot site (réception). Toute modification exige une montée de version et une mise à jour des DEUX côtés. Aucun des deux lots ne peut dévier de ce contrat sans arbitrage de M. Fillat.

**Transport :** Supabase Realtime (projet `fouvuqkdxarjpjbqnsjq`).
**Règle générale :** tout message porte `v: 1`. Un récepteur qui reçoit une version inconnue ignore le message et journalise un `console.warn` unique (pas un par message).

---

## Canal 1 — Positions live

| | |
|---|---|
| Nom | `pavillon:{circuit_id}:live` |
| Type | Broadcast (pas de postgres_changes) |
| Émetteur | App mobile (pendant une session de capture active) |
| Récepteurs | `/pavillon/accueil` · `/pavillon/coach` |
| Cadence | **1 Hz maximum par pilote** (throttle côté app depuis le flux RaceBox 25 Hz) |
| TTL affichage | Pastille retirée après **20 s** sans message du `user_id` |

**Message :**
```json
{
  "v": 1,
  "user_id": "uuid",
  "car_number": 27,
  "lat": 45.28031,
  "lon": -0.14276,
  "speed_kmh": 182,
  "ts": "2027-07-08T14:32:07.120Z"
}
```

Règles :
- `car_number` est inclus pour éviter un aller-retour base côté écran accueil. **Jamais de nom** dans ce canal — l'identité nominative passe exclusivement par la vue `pavillon_pilotes_jour`.
- `speed_kmh` est consommé par l'écran coach uniquement. L'écran accueil l'ignore (aucune donnée de performance publique).
- Interpolation linéaire côté récepteur entre deux messages ; pas d'extrapolation au-delà du TTL.

---

## Canal 2 — Contrôle de l'écran coach (tablette → TV)

| | |
|---|---|
| Nom | `pavillon:coach:{coach_user_id}:control` |
| Type | Broadcast |
| Émetteur | Site — route `/pavillon/controle` (ADDENDUM_04) |
| Récepteur | `/pavillon/coach` connecté avec le compte du même coach |

**Messages :**
```json
{ "v": 1, "action": "follow_pilot",     "user_id": "uuid", "telemetry_session_id": "uuid", "ts": "…" }
{ "v": 1, "action": "show_restitution", "telemetry_session_id": "uuid", "ts": "…" }
{ "v": 1, "action": "idle", "ts": "…" }
```

Règles :
- `follow_pilot` → mode live (réf. `tv-coach.html`).
- `show_restitution` → mode restitution (réf. `tv-coach-restitution.html`).
- `idle` → écran neutre du stand : insigne + « Stand Coach · Espace réservé » + horloge.
- La TV vérifie que le `telemetry_session_id` reçu appartient bien à un pilote de `coach_pilots` du coach connecté **avant** d'afficher quoi que ce soit (défense en profondeur : la tablette est fiable, le canal ne l'est pas par principe).
- Sans message reçu depuis le chargement : la TV démarre en `idle`.
- Dernier message reçu = état courant (le canal est idempotent : rejouer le dernier message reproduit l'écran).

---

## Canal 3 — Annotations coach

| | |
|---|---|
| Type | **postgres_changes** — INSERT sur `public.coach_annotations` |
| Filtre | `telemetry_session_id = eq.{session affichée}` |
| Récepteur | `/pavillon/coach` (modes live et restitution) |

Règles :
- Nouvelle annotation → apparition en tête de bande, les plus anciennes descendent, maximum 3 visibles (les autres restent sur la tablette).
- La RLS existante de `coach_annotations` s'applique — le récepteur étant le compte coach, aucune policy nouvelle n'est requise. Vérifier que la publication `supabase_realtime` inclut la table ; sinon l'ajouter en migration (à faire valider).

---

## Canal 4 — État de l'écran accueil

| | |
|---|---|
| Nom | `pavillon:{circuit_id}:etat` |
| Type | Broadcast |
| Émetteur | Site — route `/pavillon/regie` (ADDENDUM_04) |
| Récepteur | `/pavillon/accueil` |

**Message :**
```json
{ "v": 1, "etat": "ouverte" | "pause" | "fermee" | "veille", "message": "texte libre optionnel", "ts": "…" }
```

Comportements écran accueil :
- `ouverte` → écran complet (réf. `tv-accueil.html`), badge « Piste ouverte » rouge pulsant.
- `pause` → badge devient « Piste en pause » (pastille fixe grise), tracé sans pastilles, planning et météo conservés. `message` affiché sous le badge s'il est présent (ex. « Reprise 13:30 »).
- `fermee` → badge « Piste fermée », idem pause.
- `veille` → écran épuré : insigne centré, manifeste, horloge, prochaine ouverture (première ligne de `sessions` à venir). C'est l'état hors journée de roulage.
- **Repli sans émetteur** (aucun message depuis le chargement) : l'état est dérivé du planning — créneau de roulage en cours → `ouverte` ; jour de session hors créneau → `pause` ; aucun créneau ce jour → `veille`. Le canal, quand il émet, **prime toujours** sur la dérivation.

---

## Sécurité des canaux

1. **Canaux privés Realtime activés** (autorisation par policies `realtime.messages`) : tout abonnement exige un JWT authentifié. Les écrans étant connectés (compte affichage / compte coach), aucune écoute anonyme n'est possible. La mise en place des policies d'autorisation Broadcast fait l'objet d'une migration dédiée à faire valider — tant qu'elle n'est pas appliquée, les canaux fonctionnent en mode authentifié simple et ce point reste ouvert : `TODO_ARBITRAGE: policies realtime`.
2. Aucun canal ne transporte de nom, de chrono d'autrui vers l'accueil, ni de donnée QDI. Le contrôle §2 (vérification `coach_pilots`) est obligatoire côté récepteur.
3. Les noms de canaux incluent des UUID (`circuit_id`, `coach_user_id`) — non devinables, mais ce n'est **pas** le mécanisme de sécurité : les policies le sont.

---

## Tests de contrat (à implémenter des deux côtés)

- Émission : chaque message émis est validé contre le schéma avant envoi (fonction `validateMessage(canal, payload)` partagée conceptuellement — implémentée deux fois, testée deux fois, mêmes cas).
- Réception : message malformé ou version inconnue → ignoré + warn unique, jamais de crash d'écran.
- Cas de test communs minimaux :
  1. Position valide → pastille créée/déplacée.
  2. Position sans `car_number` → rejetée.
  3. `follow_pilot` avec session d'un pilote hors `coach_pilots` → refusé, écran inchangé, warn.
  4. `etat: "pause"` avec `message` → badge + message affichés.
  5. Silence 20 s → pastille retirée.
  6. Rafale 25 Hz reçue (app mal throttlée) → le récepteur throttle à 1 Hz par `user_id` (défense) et journalise.

---

## Récapitulatif des responsabilités

| Côté | Implémente |
|---|---|
| **Lot site (ECRANS_PAVILLON)** | Réception canaux 1–4, interpolation, TTL, modes d'écran, dérivation d'état de repli, validations réception |
| **Lot app (réduit — voir ADDENDUM_04)** | Émission canal 1 uniquement (throttle 25 Hz → 1 Hz) |
| **Migration (à valider)** | Publication realtime `coach_annotations` si absente · policies canaux privés |
