# Réponse du site au dossier de raccordement application ↔ site

> Répond au dossier du **27 juillet 2026**. Mesuré en base et dans `index.html` le
> **2 août 2026**. Tout fait porte sa mesure ; ce qui n'a pas été vérifié est dit.
>
> Le dossier du 27/07 est antérieur au document du 01/08 : **D-01 et D-02 y sont déjà
> tranchés** et ne bloquent plus rien (§ 1).

---

## 0. Les cinq contradictions à trancher avant tout code

Ce ne sont pas des questions ouvertes : ce sont des points où **le dossier du 27/07 et
l'état réel se contredisent**. Les développer sans trancher produirait du travail à défaire.

| # | Le dossier dit | L'état réel |
|---|---|---|
| **C1** | `events` = balades, à conserver | La base porte `COMMENT … 'DEPRECATED — A1 verrouillé (2026-06-30) … À SUPPRIMER'`. Décision opposée, écrite en base. |
| **C2** | « le prix se calcule côté serveur, jamais côté application » | Le prix est calculé **dans le navigateur** (`bkComputePrice`) et inséré tel quel. Et **tout pilote peut réécrire `price_total` sur sa propre ligne** (§ D-07). |
| **C3** | `is_premium` est supprimé, « confirmer que le site ne s'en sert pas » | **Le site s'en sert**, à 4 endroits (annuaire partenaires, espace partenaire, liste admin). |
| **C4** | l'avantage de parrainage est « symbolique … aucun avantage commercial » | Le site **affiche déjà trois paliers opérationnels** aux pilotes : *5 → priorité collective · 10 → box dédié · 20 → nommée plateau*. |
| **C5** | D-22 = appairage (registre des décisions) | D-22 = aussi les liens app→site (`DETTE.md`). **Le premier est clos** (§ D-22b). |

---

## 1. D-01 · D-02 — clos, et rien à restaurer

**Tranché le 01/08 par le fondateur** : les deux ensembles sont **totalement disjoints**,
il n'y a **jamais eu de perte**. Aucune journée n'est validée ; le fondateur attend la
confirmation du calendrier par le circuit et saisira chaque session par le compte admin.

**D-02, mesuré** — il n'y a pas cinq sauvegardes de dates différentes, mais **un seul
instantané du 19/07/2026**, en cinq tables :

| Table | Contenu |
|---|---|
| `_backup_sessions_20260719` | **44 lignes**, du 2026-05-05 au 2027-04-06 |
| `_backup_registrations_20260719` | 5 lignes |
| `_backup_payments_20260719` | 2 lignes |
| `_backup_weather_20260719` | 14 lignes |
| `_backup_session_feedback_20260719` | 0 ligne |

**La référence est donc cet instantané du 19/07**, et il n'y a rien à en restaurer : les
44 journées étaient un calendrier de travail, aucune n'était validée.

**La règle « aucune migration destructive » est respectée** : rien n'a été supprimé. Les
cinq tables `_backup_*` sont conservées.

---

## 2. D-03 — `events` : décision opposée, à réconcilier (C1)

**Mesuré.** Le site ne référence `events` ni `event_registrations` **nulle part**
(0 occurrence dans `index.html`). Il n'y a donc, côté site, **aucun usage circuit d'`events`
à annoter** : l'annotation demandée n'a pas d'objet.

Le vrai point est ailleurs. La base porte, depuis le 30/06 :

```
events                : DEPRECATED — A1 verrouillé (2026-06-30). Canonique = public.sessions.
                        À SUPPRIMER après migration code app … Plan: docs/site/PR_SITE_DEPRECATE_EVENTS.md
event_registrations   : DEPRECATED — A1 verrouillé (2026-06-30). Canonique = public.registrations.
                        À SUPPRIMER après migration code app.
```

Votre dossier attribue à `events` un rôle **conservé** (balades et rassemblements). Les
deux positions sont incompatibles, et c'est la base qui porte aujourd'hui l'ancienne.

