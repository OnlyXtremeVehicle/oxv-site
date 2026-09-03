# CLAUDE.md — Repo oxv-site

Guide permanent pour toute session Claude Code sur ce repo. À lire intégralement avant toute modification.

## 1. Architecture

- **Site = un seul fichier** : `index.html` (~1,3 Mo). HTML + CSS + JS vanilla + Three.js. Router single-page maison (`.page` / `.page.active`, fonctions `goTo()`, `goToAdmin()`, `goToDemande()`).
- **Pas de framework. Pas de build.** N'introduisez ni React, ni bundler, ni découpage en modules sans instruction explicite de Gabin.
- **Déploiement** : Vercel, auto-deploy sur push `main`. Domaine : `oxvehicle.fr`.
- **Backend** : Supabase, projet `fouvuqkdxarjpjbqnsjq` (Frankfurt, EU). Edge functions du site (état 2026-07-04) : `validate-inscription` (approbation/rejet admin + invite Auth + email Resend), `send-contact-ack` + `send-application-ack` (accusés automatiques, surcharge éditoriale via table `email_templates` — module admin-emails ; clés branchées : `contact_recu`, `corporate_recu`, `candidature_recue`), `notify-admin-lead`, `send-booking-confirmation`, `send-payment-confirmed`, `send-document-status`, `generate-invoice`, `pair-app`, `eligibility-reminders`, `feedback-request`, `newsletter-push` (dormante sans clé Brevo). NB : la fonction `send-email` mentionnée dans les anciennes versions de ce document n'a jamais été déployée.
- **Email** : Resend, domaine `oxvehicle.fr` vérifié, expéditeur `contact@oxvehicle.fr`.
- **Admins Supabase** : philippe.bitaube, julie.huet, gabinfillat.

## 2. Règles non négociables

### 2.1 Doctrine miroir (absolue)
OXV n'est pas agréé coaching. Le site et l'app **restituent des faits** ; ils ne dirigent pas, ne conseillent pas, ne prescrivent pas.

