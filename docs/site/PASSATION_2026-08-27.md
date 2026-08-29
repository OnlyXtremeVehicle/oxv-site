# Passation — séance du 27/08/2026

> Ce document existe pour qu'une conversation neuve reprenne le site sans avoir
> à redécouvrir ce qui a bougé. Il est écrit dans l'ordre de ce qui casse : la
> base peut désormais **refuser** des écritures que le site faisait sans
> résistance, et c'est ce qu'il faut lire en premier.

---

## 1. Ce que la base refuse maintenant, et qu'elle acceptait hier

Six déclencheurs ont été posés en production. Tous rendent `errcode`
`check_violation` (**23514**) ou `42501`, que le tunnel intercepte déjà autour de
la ligne « Violation de la contrainte unique ». **Le message d'exception est
rédigé pour être lu par un membre** : le remonter tel quel vaut mieux que le
remplacer par « une erreur est survenue ».

### `registrations` — plancher de prix

`registrations_plancher_de_prix` refuse une inscription dont `price_total` est
sous le tarif catalogue le plus bas, remise déduite.

**Le motif d'origine** : `pricing` n'était contrôlé nulle part, le prix était
écrit depuis le navigateur, et **deux inscriptions confirmées à 0 €** existent en
production. Elles viennent de la ligne `access` / `full_day` 2027, présente mais
`active = false` : la RLS ne la rend pas au navigateur, `bkComputePrice` retourne
alors 0.

> **Point ouvert.** Tant que cette ligne reste inactive, une réservation Access
> sur une journée complète est désormais **refusée** au lieu d'être facturée 0 €.
> C'est mieux, mais ce n'est pas neutre : si cette combinaison doit se vendre, il
> faut activer la ligne tarifaire.

### `registrations` — remise justifiée

`registrations_remise_justifiee` conditionne `remise_pct > 0`. Depuis un compte
pilote, la seule remise acceptée est `remise_motif = 'ecurie'`, au plus 10 %, et
elle exige :

- `crew_id` renseigné sur l'inscription ;
- une ligne `reservations_ecurie` au statut `confirmee` portant **la même écurie
  et la même journée** ;
- que le pilote appartienne effectivement à cette écurie.

**Le site ne pose encore ni `crew_id` ni `remise_pct`** dans `regData`. Tant
qu'il ne le fait pas, aucune remise ne s'applique — et c'est l'état sûr.

### `sessions` — journée vendable

`sessions_vendable_a_quelqu_un` refuse une journée dont aucune formule ouverte
n'accueille aucune classe admise. Exemple : journée complète proposant Signature
seule, restreinte à la classe I. Signature n'est ouverte qu'aux classes II et III
— la journée occuperait une date de piste sans pouvoir être réservée.

### `sessions` — classe déjà inscrite

`sessions_classe_inscrite_protegee` refuse de retirer une classe pour laquelle
des inscriptions non annulées existent sur cette journée. Le message nomme les
classes et les effectifs concernés.

### `registrations` — les deux verrous de classe

`registrations_offre_ouverte_a_la_classe` porte **deux** contrôles cumulatifs :

1. la formule est-elle ouverte à la classe (`offres_classes`) ;
2. la journée admet-elle cette classe (`sessions.classes_admises`).

Aucun ne rattrape l'autre.

### `crew_members` — le rôle n'est plus saisi

`crew_members.role` est désormais **déduit** de `crews.captain_id` par
déclencheur. Écrire `'captain'` sur un membre ordinaire est corrigé en silence.
Ne comptez plus sur `role` comme sur une donnée qu'on pose.

---

## 2. Ce qui a changé dans `index.html`

Sept commits, dans l'ordre.

| Commit | Ce qu'il fait |
|---|---|
| `03439b0` | L'étape véhicule et le périmètre de service (antérieur à la séance) |
| `4364203` | `registrations.immatriculation` figée · `bkNormalisePlaque` ne mutile plus les plaques hors SIV |
| `f8259d4` | Classes admises à la création **et** à la modification d'une journée · le tunnel les respecte · Heritage rejoint la montée en gamme · les deux retours anticipés supprimés |
| `effac1b` | `attendedCount` rejoint la remise à zéro de `bkOpen` — 140 € d'écart par dossier |
| `9f5ae58` | Intentions écartées (« Prévenez-moi ») · compteur d'impact d'une restriction · les journées trop proches se disent |
| `c6f8900` | Heritage sans pack ne fait plus planter la confirmation |
| `9fb0dbd` | Enregistrement d'un pack Heritage côté admin · textes publics alignés sur la réalité tarifaire |