**Je n'ai pas modifié ces commentaires** : ils enregistrent une décision verrouillée par
le fondateur, ce n'est pas au site de la retourner seul. Dès qu'il tranche, l'un des deux :

```sql
-- Si events est conservé pour les balades (position du dossier 27/07) :
comment on table public.events is
  'Balades et rassemblements. NE PAS utiliser pour le circuit : canonique = public.sessions.
   Révision de A1 (2026-06-30) actée le …';
comment on table public.event_registrations is
  'Participations aux balades et rassemblements. Circuit = public.registrations.';

-- Si A1 tient (suppression totale) : les commentaires actuels restent, et le plan
-- PR_SITE_DEPRECATE_EVENTS.md s'applique tel quel.
```

Note : `event_registrations` a sa propre énumération — `registered · checked_in ·
cancelled · no_show` — distincte de celle des inscriptions circuit. Conserver les deux
mondes, c'est aussi conserver deux vocabulaires de statut.

---

## 3. D-04 à D-07 — le tunnel de réservation

### D-04.1 · Accepter des lignes que le site n'a pas créées — **oui, déjà**

Policy `registrations_insert_own_or_admin` : `WITH CHECK (user_id = auth.uid() OR is_admin())`.
L'application, authentifiée avec le compte du pilote, insère sans rien changer côté site.

⚠️ **Contrainte à connaître** : il existe un **index unique partiel `(user_id, session_id)
WHERE status <> 'cancelled'`**. Une deuxième demande pour la même journée renvoie `23505`.
L'application doit traiter ce code comme « déjà inscrit », pas comme une erreur technique.

### D-04.2 · Le troisième état — **il existe déjà : `pending_payment`**

`registration_status_enum` = `pending · confirmed · cancelled · attended · no_show · pending_payment`.

Il n'apparaissait **nulle part** dans le site : les quatre tables de libellés s'arrêtaient
à `no_show` et le repli affichait la chaîne brute `pending_payment` au pilote comme à
l'admin. **Corrigé le 01/08** (commit `cf0cfd8`) : libellé « Paiement attendu », styles
ajoutés aux règles existantes de `pending`.

**Utilisez `pending_payment`.** Aucune migration n'est nécessaire.

### D-04.3 · Afficher la demande pré-remplie — **déjà le cas**

« Mes sessions » lit `registrations` du pilote avec le filtre inclusif
`neq('status','cancelled')` : une ligne posée par l'application apparaît dès la connexion,
avec sa journée, son offre, son véhicule, son prix et l'état « Paiement attendu ».

Vérifié aussi : le **décompte de capacité** et l'**anti-doublon** utilisent le même filtre
inclusif — un dossier `pending_payment` occupe donc déjà une place, ce qui est la bonne
sémantique. Le chiffre d'affaires admin, lui, ne compte que `confirmed`/`attended`.

### D-04.4 · Le prix côté serveur — **non, et c'est pire que « pas encore »** (C2)

Aujourd'hui : `bkComputePrice(offre, format, nb_sessions_déjà_faites)` s'exécute **dans le
navigateur**, et `price_total` / `price_deposit` sont insérés depuis le client.

Et surtout, § D-07 : **le pilote peut réécrire ces colonnes sur sa propre ligne**. Le prix
n'est donc pas « à passer côté serveur » — il est **actuellement modifiable par le client**,
exactement ce que votre dossier veut éviter.

### D-04 · Question ouverte : écriture directe, ou signal ?

**Ni l'un ni l'autre. Recommandation : une RPC partagée.**

```sql
create function public.create_registration(
  p_session_id uuid, p_offer_type text, p_vehicle_id uuid, p_insurance_option text
) returns uuid language plpgsql security definer …
```

