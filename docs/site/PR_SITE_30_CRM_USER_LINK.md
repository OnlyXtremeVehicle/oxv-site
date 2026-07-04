# PR-SITE-30 — Lien messages entrants ↔ compte connecté (CRM)

> Surface : 🌐 site + 🗄️ DB. Date : 2026-07-04. **Statut : ✅ LIVRÉE** (durcissement policy en attente d'accord fondateur).

## 1. Problème
Les 6 formulaires publics (contact, corporate, liste d'attente, partenaire, presse, founding) écrivent dans `contact_messages` sans lien avec le compte : un client connecté qui écrit n'était pas relié à son dossier (réservations, documents, paiements) dans l'inbox admin.

## 2. Livré
- **Migration `contact_messages_user_id_col_site30`** (additive, zéro impact app) : colonne `user_id uuid references users(id) on delete set null` + index partiel + commentaire.
- **Capture côté site** : helper `oxvCurrentUserId()` (lit la session Supabase en mémoire, `null` si visiteur) branché sur les **6 payloads** d'insertion. Visiteur non connecté → `user_id = null`, comportement inchangé.
- **Inbox admin** : `user_id` ajouté au select ; badge vert **« Compte »** sous l'email dans la liste, **« Compte client lié »** dans la modale.

## 3. Vérifié empiriquement (rôles réels, lignes de test supprimées après)
- Anon + `user_id null` (cas nominal formulaire) → ✅ insert OK.
- Authentifié + `user_id` = le sien → ✅ insert OK.
- Anon + `user_id` d'un autre compte (usurpation) → ⚠️ **passe encore** : la policy d'insert historique est `with check (true)`.
- JS 3 blocs OK · JSON-LD 9 blocs OK · 64/64 sections.

## 4. Reste à faire (décision fondateur)
Durcir la policy d'insert : `with check (user_id is null or user_id = auth.uid())`.
Effet : un visiteur ne peut plus attribuer un message à un compte qu'il ne possède pas. Aucun formulaire du site n'est impacté (ils envoient `null` ou l'id de la session réelle). Impact app mobile : aucun flux connu n'insère dans `contact_messages` ; le service role n'est pas soumis aux policies. **Bloqué par le classificateur de sécurité tant que l'accord explicite n'est pas donné** — dire « oui durcis la policy contact » pour l'appliquer.

## 5. Critères d'acceptation
- [x] Colonne `user_id` + FK + index (migration additive).
- [x] 6 formulaires capturent le compte connecté (null si visiteur).
- [x] Inbox admin affiche le lien compte (liste + modale).
- [x] RLS testée par rôle, lignes de test nettoyées.
- [ ] Policy d'insert durcie (attente accord).