**Ces sept commits ne sont pas poussés.** `main` est la production Vercel.

### Deux points de vigilance dans le code

- `bkRenderSessions` initialise désormais `container.innerHTML = ''` puis
  complète avec `+=`. Toute reprise doit conserver cet ordre : les journées
  grisées s'ajoutent **après** les journées ouvertes.
- La carte grisée est passée de `<button>` à `<div>` — elle contient maintenant
  un bouton, et un bouton ne s'imbrique pas dans un bouton. Un sélecteur qui
  ciblerait `button.bk-date` ne la trouve plus.

---

## 3. Ce qui reste à faire côté site

1. **Poser `crew_id` et `remise_pct` dans `regData`** quand une réservation
   d'écurie confirmée couvre la journée. Sans cela, le −10 % n'existe que dans
   les textes.
2. **Décider du sort de `access` / `full_day`** : activer la ligne tarifaire, ou
   cesser de proposer Access sur une journée complète.
3. **Instruire les demandes d'écurie** : `reservations_ecurie` a ses droits
   d'administration mais aucun écran. Le fil de l'app dépose ; personne ne
   répond.
4. **Lire les intentions écartées** : `intentions_journee` se remplit, rien ne
   l'affiche.
5. **Parcourir le tunnel à la main** avant de pousser. Aucun de ces sept commits
   n'a été éprouvé de bout en bout avec un compte réel.

---

## 4. Les fichiers à joindre à une conversation site

**Le nécessaire**

- `CLAUDE.md` — les instructions du dépôt site
- `index.html` — le site entier (1,9 Mo, fichier unique)
- `docs/site/PASSATION_2026-08-27.md` — ce document

**Le contexte de réservation et d'écurie**

- `docs/site/PR_SITE_06_BOOKING.md`
- `docs/site/PR_HUB_02_ELIGIBILITE.md`
- `docs/site/PR_HUB_03_PARRAINAGE_ECURIES.md`
- `docs/site/PR_SITE_21_CONTRAT_COMMUN.md`
- `docs/site/ROADMAP_MASTER.md`

**Les arbitrages du fondateur**

- `docs/site/decisions/` — les quatre documents

**Depuis le dépôt de l'application** (le schéma vit là-bas)

- `supabase/migrations/APPLIQUEES_EN_PRODUCTION.txt` — le registre complet
- `docs/architecture/05_SCHEMA_SUPABASE_ACTUEL.md`
- `docs/architecture/06_RLS_POLICIES_ACTUELLES.sql`

> `index.html` fait 38 000 lignes. Une conversation qui ne travaille que sur le
> tunnel de réservation gagne à recevoir d'abord ce document, puis le fichier —
> plutôt que l'inverse.

---

## 5. Arbitrage du 28/08/2026 — l'app fait le paddock, le site fait le bureau

Les deux postes ont bâti l'instruction des sorties d'écurie le même jour : le
site (commit `f5efff3`, à partir de ce document) et l'application. Le fondateur
a tranché la duplication.

**Le site garde l'instruction des écuries.** L'écran équivalent a été retiré de
l'application (`app/(admin)/ecuries.tsx` et son service), et la file de l'app
n'affiche plus le domaine `ecurie`.

### Ce que le site peut reprendre tel quel

`public.oxv_file_administration()` rend, en un appel, tout ce qui attend une
main côté administration. Elle est **complète** — le domaine `ecurie` y figure
toujours — et n'est filtrée que côté application. Le site ne l'utilise pas
encore ; elle couvrirait quatre postes qu'il n'a aujourd'hui aucune surface
pour montrer :