Elle calcule le prix **en base** depuis `sessions.available_offers`, pose
`status = 'pending_payment'`, respecte l'index unique, et renvoie l'`id`. Les **deux**
côtés l'appellent — le site pour son tunnel, l'application pour le dossier. Cela règle
d'un coup D-04.4, D-05 et la moitié de D-07, et supprime la question « qui écrit » :
personne n'écrit la table directement.

### D-05 · La règle de propriété — traduisible en droits, pas en discipline

La règle « à l'application tant qu'impayé, au site une fois payé » n'a de valeur que si la
base l'impose. Aujourd'hui elle n'impose rien (§ D-07). Traduction proposée :

- `REVOKE UPDATE` sur les colonnes sensibles pour `authenticated` ;
- deux RPC `security definer` : `update_registration_draft(...)` — autorisée seulement
  tant que `status IN ('pending','pending_payment')` — et `cancel_registration(...)` ;
- après paiement, `update_registration_draft` refuse : le dossier passe au site.

### D-06 · L'URL de paiement — contrat proposé

```
https://www.oxvehicle.fr/paiement/{registration_id}
```

Route authentifiée. Non connecté → mémorisation de la cible, connexion, reprise
automatique (mécanisme déjà en place pour `/controle-pilote/{user_id}`). Connecté →
lecture par RLS own-row, affichage référence · journée · offre · montant · état, et
bouton de règlement piloté par le point de bascule unique existant `OXV_PAYMENT`.

⚠️ **`OXV_PAYMENT.mode` vaut `'pending'` : aucun prestataire de paiement n'est branché.**
La page existera et sera stable, mais elle **ne permettra pas de payer** tant qu'un PSP
n'est pas configuré. Vos trois canaux (lien profond, courriel, notification) peuvent
pointer dessus dès maintenant ; ils mèneront à un état honnête, pas à une caisse.

**Non implémentée** : elle fixe une forme d'URL, donc un engagement envers vous. Un mot
et je la construis.

### D-07 · Les transitions du site — liste exhaustive, mesurée

| Où | Acteur | Transition | Garde sur l'état de départ |
|---|---|---|---|
| Tunnel de réservation | pilote | ∅ → `pending` (INSERT) | — |
| `cancelRegistration` | **pilote** | * → `cancelled` | aucune |
| Validation de paiement (2 endroits) | admin | * → `confirmed` | aucune |
| `adminCancelRegistration` | admin | * → `cancelled` | aucune |
| Annulation d'une journée | admin | * → `cancelled` (cascade) | aucune |
| `adminMarkAttended` (scan QR) | admin | * → `attended` + `attended_at` | aucune |

**Le site n'écrit jamais `no_show`.** Il n'écrivait jamais `pending_payment` non plus.

**Aucune transition n'est gardée** : toutes sont des `UPDATE` inconditionnels.

**Et la collision que vous cherchez existe.** Vous écrivez `attended` depuis `pending` ou
`confirmed` ; `adminMarkAttended` écrit `attended` **sans condition de départ**. Deux
écrivains, aucune garde, le dernier gagne.

**Plus grave — mesuré le 01/08.** La policy `registrations_update_own_or_admin` autorise
l'`UPDATE` sur sa propre ligne, et le rôle `authenticated` détient le droit `UPDATE` sur
**toutes** les colonnes : `status`, `price_total`, `price_deposit`, `deposit_paid_at`,
`attended_at`, `user_id`… RLS ne restreint pas les colonnes ; seuls les droits le font.

> **Tout pilote connecté peut se passer en `confirmed` ou `attended` et réécrire son prix,
> par un simple `PATCH` PostgREST. Sans payer.**

C'est la réponse actuelle, non voulue, à votre question. Le correctif complet est dans
[PR_SITE_TUNNEL_RESERVATION.md](PR_SITE_TUNNEL_RESERVATION.md) § 2 — il touche
l'annulation côté site **et** vos écritures : il se déploie des deux côtés le même jour.
**Ce que j'attends de vous : la liste des colonnes de `registrations` que l'application
écrit**, pour calibrer le `REVOKE` sans vous casser.

