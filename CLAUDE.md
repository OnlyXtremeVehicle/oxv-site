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
- La page **coach partenaire** (coach humain diplômé BPJEPS, licence 750 €/saison) est légitime et conservée : le coaching y est exercé par le coach sous sa propre responsabilité, jamais par OXV. Son encadré « Cadre légal » ne doit jamais être affaibli.

### 2.2 Politique multi-circuit
OXV est une plateforme multi-circuit basée à Bordeaux. **Le Circuit de Haute-Saintonge (tracé Beltoise) n'appartient pas à OXV** : il n'est développé que sur sa page dédiée, jamais ailleurs.
- Home, offres, manifeste, contenu générique : circuit-agnostiques. Aucun storytelling Beltoise, aucun chiffre spécifique au tracé (longueur, virages) hors page dédiée.
- Autorisé hors page dédiée : le nom du circuit dans une liste de circuits partenaires, avec lien vers sa page.
- Ne jamais inventer d'autres circuits partenaires : les emplacements non confirmés s'affichent « Sélection en cours ».

### 2.3 Vocabulaire gelé
- **QDI** : 64 occurrences sur le site (recompte réel du 2026-07-04 — l'ancien « ~136 » datait d'une version antérieure). Vocabulaire figé (QDI, marges, 7-segments). **Aucun renommage** avant données réelles de roulage. (Le QDI est abandonné côté app pilote — cela ne concerne pas le site pour l'instant.)
- **Couleurs piliers QDI intouchables** : Trajectoire `#60A5FA` · Fluidité `#FFB703` · Freinage `#E63946` · Accélération `#4ADE80` · Régularité `#C084FC`. Ce sont des couleurs de DONNÉE, jamais de fond.
- **Faucon** : totem strictement interne. Jamais dans le contenu client (pas de « Falcon Eye », « Dive Mode », etc.). Vocabulaire HUD autorisé : Cap, Trajectoire, Anticipation, Visée, Plongée.

### 2.4 Tarifs — grille canonique (modèle v9, validée)
- **Access : 390 € TTC** (HT interne 325 €) · **Signature : 690 € TTC** (HT interne 575 €) · **Heritage : 2 490 € TTC** (HT interne 2 075 €)
- **B2B : Standard 13 000 € HT · Signature 17 000 € HT** — grille strictement INTERNE : sur le site, toujours « sur devis », aucun prix B2B affiché.
- **Licence coach partenaire : 750 € / saison**
- Décisions actées : **Heritage = pack de 4 sessions Signature** (pas de mix demi/pleines) · **capacité 20 pilotes max par session, Access inclus** (la valeur 18 du BP v9 est obsolète).
- Toute autre valeur trouvée dans le repo (README 350/590/890/1 290, anciennes versions) est obsolète : à remplacer par la grille ci-dessus.
- **Promotion** : aucun prix validé dans la grille v9. Ne pas afficher de prix Promotion sans instruction explicite.
- Affichage : la grille B2C est entièrement TTC — mention « TTC » à côté de chaque prix. Le B2B s'exprime en HT. Toute occurrence « 390 € HT » sur le site ou dans les documents est une erreur à corriger en « 390 € TTC ».
- BDD : valeur Heritage = **249 000 centimes** (pas 229 000). Correction à appliquer avant l'ouverture des paiements (~janvier 2027), sur instruction.

### 2.5 Ton éditorial
- Vouvoiement strict. Minimalisme sec façon Ferrari. Pas d'emojis. Pas de superlatifs creux.
- Style de titre de référence : eyebrow monospace + heading avec mot-clé en `<em>` (voir page charte du site).
- Palette validée : fond noir carbone, doré, rouge, blanc. Insigne rouge : favicon, header, footer, signatures — jamais en décoration répétée.

### 2.6 Discipline d'ingénierie
- **Pas de refactoring spéculatif.** Modifications ciblées sur des éléments validés uniquement. La base est bonne : on la développe, on ne la refond pas.
- Avant de modifier une edge function : l'inspecter (`get_edge_function` via MCP Supabase ou lecture du dossier `supabase/functions/`). Les fonctions marquées « ACTIVE » peuvent être des templates non implémentés.
- Toute incohérence structurelle détectée (contradiction de contenu, de prix, de logique) : **la signaler avant de produire**, ne pas la résoudre silencieusement.
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

# QDI — le compte ne doit pas baisser sans instruction explicite
grep -c "QDI" index.html
```

Exception : la page coach partenaire humain et son SEO peuvent contenir « coach » — jamais associé à une IA ni à OXV comme opérateur du coaching.
