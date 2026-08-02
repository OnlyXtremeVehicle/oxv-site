# PR-SITE — Tunnel de réservation app ↔ site (chantier 4)

> Surface : 🌐 site + 🗄️ Supabase. Date : 2026-08-01.
> **Statut : ✅ `pending_payment` branché côté site · 🔴 une faille de privilèges signalée, NON corrigée.**
>
> Partage des rôles rappelé par le document de reprise : **l'application constitue le
> dossier, le site encaisse.**

## 1. `pending_payment` n'existait pas côté site — corrigé

L'énumération `registration_status_enum` vaut, revérifié le 01/08 :
`pending · confirmed · cancelled · attended · no_show · pending_payment`.

**`pending_payment` apparaissait 0 fois dans `index.html`.** Les quatre tables de
libellés (deux dans « Mes sessions » desktop + mobile, une dans l'admin sessions, une
dans le détail pilote) s'arrêtaient à `no_show`, et le repli `|| statusKey` affichait
la valeur brute de l'énumération — `pending_payment` — à un pilote comme à l'admin.

C'est précisément le statut que l'app posera en déposant un dossier à payer. Corrigé :

- libellé **« Paiement attendu »** dans les quatre tables ;
- classes CSS `.session-status.pending_payment` et `.admin-list-pill.pending_payment`
  ajoutées **aux règles existantes de `pending`** — deux états non soldés, distingués
  par le libellé, pas par une couleur inventée.

**Vérifié sans changement nécessaire** : le décompte de capacité, l'anti-doublon et
« mes sessions » filtrent tous en `neq('status','cancelled')` — une règle inclusive.
Un dossier `pending_payment` occupe donc déjà une place, ce qui est la bonne
sémantique. Le chiffre d'affaires admin ne compte que `confirmed`/`attended` : un
dossier non payé n'y entre pas. Aucune de ces logiques n'avait de trou.

## 2. 🔴 Faille de privilèges — signalée, non corrigée

Mesuré en base le 01/08 :

- policy `registrations_update_own_or_admin` : `UPDATE` autorisé quand `user_id = auth.uid()` ;
- grants colonne pour le rôle `authenticated` : `UPDATE` sur **toutes** les colonnes —
  `status`, `price_total`, `price_deposit`, `deposit_paid_at`, `attended_at`, `user_id`…

RLS ne restreint pas les colonnes ; seuls les grants le font. Conséquence :
**tout pilote connecté peut, par un simple `PATCH` PostgREST sur sa propre ligne, se
passer en `confirmed` ou `attended` et réécrire son prix** — sans payer.

C'est la réponse actuelle, et non voulue, à la question « quelles transitions sont
autorisées côté site » : **toutes, par le pilote lui-même.**

**Pourquoi je ne l'ai pas corrigée seul.** Le chemin d'annulation du pilote
(`cancelRegistration`, `index.html`) est un `UPDATE` client direct sur `status`,
`cancelled_at`, `cancelled_by`, `cancellation_reason` : révoquer les colonnes le casse.
Et surtout, **l'app écrit ces mêmes lignes** — révoquer sans coordination casserait la
constitution du dossier côté app. Ce n'est pas un correctif site isolé.

**Correctif proposé** (à valider, puis à appliquer des deux côtés le même jour) :

1. RPC `cancel_registration(p_id uuid)` en `security definer` : seule transition pilote
   autorisée, vérifie `user_id = auth.uid()` et que le statut de départ est
   `pending | pending_payment | confirmed`, écrit `cancelled` + horodatage + auteur.
2. `cancelRegistration` côté site appelle la RPC au lieu de l'`UPDATE`.
3. `REVOKE UPDATE (status, price_total, price_deposit, deposit_paid_at,
   balance_paid_at, attended_at, refund_amount, user_id, session_id, offer_type)
   ON registrations FROM authenticated;`
   Restent modifiables par le pilote : `vehicle_id`, `insurance_option`, `slot_choice`,
   `notes` — ce qui est légitimement son dossier.
4. Côté app : lister ce qu'elle écrit sur `registrations` et router chaque écriture
   restante vers une RPC dédiée ou le service-role.

Tant que ce n'est pas fait, la protection réelle est que la base est en pré-lancement
(14 comptes, 1 inscription) — pas un contrôle.

## 3. Ce qui reste, et ce qui bloque

| # | Manque | État |
|---|---|---|
| 1 | Retrouver à la connexion une demande rédigée dans l'app | **Non bloqué techniquement** : RLS `registrations_select_own_or_admin` permet déjà la lecture, et « Mes sessions » lit `neq cancelled`. Il manque de savoir **ce que l'app écrit exactement** (statut de départ, colonnes remplies, prix posé ou non). |
| 2 | URL de paiement stable | Contrat proposé ci-dessous. |
| 3 | Transitions autorisées côté site | § 2 — la faille doit être fermée avant d'écrire la règle, sinon la règle est décorative. |
| 4 | Propriété du dossier (app tant qu'impayé, site une fois payé) | Règle à acter ; elle se traduira surtout en grants (§ 2) et en statuts. |

**Contrat proposé pour l'URL de paiement** — à valider avant implémentation :

```
https://www.oxvehicle.fr/paiement/{registration_id}
```

Route authentifiée. Non connecté → mémorisation de la cible, connexion, reprise
automatique (mécanisme déjà en place pour `/controle-pilote/{user_id}`). Connecté →
lecture de la `registration` par RLS own-row, affichage référence · session · offre ·
montant · statut, et bouton de règlement piloté par le point de bascule unique existant
`OXV_PAYMENT` (`mode:'pending'` aujourd'hui, donc pas de bouton mort : la page indique
l'état sans promettre un paiement indisponible). Dossier inexistant ou appartenant à un
autre compte → même refus, sans distinguer les deux cas.

Ce contrat n'est pas implémenté : il fixe une forme d'URL, ce qui est un engagement
envers l'app. Un mot de validation et je le construis.