---

## 4. D-08 à D-12 — les champs partagés

| # | Champ | Mesuré côté site | Réponse |
|---|---|---|---|
| D-08 | `users.car_number` | `smallint`. Le site **ne le collecte pas** ; il le **lit** seulement, sur les écrans Pavillon. | Non, il n'est pas collecté aujourd'hui. |
| D-08 | `users.bio` | **0 usage.** (Les 6 occurrences de « bio » visent `coach_profiles.bio`.) | Non câblé, confirmé. |
| D-08 | `users.pavilion_name_optin` | **0 usage** dans le site ; lu côté serveur par la vue `pavillon_pilotes_jour`. | Non collecté : aucun écran ne permet au pilote de donner cet accord. |
| D-09 | `users.is_admin` | **Le site ne l'écrit jamais** (2 occurrences, toutes deux des commentaires sur la fonction SQL `is_admin()`). | ✅ Confirmé, le miroir par déclencheur ne rencontrera aucun conflit. |
| D-10 | `users.public_handle` | **Le site ne le collecte pas** ; lecture Pavillon uniquement. | Aucune règle de format côté site. |
| D-11 | `users.notification_preferences` | **0 occurrence.** | ✅ Confirmé : le site ne l'écrase pas et n'y utilise aucune clé. |
| D-12 | fuseau horaire | **`users.timezone text` existe déjà.** Le site ne l'écrit pas. | La colonne est là ; prenez-la. |

**D-08, la collision de numéro : elle est déjà arbitrée, et pas comme vous l'imaginez.**
La base porte `CREATE UNIQUE INDEX users_car_number_unique ON users (car_number) WHERE
car_number IS NOT NULL` — **l'unicité est globale, pas par journée**. Deux pilotes ne
peuvent pas porter le même numéro, même sur des journées différentes ; le premier arrivé
le garde. Un arbitrage au paddock, journée par journée, est **impossible sans supprimer
cet index**. À trancher : unicité globale (état actuel, rien à faire) ou unicité par
journée (nouvel index sur la participation, pas sur le compte).

`public_handle` est également unique en base (`users_public_handle_key`). Un index
non-unique redondant (`idx_users_public_handle`) coexiste — sans effet, à nettoyer un jour.

---

## 5. D-13 — éligibilité

**Mesuré.** `eligibility_items` porte **9 lignes**. Son commentaire dit : *« Écriture admin
(validation) + système (seed/sync docs) »*.

- **Le site lit** la table à trois endroits (dossier pilote, liste admin, écran de checkup).
- **Le site écrit** un seul chemin : la **validation admin** (`update` sur un item).
- **Le site ne fait aucun `INSERT`** : le seed ne vient pas de `index.html`. Une fonction
  `eligibility-reminders` est déployée. **Je n'ai pas ouvert son code** : je ne peux pas
  affirmer qu'elle sème, seulement qu'aucun autre chemin site ne le fait.

**`declared_at` est sans risque côté site** : additive, aucun `select *` sur cette table.
Votre argument L321-1 est le bon — la date déclarée par le pilote et la date contrôlée par
l'organisateur sont deux faits distincts, et les confondre serait indéfendable.

---

## 6. D-14 à D-16 — partenaires et Territoire

**D-14.** Le site lit `partners.partner_type` et l'écrit à la candidature partenaire. Il ne
connaît ni `contact_policy` ni `channel`. Figer les trois énumérations côté application ne
casse rien tant que les valeurs actuelles de `partner_type` restent valides — **envoyez la
liste exacte**, je vérifie l'alignement.

**D-15 — non, le site s'en sert (C3).** `is_premium` apparaît à **4 endroits** :

