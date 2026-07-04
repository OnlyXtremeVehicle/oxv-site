# PR-HUB-09 — Bilan / tableau de bord admin + export compta

> Surface : 🌐 site (admin-stats). Date : 2026-07-01. **Statut : ✅ livrée.** Aucune migration (lecture via RLS admin existante).

## Livré
- **Chiffre d'affaires** : encaissé (paiements `succeeded`) · en attente (`pending`) · nombre de factures émises (branché sur PR-HUB-01).
- **Pipeline CRM** : compteurs par statut lead (Lead → Contacté → Qualifié → Proposition → Gagné/Perdu) depuis `metadata.crm` (PR-COMP-07).
- **Remplissage** : 8 prochaines sessions, jauge `inscrits/capacité` (sessions privatisées signalées).
- **Export CSV compta** (micro-entreprise) : sélecteur de mois (pré-rempli), un fichier `oxv-compta-AAAA-MM.csv` — factures/avoirs (numéro, date, client, montant) + paiements (référence, date, client, montant, statut). Séparateur `;`, décimales à virgule, BOM UTF-8 explicite (`﻿`) → ouverture Excel propre.
- **Honnêteté** : NPS (attend PR-HUB-07), parrainages (attend PR-HUB-03), conversion visite→réservation (Vercel Analytics) affichés comme « à venir » — l'ancienne mention « Export CSV disponible sur demande » (fausse promesse) est remplacée par le vrai bouton.

## Vérifications
- Ids UI câblés (6/6), `loadAdminBilan` appelé par `loadAdminStats`, `node --check` OK.
- Lectures couvertes par les policies admin existantes (payments/invoices/contact_messages/sessions/registrations) — aucune écriture.

## Critères d'acceptation
- [x] CA encaissé / en attente visibles.
- [x] Remplissage par session.
- [x] Pipeline CRM par statut.
- [x] Export CSV mensuel paiements + factures.
- [x] NPS / parrainages / conversion : affichés honnêtement comme dépendants de leurs modules.
