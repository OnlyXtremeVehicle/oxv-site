# PR-HUB-01 — Facturation client (audit + fondations)

> Surface : 🌐 site + 🗄️ DB + ⚡ Edge Function. Date : 2026-07-01. **Statut : fondations ✅ livrées · PDF/email/UI en cours.** SIRET en placeholder (décision Q6).

## 1. Audit (vérifié live)
- ❌ Aucune table `invoices`, aucune séquence, aucun bucket facture.
- ✅ `payments.invoice_url` / `invoice_pdf_url` existent (inutilisés) — points de branchement prêts.
- ✅ Patterns éprouvés réutilisables : Edge Functions Resend, triggers pg_net, buckets privés.

## 2. Fondations livrées (migration `invoices_foundation_hub01`, vérifiée)
- **Numérotation séquentielle infalsifiable par année** : table `invoice_counters` + fonction `oxv_next_invoice_number()` (SECURITY DEFINER, **service role uniquement**). Testée : `OXV-2026-0001` → `OXV-2026-0002` ; `authenticated` ne peut PAS l'exécuter (vérifié) ; compteur de test remis à zéro (aucun numéro réel consommé).
- **Table `invoices`** : numéro unique, type facture/avoir (`credit_note_for`), **snapshot immuable** (`seller` jsonb avec SIRET placeholder, `customer`, `lines`, montants en centimes), mention « TVA non applicable, art. 293 B du CGI », `pdf_path`. RLS : le client lit **ses** factures, l'admin tout, **aucune écriture client** (service role only).
- **Bucket privé `invoices`** + policy storage : lecture owner (dossier = son `user_id`) ou admin ; upload service role uniquement.

## 3. Reste à livrer (prochaine étape de cette PR)
1. **Edge Function `generate-invoice`** : entrée `{payment_id}` (secret interne + trigger pg_net quand `payments.status → succeeded`) → snapshot depuis payments/registrations/users/sessions → numéro → **PDF via pdf-lib** (Deno) → upload bucket → insert `invoices` → maj `payments.invoice_pdf_url` → **email Resend « votre facture »** (PDF joint).
2. **UI compte** (`compte-paiements`) : liste des factures + téléchargement (`storage.download`, RLS owner).
3. **UI admin** (admin-paiements) : liste, régénération, création d'**avoir** sur annulation/remboursement.
4. Vérifs : PDF réel généré/ouvert, email reçu, RLS storage testée avec 2 comptes, avoirs corrects (montant négatif, référence).

## 4. Critères d'acceptation
- [x] Numérotation séquentielle par année, non falsifiable côté client (fn service-only testée).
- [x] Schéma facture avec snapshot + mentions micro-entreprise + RLS stricte.
- [x] Bucket privé + policy lecture owner/admin.
- [ ] PDF généré serveur (Edge Function), stocké, téléchargeable depuis le compte.
- [ ] Email automatique à la validation du paiement.
- [ ] Avoirs pour annulations.