- annuaire public des partenaires : sélectionné et utilisé pour **encadrer la carte en doré** ;
- espace partenaire : badge « Premium » ;
- liste admin des partenaires : badge « Premium » (sélection + affichage).

Supprimer la colonne casse ces écrans. Si la décision du 12/07 tient — et l'argument de la
régie 100 % saison est convaincant — **il faut retirer l'affichage côté site d'abord**,
puis supprimer la colonne. Deux migrations, dans cet ordre. Dites-moi si je prépare la
première.

**D-16.** `social_pings` : **0 occurrence côté site.** Aucune modération n'existe. Si elle
doit vivre côté site, c'est un écran admin à construire, pas un branchement.

---

## 7. D-17 — statut fondateur : la moitié existe déjà

**Mesuré.** Trois des quatre pièces que vous vous apprêtez à ajouter **sont déjà en base** :

- `founding_members.user_id` : **colonne présente** ;
- `users.founder_since` : présente ;
- `users.founder_number` : présente, avec `CREATE UNIQUE INDEX users_founder_number_unique
  … WHERE founder_number IS NOT NULL` — **la non-réattribution est déjà garantie par la base.**

Ce qui manque n'est pas le schéma, c'est l'écriture : **le site ne renseigne aucun des
trois.** `capture-membre-fondateur` insère `founding_members` par email et laisse `user_id`
à `null`.

**Une fonction `yousign-webhook` est déployée** — c'est l'endroit naturel pour attribuer le
numéro à la signature, dans l'ordre réel, comme vous le décrivez. **Je n'ai pas lu son
code** : je ne sais pas ce qu'elle fait aujourd'hui.

⚠️ **À connaître avant le rattachement par correspondance d'adresse** : j'ai ajouté le
01/08 un **index unique sur `lower(email)`** de `founding_members` (anti-abus du formulaire
public). Le rattachement par email est donc déterministe — une adresse, une candidature.

---

## 8. D-18 · D-19 — écuries

**D-18 — oui, confirmé.** `payments.status` prend bien `succeeded`, écrit à **deux endroits,
tous deux admin** : la validation d'un paiement dans l'espace admin. L'énumération
`payment_status_enum` vaut `pending · succeeded · failed · refunded`.

**Le moment exact** : quand un administrateur marque le paiement comme validé. Aucun
prestataire n'est branché (`OXV_PAYMENT.mode = 'pending'`), donc **aucun passage automatique
en `succeeded` n'existe aujourd'hui**. La table porte 1 ligne, en `pending`. Votre
déclencheur de parrainage ne s'est donc jamais exécuté — et ne s'exécutera qu'au geste d'un
admin, tant qu'il n'y a pas de PSP.

**D-19 — non, je ne peux pas le confirmer (C4).** Le site **affiche déjà trois paliers** aux
pilotes, dans l'espace compte :

> **5** priorité collective · **10** box dédié · **20** nommée plateau

avec le compte de membres validés et le « prochain palier ». « Priorité collective » et
« box dédié » sont des engagements opérationnels, pas symboliques — et ils sont **déjà
promis** aux membres. Seul le palier 20 relève du symbole.

Il faut trancher : soit ces paliers sont tenus et D-19 est faux, soit ils sont retirés du
site — et ce serait un retrait d'un engagement déjà affiché.

*Observation secondaire, non liée* : `loadCrewCard` lit `crews` sans filtre et prend
`crews[0]`. La RLS restreint à sa propre écurie pour un pilote, donc c'est correct pour
lui ; **pour un administrateur, `is_admin()` renvoie toutes les écuries** et la carte
afficherait un nom arbitraire. Défaut d'affichage admin uniquement, à corriger un jour.

---

## 9. D-20 · D-21 — les sorties serveur

