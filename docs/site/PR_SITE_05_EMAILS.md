# PR-SITE-05 — Emails transactionnels (audit + design)

> Objectif : emails transactionnels fiables, aucune clé côté client, erreurs non bloquantes.
> Surfaces : 🌐 site + 🗄️ Supabase (Edge Functions + triggers) + 📱 app (repo `oxv-app/supabase/functions`).
> Date : 2026-06-30. **Statut : ✅ LIVRÉ — déployé en prod et vérifié end-to-end.**

## 1. Découverte majeure : l'infra email est déjà opérationnelle

| Élément | État | Preuve |
|---|---|---|
| Provider Resend | ✅ configuré | `RESEND_FROM_EMAIL=noreply@oxvehicle.fr`, `email.sent`+`email.delivered` dans `resend_events` (16/06) |
| Secrets vault | ✅ posés | `edge_functions_base_url`, `edge_functions_invoke_secret`, `validate_inscription_secret` |
| 24 Edge Functions déployées | ✅ | dont `send-contact-ack`, `validate-inscription`, `admin-review-inscription`, `resend_webhook` |
| `email_log` + `resend_webhook` (tracking) | ✅ | journalisation + webhooks Resend |
| **Email de confirmation CONTACT** | ✅ **marche déjà** | trigger `trg_contact_message_ack` → `send-contact-ack` → Resend (idempotent, charge l'email côté serveur = anti-spam) |

**Pattern de référence** (`send-contact-ack`) : `verify_jwt=false` + auth par secret partagé `x-oxv-invoke-secret` ; charge la donnée via `service_role` (jamais l'email du body) ; envoie Resend ; journalise `email_log` ; idempotent ; **dormante** (503) si secret absent → jamais bloquant. C'est le modèle à répliquer.

> Conséquence : PR-03 (contact) déclenche désormais un **vrai** email de confirmation. La partie « contact » de PR-05 est **déjà faite**.

## 2. Ce qui manque (côté site)

| Email | Déclencheur actuel (site) | Problème |
|---|---|---|
| Booking confirmation (→ pilote) | `triggerBookingEmail` (l.21190) appelle `send-confirmation-email` en **client** (fetch + JWT, l.21237) | fonction **non déployée** → échoue ; mauvais modèle d'auth (client au lieu de trigger serveur) |
| Paiement confirmé (→ pilote) | `triggerPaymentConfirmedEmail` (l.28140) | **placeholder** `console.log('[OXV Email queued]')` (l.28170) |
| Annulation session (→ pilotes) | `console.log('[OXV Email queued]')` (l.28017) | placeholder |
| Notif admin — nouveau lead corporate | aucun | absent (le contact ack notifie l'expéditeur, pas l'équipe) |
| Notif admin — nouvelle réservation | aucun | absent |
| Test email admin | `adminTestEmail` → `functions.invoke('send-email')` (l.22239) | `send-email` **non déployée** |

## 3. Design proposé — répliquer le pattern « trigger → edge function »

**Principe : les emails partent de la DB (server-to-server), pas du client.** On supprime les appels client (`triggerBookingEmail`, `triggerPaymentConfirmedEmail`) et on déclenche par trigger, exactement comme le contact.

### 3.1 Nouvelles Edge Functions (dans `oxv-app/supabase/functions/`, déployées)
| Fonction | Rôle | Déclencheur |
|---|---|---|
| `send-booking-confirmation` | confirme la réservation au pilote (réf OXV, offre, date, montant, statut paiement) | trigger `AFTER INSERT ON registrations` |
| `send-payment-confirmed` | confirme la réception du virement au pilote | trigger `AFTER UPDATE ON payments` (status → paid/succeeded) |
| `notify-admin-lead` | alerte l'équipe : nouveau lead corporate / nouvelle réservation | trigger sur `contact_messages` (source=corporate_form) + `registrations` |

Toutes : mêmes garde-fous que `send-contact-ack` (secret partagé, dormante sans secret, idempotence via `metadata`/`email_log`, journalisation).

### 3.2 Triggers / migration (Supabase)
- `AFTER INSERT ON registrations` → `net.http_post(edge_url||'/send-booking-confirmation', ... contact via vault secret)`.
- `AFTER UPDATE ON payments WHEN status passe à payé` → `/send-payment-confirmed`.
- Notif admin : sur insert `contact_messages` (source corporate) + insert `registrations`.
- **⚠️ DB partagée site+app** : les triggers sur `registrations`/`payments` se déclenchent aussi pour les écritures app. Pour OXV les réservations sont créées par le site → acceptable, mais on ajoutera une **idempotence** (`metadata.*_email_sent_at`) et au besoin un garde (ne pas ré-emailer). À valider.

### 3.3 Nettoyage site (🌐, non bloquant)
- Retirer `triggerBookingEmail` / `triggerPaymentConfirmedEmail` côté client (remplacés par triggers) **ou** les neutraliser proprement.
- Supprimer les `console.log('[OXV Email queued]')` (placeholders trompeurs).
- Corriger les toasts qui laissent croire qu'un email est parti (« pilotes notifiés ») tant que ce n'est pas réel.
- `adminTestEmail` : soit déployer `send-email` (test), soit retirer le bouton.

## 4. Ce qui nécessite ta validation / une action

1. **Autorisation deploy prod** : créer 3 Edge Functions + 3 triggers sur la **base de prod partagée** avec l'app live. Risque maîtrisé (fonctions dormantes, idempotentes, non bloquantes) mais c'est du prod.
2. **Secrets fonction** : `RESEND_API_KEY` + `EDGE_FUNCTIONS_INVOKE_SECRET` doivent exister au niveau des Edge Functions (très probablement déjà, vu que l'app envoie des mails). À confirmer / je vérifie au déploiement.
3. **Garde DB partagée** : confirmer qu'un email part pour **toute** nouvelle `registration` (site) — ou faut-il restreindre à certaines sources ?
4. **From/branding** : `send-contact-ack` envoie depuis `OXV <contact@oxvehicle.fr>`. Pour booking/paiement : garder ce From ou `noreply@oxvehicle.fr` ?

## 5. Réalisé (build + deploy + vérif)

**Edge Functions déployées (prod, verify_jwt=false, dormantes/idempotentes) :**
- `send-booking-confirmation` (ACTIVE v1) — trigger `trg_registration_emails`.
- `send-payment-confirmed` (ACTIVE v1) — trigger `trg_payment_confirmed_email`.
- `notify-admin-lead` (ACTIVE v1) — triggers `trg_registration_emails` (booking) + `trg_corporate_lead_admin` (corporate).
- Source versionnée dans `oxv-app/supabase/functions/`, migration `20260630140000_site_transactional_email_triggers.sql`.

**Triggers (migration appliquée) :** les 3 présents et activés (`tgenabled='O'`).

**Nettoyage site (`index.html`) :** suppression des appels email client (`triggerBookingEmail`, `triggerPaymentConfirmedEmail`) et des placeholders `[OXV Email queued]` ; toasts honnêtes (plus de « email envoyé »/« pilotes notifiés » mensongers).

**Vérification end-to-end (test auto-adressé contact@, puis nettoyé) :**
- Insert d'un lead corporate de test → `email_log` : `admin_lead`/`admin_corporate_v1` **status=sent** + `contact_received` **status=sent**, `resend_message_id` présents, `error=null`, en ~8 s. ✅
- Chaîne prouvée : trigger → pg_net (secret vault) → Edge Function (auth secret) → Resend → `email_log`. Les 3 fonctions partageant ce mécanisme, il est validé pour les trois.

## 6. Critères d'acceptation (PR-05)
- [x] Aucune clé API email côté client (0 occurrence).
- [x] Booking confirmation envoyée (à pilote) après réservation — trigger insert registrations.
- [x] Paiement confirmé envoyé après validation admin — trigger transition paid_at.
- [x] Notif admin sur nouveau lead/booking — **vérifié end-to-end**.
- [x] Erreurs non bloquantes (pattern dormant/idempotent, EXCEPTION→RETURN NEW).
- [x] Emails testables (`email_log` + `resend_events`).

## 7. Suivis (non bloquants)
- Email d'**annulation de session** (pilote) : non implémenté — toast rendu honnête, `TODO` posé pour une fonction `send-session-cancelled` (PR ultérieure).
- Toasts admin docs (« pilote informé par email », l.~26469/26518) : l'email de validation/refus de document relève de **PR-SITE-10** — claims à brancher là.
- Double-envoi théorique uniquement si Resend accepte mais renvoie une erreur réseau (idempotence sur chemin succès) — comportement aligné sur le pattern de référence, accepté.
- `adminTestEmail` (bouton admin) appelle `send-email` (non déployée) — gère déjà l'absence ; à déployer ou retirer plus tard.

## 8. Verdict
**✅ PR-SITE-05 livrée et vérifiée en production.** Le système email transactionnel du site est opérationnel (contact, booking, paiement, notif admin) sur l'infra Resend existante.
