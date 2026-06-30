# PR-COMP-04 — Page Partenaires + formulaire

> Surface : 🌐 site (`index.html` page + footer + sitemap + admin inbox). Date : 2026-06-30. **Statut : ✅ livré.**

## 1. Objectif
Distinguer **Corporate** (achète une expérience) de **Partenaire** (apporte une offre/service/présence à l'écosystème) — V2.1 §5. Capter des leads partenaires qualifiés et structurés.

## 2. Livré
- Nouvelle page publique **`page-partenaires`** (route `goTo('partenaires')`) : 6 types de partenaires (garage/préparateur, photographe/vidéaste, hôtel/restaurant, transport/stockage, assurance/équipementier, concession) + formulaire de candidature.
- **`submitPartner()`** : insert réel `contact_messages`, `source='partner_form'`, `metadata { company, partner_type, zone, details }`, `phone` en colonne. Pattern fiabilisé (validation, pas de faux succès, état loading, **fallback mailto**, `track('submit_partner')`).
- **Admin inbox** : source `partner_form` (label « Partenaire » + filtre dédié).
- **Footer** : lien « Partenaires ». **Sitemap** : `/partenaires`.

## 3. Vérification
- page-partenaires (1), submitPartner (1), `partner_form` (payload+label+filtre+option), 8 ids `pt-*`, lien footer, sitemap, **48/48 `<section>` équilibrés**.
- Chemin d'insert identique aux formulaires déjà vérifiés (contact/corporate/waitlist) ; helpers existants (toggleConsent/track/toast) ; classes existantes.

## 4. Critères d'acceptation
- [x] Page Partenaires distincte du Corporate, 6 types présentés.
- [x] Leads partenaires structurés (metadata company/type/zone/details) dans l'inbox.
- [x] Aucun faux succès ; fallback mailto.

## 5. Suivi
- Table `partner_leads` existe en base mais non retenue (centralisation `contact_messages` cohérente avec l'inbox + CRM). À déprécier ou à brancher si l'équipe préfère une table dédiée.

**Verdict : ✅ PR-COMP-04 livrée.** V2.1 restantes : COMP-09 (Après-journée), COMP-03 (Presse), COMP-05 (Preuves — assets réels), COMP-06 (contenu SEO), COMP-07 (CRM statuts), COMP-10 (gate go-live).