**Ce que le site a réellement.** 35 fonctions Edge déployées, dont `generate-invoice` qui
produit déjà un document. Côté hébergement web, **Vercel ne sert ici que des fichiers
statiques** : le dépôt ne contient aucune fonction serverless, et le site est un fichier
HTML unique. **Il n'y a pas d'« infrastructure du site » au sens d'un serveur de calcul.**

**Contrainte dure, à intégrer avant de choisir** : les fonctions Edge Supabase tournent sur
**Deno, sans binaire système**. **ffmpeg ne peut pas y tourner.** La vidéo synchronisée ne
peut donc être ni rendue sur Edge, ni rendue par le site tel qu'il est.

En conséquence :

| Sortie | Où c'est possible |
|---|---|
| PDF de bilan · carte-souvenir · livret de saison | Edge Supabase, sur le modèle de `generate-invoice` |
| **Vidéo synchronisée (ffmpeg)** | **Ni Edge, ni le site.** Il faut un troisième hôte — conteneur dédié, ou service de rendu. |
| **D-21 pré-calcul boxplot (~1 min / 50 trajectoires)** | Pas sur Edge non plus : les fonctions Edge ont une limite de temps d'exécution. À faire en tâche planifiée sur le même hôte que la vidéo, ou par `pg_cron` si le calcul peut s'écrire en SQL. |

Sur D-21, la fonction `security definer` qui ne rend que des agrégats est le bon dessin —
c'est exactement celui de `share_public_view`, déjà en production. Le précédent existe.

---

## 10. D-22 — les deux registres

**D-22 (registre des décisions) — appairage.** `app_pairing_codes` : **0 ligne**, confirmé.
Le mécanisme est **déployé et testé unitairement** (`redeem` d'un code invalide → 400
`invalid_or_expired` ; `generate` sans JWT → 401 ; RLS 4/4), mais **jamais parcouru de bout
en bout** — il manque l'écran de saisie côté application.

**Ma réponse : gardez-le, ne le priorisez pas.** Il est déployé, il ne coûte rien à laisser
en place, et votre analyse est juste : avec l'authentification partagée et le panier
pré-rempli, il n'est plus sur le chemin critique. Il redeviendra utile le jour où l'on
voudra éviter une saisie de mot de passe sur mobile. **Ne le supprimez pas, ne le
développez pas maintenant.**

**D-22 (`DETTE.md`) — les liens app → site. Mesuré le 02/08 à 09 h 01 :**

- `https://www.oxvehicle.fr/compte-sessions` → **200**, et le HTML servi contient bien
  `id="page-compte-sessions"`. **Fermé.**
- `https://www.oxvehicle.fr/share/{jeton}` → **200**, mais le HTML en production **ne
  contient pas encore `id="page-share"`** : la page existe, écrite et vérifiée, sur une
  branche non fusionnée. Un lien de partage ouvre donc l'accueil — plus un 404, pas encore
  fonctionnel. **En attente d'un merge, pas d'un développement.**
- `oxvehicle.fr` sans `www` répond **307** vers `www`. Tout client qui suit les redirections
  arrive en 200 ; un client strict verra un 307. Pointez sur `https://www.oxvehicle.fr/…`.

---

## 11. Ce que le site attend de vous

1. **La liste des colonnes de `registrations` que l'application écrit** — sans elle, le
   `REVOKE` qui ferme la faille du § D-07 vous casse. C'est le point le plus urgent.
2. **L'arbitrage sur les cinq contradictions du § 0** (fondateur).
3. **Les valeurs exactes** des trois énumérations partenaires (D-14).
4. **Un mot sur l'URL de paiement** (D-06) et je la construis.

Une question qui n'est pas dans votre dossier, et qui n'est pas la mienne à trancher : une
fonction `generate-debrief-ai` est déployée. La doctrine miroir écrite dans `CLAUDE.md`
proscrit toute figure de débrief par IA **côté pilote**. Si sa sortie reste interne ou
destinée au coach humain, il n'y a rien à dire ; si elle atteint le pilote, c'est à vérifier.
