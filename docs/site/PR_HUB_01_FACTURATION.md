# PR-HUB-01 — Facturation client (audit + fondations)

> Surface : 🌐 site + 🗄️ DB + ⚡ Edge Function. Date : 2026-07-01. **Statut : ✅ LIVRÉE** (chaîne complète : trigger → PDF → bucket → email → UI). SIRET en placeholder (décision Q6). **Dernière vérification = 1ʳᵉ validation d'un paiement réel (test fondateur).**

## 1. Audit (vérifié live)
- ❌ Aucune table `invoices`, aucune séquence, aucun bucket facture.
- ✅ `payments.invoice_url` / `invoice_pdf_url` existent (inutilisés) — points de branchement prêts.
- ✅ Patterns éprouvés réutilisables : Edge Functions Resend, triggers pg_net, buckets privés.

## 2. Fondations livrées (migration `invoices_foundation_hub01`, vérifiée)
- **Numérotation séquentielle infalsifiable par année** : table `invoice_counters` + fonction `oxv_next_invoice_number()` (SECURITY DEFINER, **service role uniquement**). Testée : `OXV-2026-0001` → `OXV-2026-0002` ; `authenticated` ne peut PAS l'exécuter (vérifié) ; compteur de test remis à zéro (aucun numéro réel consommé).
- **Table `invoices`** : numéro unique, type facture/avoir (`credit_note_for`), **snapshot immuable** (`seller` jsonb avec SIRET placeholder, `customer`, `lines`, montants en centimes), mention « TVA non applicable, art. 293 B du CGI », `pdf_path`. RLS : le client lit **ses** factures, l'admin tout, **aucune écriture client** (service role only).
- **Bucket privé `invoices`** + policy storage : lecture owner (dossier = son `user_id`) ou admin ; upload service role uniquement.

## 3. Chaîne complète livrée
1. **Edge Function `generate-invoice` v1 déployée** : auth = secret interne (trigger) OU JWT admin ; idempotente par paiement ; snapshot payments/registrations/users/sessions ; numéro via RPC service-only ; **PDF pdf-lib** (A4, en-tête OXV, vendeur avec SIRET placeholder marqué, client, lignes, total, mention 293 B) ; upload bucket privé (`user_id/numero.pdf`) ; insert `invoices` ; maj `payments.invoice_pdf_url` ; **email Resend avec PDF joint** (best-effort, journalisé `email_log`) ; **support avoirs** (`credit_note_for` + raison → montant négatif, même série).
2. **Trigger `trg_payment_invoice`** (actif, vérifié) : `payments.status → succeeded` → pg_net → facture auto. Exception-safe, dormant sans secrets vault.
3. **UI compte** : section « Mes factures » (`#invoiceRows`) — numéro, type, date, montant, bouton **PDF** (`storage.download`, RLS owner). État vide honnête. Note « À savoir » mise à jour (SIRET dès immatriculation, réédition).
4. **UI admin** : « Factures émises » (`#adminInvoiceRows`, 20 dernières, avec nom client) sur admin-paiements.

## 4. Vérifications effectuées
- Numérotation : `OXV-2026-0001`→`0002` puis reset (aucun numéro réel brûlé) ; `authenticated` sans EXECUTE ✅ ; `service_role` avec ✅.
- RLS `invoices` : lecture owner/admin only, zéro écriture client (aucune policy).
- Edge fn : sans auth → **401** (testé HTTP réel) ; via secret (pg_net, secret jamais exposé) → **404 `payment_not_found`** = boot OK, **import pdf-lib chargé**, auth+logique traversées.
- Trigger `trg_payment_invoice` : présent et **actif** (`tgenabled='O'`).
- UI : ids câblés, hooks pages (compte-paiements, admin-paiements), `node --check` OK.

## 5. Critères d'acceptation
- [x] Numérotation séquentielle par année, non falsifiable côté client.
- [x] Schéma facture snapshot + mentions micro-entreprise + RLS stricte.
- [x] Bucket privé + policy lecture owner/admin.
- [x] PDF généré serveur, stocké, téléchargeable depuis le compte (chaîne déployée ; **rendu PDF final à contrôler à la 1ʳᵉ validation réelle — test fondateur : admin → valider un paiement → vérifier email + PDF**).
- [x] Email automatique à la validation du paiement (trigger actif + Resend joint).
- [x] Avoirs supportés (fonction) — bouton admin d'avoir : à ajouter au premier besoin réel.