- Interdit dans tout contenu à destination du pilote : formulations causales ou prescriptives (« vous devriez freiner plus tard », « votre problème vient de », « améliorez », « corrigez »).
- Autorisé : constat factuel, mesure, comparaison neutre (« vitesse d'entrée virage 3 : 112 km/h · référence session : 118 km/h »).
- Toute figure de « coach IA », « OXV Coach », « débrief par IA » côté pilote est **supprimée**. La formulation de référence : *restitution factuelle de la donnée de roulage*. On affiche la donnée, simplement présentée — rien d'autre.
- La page **coach partenaire** (coach humain diplômé BPJEPS, Espace Coach 550 € TTC/saison) est légitime et conservée : le coaching y est exercé par le coach sous sa propre responsabilité, jamais par OXV. Son encadré « Cadre légal » ne doit jamais être affaibli.

### 2.2 Politique multi-circuit
OXV est une plateforme multi-circuit basée à Bordeaux. **Le Circuit de Haute-Saintonge (tracé Beltoise) n'appartient pas à OXV** : il n'est développé que sur sa page dédiée, jamais ailleurs.
- Home, offres, manifeste, contenu générique : circuit-agnostiques. Aucun storytelling Beltoise, aucun chiffre spécifique au tracé (longueur, virages) hors page dédiée.
- Autorisé hors page dédiée : le nom du circuit dans une liste de circuits partenaires, avec lien vers sa page.
- Ne jamais inventer d'autres circuits partenaires : les emplacements non confirmés s'affichent « Sélection en cours ».

### 2.3 Vocabulaire gelé
- **QDI** : 79 occurrences sur le site (recompte du 2026-08-18 ; 64 au 2026-07-04, l'ancien « ~136 » datait d'une version encore antérieure). Le compte **ne doit pas baisser** — il sert de garde-fou contre une suppression accidentelle de vocabulaire, pas de cible. Vocabulaire figé (QDI, marges, 7-segments). **Aucun renommage** avant données réelles de roulage. (Le QDI est abandonné côté app pilote — cela ne concerne pas le site pour l'instant.)
- **Couleurs piliers QDI intouchables** : Trajectoire `#60A5FA` · Fluidité `#FFB703` · Freinage `#E63946` · Accélération `#4ADE80` · Régularité `#C084FC`. Ce sont des couleurs de DONNÉE, jamais de fond.
- **Faucon** : totem strictement interne. Jamais dans le contenu client (pas de « Falcon Eye », « Dive Mode », etc.). Vocabulaire HUD autorisé : Cap, Trajectoire, Anticipation, Visée, Plongée.

### 2.4 Tarifs — grille canonique (modèle financier v16 du 2026-08-13)
- **Access : 390 € TTC** (HT interne 325 €) · **première session Access : 250 € TTC** (HT 208,33 €) — tarif de découverte, **une seule fois par pilote**, déclenché au premier engagement (et non à la première session effectuée).
- **Signature : 690 € TTC** (HT interne 575 €) · **Heritage : 2 490 € TTC** (HT interne 2 075 €), soit 622,50 € la session.
- **B2B : Standard 13 000 € HT · Signature 18 500 € HT** — grille strictement INTERNE : sur le site, toujours « sur devis », aucun prix B2B affiché. *(La v9 disait 17 000 € pour la Signature ; le modèle v16 dit 18 500 € — écart à confirmer par le fondateur.)*
- **Espace Coach : 550 € TTC / saison**, 0 % de commission sur les prestations du coach. ⚠️ Ne pas confondre avec les **750 € TTC / an du Partenaire Application** : la confusion entre les deux a fait publier 750 € comme licence coach jusqu'au 2026-08-18, JSON-LD compris.
- **L'application OXV Mirror est comprise dans chaque offre, 0 € pour le pilote** (décision fondateur 2026-08-18, conforme au dossier p. 23). Aucun abonnement pilote. **Aucun prix ne doit apparaître sur la page application.** Le rapport QDI est remis à chaque pilote sans condition — toute formulation « avec l'abonnement » est un reliquat à supprimer.
- **Partenaires** : les quatre formats sont décrits sans montant sur le site public ; le contact se fait par courriel à contact@oxvehicle.fr. Les fourchettes du dossier restent internes.
- Décisions actées : **Heritage = pack de 4 sessions Signature** (pas de mix demi/pleines) · **capacité 20 pilotes max par session, Access inclus** (la valeur 18 du BP v9 est obsolète).
- **Formats** : Access = **l'après-midi du lundi (14h–18h), quatre relais** (décision fondateur 2026-08-18 — le créneau du matin est supprimé, CGV comprises). Signature = journée complète du vendredi, six relais.
- **Heritage a perdu un argument** le 2026-08-18 : « un an d'app Mirror inclus » est devenu vide dès lors que l'application est gratuite pour tous. Il reste les quatre sessions, l'économie de 270 €, la priorité de réservation et l'accès anticipé N+1. **Un remplaçant éventuel est une décision commerciale non prise.**
- Toute autre valeur trouvée dans le repo (README 350/590/890/1 290, anciennes versions) est obsolète : à remplacer par la grille ci-dessus.
- **Promotion** : aucun prix validé dans la grille v9. Ne pas afficher de prix Promotion sans instruction explicite.
- Affichage : la grille B2C est entièrement TTC — mention « TTC » à côté de chaque prix. Le B2B s'exprime en HT. Toute occurrence « 390 € HT » sur le site ou dans les documents est une erreur à corriger en « 390 € TTC ».
- BDD : valeur Heritage = **249 000 centimes** (pas 229 000). Correction à appliquer avant l'ouverture des paiements (~janvier 2027), sur instruction.

### 2.4 bis — Écuries et contrôle sonore (décisions du 2026-08-18)
- **Écurie** = une équipe créée par un membre pour **réserver ensemble**. On y entre **par lien d'invitation** : l'invité ouvre le lien, crée son compte, et se retrouve rattaché — sans code à recopier. Une mention nommée (« Vous faites partie de l'écurie X ») lui est transmise et lui ouvre les fonctionnalités. La réservation propose ensuite d'inviter son écurie sur la date choisie.
  - Le modèle « une écurie par marque, adhésion automatique » du dossier d'août est **abandonné**.
  - Mécanique : RPC `oxv_get_my_referral_code` / `oxv_redeem_referral` / `oxv_name_my_crew` (SECURITY DEFINER, aucune écriture directe). Liens `/?ecurie=CODE` et `/?session=ID`, captés au boot, paramètre retiré de l'URL, rattachement sur `SIGNED_IN`.
  - **Les noms des autres membres ne sont pas lisibles côté client** (RLS sur `users`) : on annonce un effectif, jamais une liste.
- **Décibels** : le pilote ne **certifie** pas la conformité sonore de son véhicule — il **reconnaît** qu'un contrôle a lieu sur place et qu'un dépassement de la norme du circuit (98 dB, tolérance 3 dB) entraîne le refus d'accès à la piste, sans remboursement. La norme est **attribuée au circuit**, jamais assertée par OXV.

### 2.5 Ton éditorial
- Vouvoiement strict. Minimalisme sec façon Ferrari. Pas d'emojis. Pas de superlatifs creux.
- Style de titre de référence : eyebrow monospace + heading avec mot-clé en `<em>` (voir page charte du site).
- Palette validée : fond noir carbone, doré, rouge, blanc. Insigne rouge : favicon, header, footer, signatures — jamais en décoration répétée.

### 2.6 bis — Donnée de chronométrage tierce (garde `plateauNonPublic`)
Le paquet de démarrage d'`oxv-app` (30/08/2026) déclare cette garde **bloquante
avant toute mise en ligne**. Elle contraint le site, parce que c'est ici que
vivent les pages publiques.

- **Aucune donnée de chronométrage produite par un tiers ne sort sur une page
  publique du site**, ni sur `/pavillon/accueil`, ni dans un export client. Le
  référentiel de plateau reste interne.
- C'est un **engagement contractuel**, pris dans le courrier à ITS : l'arrêt de
  lecture doit être tenable en une seconde, un dimanche. Une page publique qui
  rediffuserait la donnée le rendrait intenable.
- **État au 2026-09-03 : aucune source tierce n'est branchée sur le site** —
  vérifié, zéro occurrence. La règle protège l'avenir, pas le présent.
- Le grep de §4 ne rattrape que l'évident. Toute page qui afficherait un
  classement, un temps au tour ou une position venus d'ailleurs qu'OXV se
  **relit à la main** avant publication.

### 2.6 ter — Deux décisions prises le 2026-09-03, à ne pas rouvrir
- **Jetons de design partagés : ajournés.** L'étude de design d'`oxv-app`
  demande une source unique `tokens.json` pour les deux dépôts, faute de quoi
  « la divergence deviendra votre allure ». Mesure faite sur ce dépôt :
  **118 couleurs écrites en dur contre 78 variables déclarées** — dont une part
  légitime, les `--pv-*` qui reproduisent la palette de l'application dans ses
  aperçus et qu'on ne corrige pas. Décision fondateur : **on attend que l'app
  publie ses jetons** (sa phase 2, derrière un codemod de 868 usages de
  `fontSize`, donc après Le Mans) pour ne faire le travail qu'une fois.
- **Typographie : la recherche d'`oxv-app` ne rouvre pas l'arbitrage du site.**
  Ses cinq critères (axe `GRAD`, chiffres tabulaires, taille optique,
  désambiguïsation, unité des chasses) sont calibrés pour une tablette au
  camion, en plein soleil, affichant des nombres à 25 Hz. Le site garde son
  propre arbitrage. On en retient la méthode — mesurer, pas choisir.

### 2.6 Discipline d'ingénierie
- **Pas de refactoring spéculatif.** Modifications ciblées sur des éléments validés uniquement. La base est bonne : on la développe, on ne la refond pas.
- Avant de modifier une edge function : l'inspecter (`get_edge_function` via MCP Supabase ou lecture du dossier `supabase/functions/`). Les fonctions marquées « ACTIVE » peuvent être des templates non implémentés.
- Toute incohérence structurelle détectée (contradiction de contenu, de prix, de logique) : **la signaler avant de produire**, ne pas la résoudre silencieusement.
- **Un script de correction doit écrire son fichier même s'il échoue en route.** Une assertion qui lève avant le `write` fait perdre tous les remplacements déjà annoncés « ok » en console. Vérifier le rendu, jamais les logs seuls.
- **Après tout retrait de prix ou de mention, vérifier aussi le JSON-LD et `llms.txt`.** Une page peut être propre à l'œil et continuer d'annoncer un prix aux moteurs de recherche.
- **Tout schéma ou carte SVG se mesure à 375 px de large**, pas à l'œil sur grand écran : un viewBox large y écrase ses libellés à deux ou trois pixels. Reprendre les classes `.oxv-schema-wrap` et `.oxv-schema`.
- Me challenger, pas me valider. Communication directe. Décisions structurantes via prompts de confirmation explicites.
- Logique d'économie unitaire : l'unité de marge est le jour de piste loué, pas l'offre individuelle.

## 3. Conventions de travail

- **Commits** : en français, un lot fonctionnel = un commit. Format : `type: description courte` (`fix:`, `feat:`, `content:`, `style:`, `chore:`). Jamais de `push --force` sur `main`.
- **Modifications de contenu** : privilégier des remplacements exacts (search/replace) et lister chaque chaîne modifiée dans le message de commit ou un rapport.
- **Vérification avant commit** : le router doit fonctionner sur toutes les pages (`page-*`), aucun `console.error` au chargement, grep de contrôle sur les termes interdits (voir §2).
- **Rapport de fin de session** : liste des fichiers touchés, occurrences modifiées, points laissés en attente de validation.

## 4. Greps de contrôle (à exécuter avant chaque commit de contenu)

```bash
# Doctrine miroir — ne doit retourner AUCUNE occurrence côté contenu pilote
grep -n -i "coach ia\|oxv coach\|coaching ia\|par ia\|falcon\|dive mode" index.html

# QDI — le compte ne doit pas baisser sans instruction explicite (79 au 2026-08-18)
grep -c "QDI" index.html

# Aucun tarif pilote pour l'application, aucune trace de l'ancienne licence coach
grep -n "15 €/mois\|150 €/an\|750 €\|avec l'abonnement" index.html
# (« sans abonnement pilote » est la formulation correcte : ne pas la confondre avec un reliquat)

# Chiffres du tracé hors de sa page dédiée (§2.2) — doit rester vide
grep -n "2,2 km" index.html

# Créneau Access du matin — supprimé, doit rester vide
grep -n "9h-13h" index.html

# Garde `plateauNonPublic` (§2.6 bis) — aucune source de chronométrage tierce
# sur une page publique. Doit rester vide.
grep -n -i "plateau_lecture\|plateau_lecteur\|its.chrono\|apex.timing\|live.timing" index.html
```

Exception : la page coach partenaire humain et son SEO peuvent contenir « coach » — jamais associé à une IA ni à OXV comme opérateur du coaching.
