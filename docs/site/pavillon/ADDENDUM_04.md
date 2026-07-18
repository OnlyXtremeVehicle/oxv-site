# ADDENDUM 04 — LOT ÉCRANS PAVILLON

**Décision de M. Fillat du 18/07/2026 : l'ensemble du dispositif Pavillon est côté site internet.** Les émetteurs des canaux 2 et 4 deviennent des routes web de ce lot. **Seule l'émission du canal 1 (positions live) reste côté app** — c'est le téléphone embarqué qui reçoit le flux RaceBox ; c'est l'unique `DEPENDANCE_APP` restante.

---

## 1. Nouvelle route `/pavillon/controle` — télécommande de la TV coach

**Usage :** ouverte sur la tablette du coach (navigateur, à côté de l'app). Émet sur `pavillon:coach:{coach_user_id}:control` (contrat v2). La TV du même coach obéit.

**Garde :** identique à `/pavillon/coach` (compte coach, `coach_permissions.can_view_pilots`). Le `coach_user_id` du canal est celui du compte connecté — jamais un paramètre d'URL.

**Interface (outil, pas vitrine — tokens standards, format portrait tablette, cibles tactiles ≥ 48px) :**
- Liste « Mes pilotes du jour » (même source que la file de l'écran coach) : chaque ligne = numéro, nom, état (En piste / Post-session / À venir).
- Par pilote en piste : bouton « Suivre » → émet `follow_pilot`.
- Par pilote post-session : bouton « Restitution » → émet `show_restitution`.
- Multi-sélection : cases sur les pilotes en piste (2–4) + bouton « Multi-suivi » → émet `multi` (tri par numéro appliqué à l'émission ET à la réception).
- Bouton « Écran neutre » → émet `idle`.
- L'état actuellement affiché par la TV est marqué dans la liste (la télécommande écoute son propre canal — le dernier message fait foi, y compris après rechargement).
- Émission : validation `validateMessage` avant envoi (contrat §Tests), accusé visuel simple (l'état marqué change).

## 2. Nouvelle route `/pavillon/regie` — console Staff (état + drapeaux)

**Usage :** poste d'accueil ou téléphone du staff. Émet sur `pavillon:{circuit_id}:etat` (contrat v2, Addendum 03).

**Garde :** compte staff — même mécanisme que `/pavillon/admin` (`TODO_ARBITRAGE: rôle staff`, une seule résolution pour les deux routes).

**Interface :**
- Section « État piste » : quatre boutons exclusifs Ouverte / Pause / Fermée / Veille, état courant marqué, champ message optionnel (120 car. max, ex. « Reprise 13:30 »).
- Section « Drapeau » : trois boutons exclusifs Jaune / Rouge / Aucun. Jaune et rouge exigent une **confirmation en deux temps** (second appui « Confirmer ») ; « Aucun » est immédiat — lever une neutralisation ne doit jamais attendre. `drapeau_ts` = instant d'émission.
- Rappel fixe sous la section drapeau : « Relais d'information. Seuls les signaux du circuit font foi. »
- Chaque émission renvoie l'état complet (etat + drapeau + message) — le canal reste idempotent : un seul message reconstruit tout l'affichage.
- La régie écoute son propre canal : deux postes de régie ouverts restent synchronisés.

## 3. Répartition des responsabilités — remplace le tableau final du contrat

| Côté | Implémente |
|---|---|
| **Lot site (ce lot)** | Écrans `/pavillon/accueil` + `/pavillon/coach` (4 modes) · `/pavillon/admin` (photos) · `/pavillon/controle` (émetteur canal 2) · `/pavillon/regie` (émetteur canal 4) · réception canaux 1–4 · validations émission ET réception |
| **Lot app (réduit)** | Émission canal 1 uniquement : throttle RaceBox 25 Hz → 1 Hz, format contrat v2 (`DEPENDANCE_APP`) |
| **Migrations (à valider)** | Vues Pavillon · table photos · publication realtime `coach_annotations` · policies canaux privés |

## 4. QA supplémentaire

- [ ] Télécommande et TV côte à côte (`?demo=1` exclu — test réel sur canaux) : chaque bouton produit le bon mode en < 1 s.
- [ ] `multi` émis avec 1 ou 5 sélections → bouton inactif (bornes 2–4 à l'émission ; la réception garde ses propres bornes).
- [ ] Deux régies ouvertes : l'action de l'une se reflète sur l'autre.
- [ ] Drapeau jaune sans confirmation (simple appui) → aucune émission.
- [ ] « Aucun » émis pendant une confirmation en attente → priorité au levage, confirmation annulée.
- [ ] Compte pilote sur `/pavillon/controle` et `/pavillon/regie` → redirection.
- [ ] Les quatre nouvelles routes absentes du sitemap et de la navigation (grep).
- [ ] Rechargement de la télécommande pendant un mode `multi` actif → l'état marqué est reconstruit depuis le dernier message du canal.
