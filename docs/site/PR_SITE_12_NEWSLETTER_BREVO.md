# PR-SITE-12 — Newsletter Brevo réelle (dormante sans clé)

> Surface : 🌐 site + ⚡ Edge Function. Date : 2026-07-04. **Statut : ✅ LIVRÉE** — chaîne réelle déployée, en dormance tant que la clé Brevo n'est pas fournie.

## 1. Avant
Le bouton admin « ✉ Newsletter » d'un article était un stub : `console.log` du payload + toast « Brevo à brancher ». Rien ne partait, rien n'était journalisé.

## 2. Livré
- **Edge Function `newsletter-push` v1** (même socle d'auth que `generate-invoice` : JWT admin vérifié serveur OU secret interne) :
  - relit l'article **en base** (jamais le payload client), exige `published = true` ;
  - **idempotence** : une diffusion par article via `email_log` (`email_type='newsletter'`, `metadata.article_id`) ; `force=true` pour re-diffuser après confirmation ;
  - **dormance honnête** : sans `BREVO_API_KEY` + `BREVO_LIST_ID` (secrets Edge à configurer), réponse `brevo_not_configured`, **aucun envoi, aucun faux succès** ;
  - envoi réel : création campagne Brevo (sujet = titre, template HTML sombre aux couleurs OXV, lien `oxvehicle.fr/actualites/<id>`, lien de désinscription Brevo) + `sendNow` + journalisation `email_log` avec l'id de campagne.
- **Site** : `oxvNewsletterPush()` appelle la fonction et affiche l'état réel (envoyée / déjà diffusée → confirmation re-diffusion / Brevo non branché / erreur). Texte d'aide admin mis à jour.

## 3. Vérifié empiriquement (HTTP réel via pg_net, secret jamais exposé)
- Sans auth → **401**.
- Secret + article inexistant → **404 `article_not_found`** (boot + auth + lecture DB traversés).
- Secret + article publié réel → **200 `brevo_not_configured`** (dormance, zéro email parti).
- `node --check` : 3 blocs JS OK.

## 4. Pour activer (fondateur)
1. Créer un compte Brevo (plan gratuit : 300 emails/jour) et une **liste** de contacts newsletter.
2. Fournir la clé API → à configurer en secrets Edge Functions : `BREVO_API_KEY` et `BREVO_LIST_ID` (jamais dans le code).
3. Décision à prendre ensuite : synchronisation automatique des opt-ins du site (`users.notif_newsletter`) vers la liste Brevo — non incluse ici.
