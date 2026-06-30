# PR-SITE-03 — Contact réel (suppression du faux succès)

> Objectif : le formulaire contact enregistre réellement dans `contact_messages`, avec `source`, états loading/success/error, et **aucun faux succès**.
> Surface : 🌐 site + 🗄️ DB (lecture seule de vérification). Date : 2026-06-30.

## 1. Problème (avant)

`submitContact()` (`index.html`) :
- Le toast de succès « Message envoyé » était **hors du `try/catch/finally`** → il s'affichait **toujours**, même si l'insert Supabase échouait (l'erreur n'était que `console.warn`). → **perte de leads silencieuse** (faux succès).
- Le champ `source` était **absent** du payload.
- État de chargement réduit à `pointerEvents='none'` (aucun retour visuel).
- Si `supabase` était indéfini, l'utilisateur voyait quand même « envoyé ».

## 2. Correctif (après)

- **Succès affiché uniquement après insert réussi** (`if (error) throw error;` puis toast `ok`). Reset des champs + RGPD uniquement en cas de succès.
- **Erreur explicite** en cas d'échec : `toast('Envoi impossible · réessayez ou écrivez à contact@oxvehicle.fr', 'error')` (la classe CSS `.toast.error` existe déjà).
- **`source: 'contact_form'`** ajouté au payload.
- **État loading réel** : le bouton passe à « Envoi en cours… » puis est restauré dans le `finally`.
- `supabase` indéfini → `throw` → message d'erreur (plus de faux succès).

Payload final : `first_name, last_name, email, subject, message, source='contact_form'`.

## 3. Vérifications DB (lecture seule)

- **Schéma `contact_messages`** : colonnes NOT NULL = `first_name, last_name, email, message` (toutes fournies) + `id`/`created_at` (defaults). `source` présent (default `contact_form`), `metadata` jsonb default `{}`. → payload valide. ✅
- **RLS** : policy `contact_messages_insert_public` `WITH CHECK (true)` + grant INSERT à `anon` → le formulaire public (anonyme) peut insérer. ✅
- **Trigger** `trg_contact_message_ack` (SECURITY DEFINER) : sur insert, appelle l'edge function `send-contact-ack` **si** les secrets `edge_functions_base_url` / `edge_functions_invoke_secret` sont définis, sinon `RETURN NEW`. Bloc `EXCEPTION WHEN OTHERS → RETURN NEW` : **ne bloque jamais l'insert**. ✅
  - → **Lien PR-05** : l'accusé de réception email au contact se déclenchera automatiquement dès que les secrets seront posés et l'edge function déployée. Rien à recoder ici.

## 4. Test manuel restant (avant merge)

1. Page Contact, remplir et envoyer → toast succès, champs vidés, et la ligne apparaît dans `contact_messages` (vérifiable via admin une fois PR-07 livrée, ou via Supabase).
2. Simuler une erreur (couper le réseau) → toast d'erreur, **pas** de « envoyé », champs conservés.

## 5. Critères d'acceptation

- [x] Message créé en base avec `source='contact_form'`.
- [x] Aucun faux succès (succès conditionné à `!error`).
- [x] Erreur visible si l'insert échoue.
- [x] État loading sur le bouton.

## 6. Suivi

- `submitContact` n'a pas de champ `phone` (colonne nullable) — OK, non requis.
- Le commentaire périmé `TODO Supabase` (auth, l.~22637) sera nettoyé en PR-SITE-18.

**Verdict : ✅ PR-SITE-03 prête.** Prochaine : PR-SITE-04 (Corporate leads).
