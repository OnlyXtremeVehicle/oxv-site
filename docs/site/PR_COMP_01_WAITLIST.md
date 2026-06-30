# PR-COMP-01 — Liste d'attente (pré-lancement)

> Surface : 🌐 site (`index.html`, page Calendrier + admin inbox). Date : 2026-06-30. **Statut : ✅ livré.**

## 1. Objectif
Outil go-to-market prioritaire (V2.1 §1/§9) : capter des prospects qualifiés **avant** que le calendrier soit rempli. La liste d'attente alimente `contact_messages` (source `event_waitlist`), donc s'intègre directement à l'**admin inbox** (PR-07).

## 2. Livré
- **Section « Liste d'attente »** sur la page Calendrier (sous le CTA réservation — là où atterrissent les chercheurs de dates) : prénom, nom, email (requis), téléphone (facultatif), **intérêt** (Access / Signature / Heritage / Corporate / lancement app), département, véhicule, consentement newsletter. Réutilise les classes de formulaire existantes (`.form-grid`/`.form-row`/`.consent`/`toggleConsent`).
- **`submitWaitlist()`** : mirroir exact du pattern fiabilisé `submitContact` :
  - insert **réel** dans `contact_messages`, `source='event_waitlist'`, `metadata { preference, departement, vehicule, newsletter }`, `phone` en colonne ;
  - **aucun faux succès** (succès uniquement après insert OK), toast d'erreur sinon, état loading sur le `<span>` du bouton ;
  - `track('join_waitlist', { preference })` (analytics PR-17).
- **Admin inbox** : source `event_waitlist` ajoutée au label (« Liste d'attente ») + option de **filtre** dédiée → l'admin traite les inscriptions comme les autres leads (statuts, notes, mailto).

## 3. Vérification
- Câblage : `submitWaitlist` défini (1), 8 ids `wl-*`, `event_waitlist` présent (payload + label + filtre + option), bouton `#page-calendrier .btn-primary.btn-lg` unique.
- Chemin d'insert **identique** à `submitContact`/`submitCorporate` (déjà vérifiés en adversarial + prouvés en prod) : RLS `contact_messages_insert_public` autorise l'insert anonyme ; `source` est une colonne texte libre ; `metadata` jsonb.
- Helpers utilisés (`toggleConsent`, `track`, `toast`, classes `.consent/.form-row`) tous existants.

## 4. Critères d'acceptation
- [x] Liste d'attente alimente `contact_messages` (source `event_waitlist`) avec preference/département/véhicule/email/téléphone/consentement.
- [x] Aucun faux succès ; erreur visible.
- [x] Visible et filtrable dans l'admin inbox.

## 5. Suivi
- Email d'accusé liste d'attente : le trigger `trg_contact_message_ack` enverra l'accusé `send-contact-ack` à l'inscrit (générique « message reçu ») — un template waitlist dédié pourrait être ajouté plus tard (optionnel).
- Le plan V2.1 évoque une table `waitlist_entries` alternative : non retenue (centralisation `contact_messages` cohérente avec l'inbox + le CRM).

**Verdict : ✅ PR-COMP-01 livrée.** Prochaines V2.1 site-only : COMP-02 (Sécurité & Cadre), COMP-04 (Partenaires), COMP-05 (Preuves), COMP-09 (Après-journée).