| Domaine | Ce qu'il signale |
|---|---|
| `intentions` | Les pilotes écartés qui ont demandé à être prévenus, groupés par journée. Le site écrit dans `intentions_journee` ; personne ne les lit. |
| `journee_a_valider` | Les journées `proposee` créées par un dépôt d'écurie, à valider sous sept jours. `echeance` porte la date. |
| `calendrier` | Aucune journée publique au calendrier — le tunnel n'a rien à proposer. |
| `tarif` | Une combinaison offre × format sans ligne tarifaire active. |

Elle rend deux notions de délai qu'il ne faut pas confondre :

- `sous_engagement` = le poste court sous les **72 h ouvrées** des CGV. Le délai
  se CALCULE, et l'unique implémentation vit dans l'application
  (`examenSuiviLogic.etatDelai`). Un portage sur le site doit la réécrire —
  ou mieux, ne pas la réécrire et se contenter d'un âge.
- `echeance` = une date **déjà arrêtée en base** (sept jours de validation).
  Elle se LIT, elle ne se calcule pas.

### Colonnes nées après le commit du site

L'écran d'écurie du site ne les affiche pas encore :

- `reservations_ecurie.echeance_inscriptions` — au-delà, les places non prises
  retournent au calendrier. **La réservation est évaluée à la lecture** : pas
  de tâche planifiée, donc pas d'état qui dérive.
- `sessions.validation_due_le` — les sept jours d'une journée `proposee`.
- `public.oxv_avancement_ecurie(crew_id)` — combien annoncés, combien inscrits,
  combien restent. Un COMPTE, jamais des noms.

### Ce que l'application garde

Les examens de véhicule (`app/(admin)/examens-vehicule.tsx`) : le site **écrit**
dans `demandes_examen_vehicule` mais n'a aucun écran pour les instruire. Pas de
duplication — et regarder un véhicule est un geste de paddock.

---

## 6. Vérification du 29/08/2026 — la méthodologie QDI, et ce qu'elle promettait

`docs/site/QDI_METHODOLOGIE.md` a été **vérifié point par point, puis supprimé**.
Son point 5 demandait de porter la correspondance branche → formule dans le dépôt
de l'application ; c'est fait, et le document y vit désormais :
**`docs/architecture/21_QDI_METHODOLOGIE.md` (dépôt app)** — à côté des formules
qu'il décrit. Une garde (`src/__tests__/qdiMethodologie.guard.test.ts`) tient
l'accord entre les deux.

### Ce que la vérification a trouvé, et qui était publié

**1. Le site annonçait des capteurs qui n'existent pas.** La Fluidité était
présentée comme la « régularité des inputs volant », le Freinage comme
« modulation, relâche au corde ». Le boîtier fournit GPS + centrale inertielle à
25 Hz : **ni volant, ni pédales, ni pression de frein**. Le code de l'application
l'assume explicitement depuis toujours ; le texte public, non.

Les cinq encarts piliers et le paragraphe « Méthodologie & références » ont été
réécrits sur ce que le boîtier mesure réellement. Le paragraphe **dit maintenant
l'absence de capteurs**, au lieu de la contourner — c'est un argument premium, pas
un aveu.

**2. « Le QDI du plateau » n'affichait pas de QDI.** La vue `qdi_public` ne porte
aucune branche : ses colonnes sont `display_name`, `nominative`, `margin_global`,
`margin_zone`, `computed_at`, `sessions_count`. Le bloc affichait la **marge** sous
un titre de QDI, avec un score sur 100 en or.

Renommé « **La marge du plateau** ». `#plateauQdi` → `#plateauMarge`,
`loadPlateauQdi` → `loadPlateauMarge` (les 4 occurrences, aucune autre référence).
Le nom de la vue reste `qdi_public` — le renommer en base casserait la lecture
anonyme ; le commentaire du bloc explique l'écart.

### Ce qui reste, et qui est un arbitrage produit

La page Progression affiche cinq piliers **pondérés** — Trajectoire 30 %, Fluidité
25 %, Freinage 20 %… — sur des valeurs d'exemple. **Cette pondération n'existe pas
dans le code** : `computeQdi` rend cinq branches indépendantes et ne compose aucun
score global. Soit la maquette retire les pourcentages, soit un composite est
décidé et implémenté avec un incrément de `QDI_ALGO_VERSION`. Ce n'est pas une
correction à faire seul.
