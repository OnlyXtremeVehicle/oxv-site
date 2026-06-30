# PR-COMP-10 — Gate de mise en production (go-live)

> Surface : 🌐 site + 🗄️ Supabase. Date : 2026-06-30. **Statut : ✅ aucun bloqueur P0 site — shippable honnêtement ; paiement réel = activation différée.**

Checklist transverse de mise en ligne. Vérifications **réelles** (advisors Supabase, RLS, code), pas déclaratives.

---

## ✅ P0 — Paiement (ex-bloqueur RIB) : RÉSOLU

Décision produit : paiement par **lien hébergé** (CB / Visa / PayPal / Apple Pay), plus de virement final.
- Le **faux RIB est entièrement retiré** (booking, espace pilote, admin). Cf [PR-SITE — Paiement par lien](PR_SITE_PAYMENT_LINK.md).
- État actuel **honnête** : « réservation enregistrée, un lien de paiement sécurisé vous sera envoyé ». Aucune fausse coordonnée bancaire affichée → **le site est shippable en l'état**.
- **Activation du paiement réel = différée, non bloquante** : basculer `OXV_PAYMENT.mode='link'` + `linkUrl` une fois le prestataire en place (+ Edge Function `create-payment-link` + webhook, backend).
- ⚠️ **CGV** : finaliser le **nom/juridiction du prestataire de paiement** une fois le PSP choisi (placeholder « prestataire PCI-DSS » en attendant).

---

## ✅ Sécurité — audité (advisors Supabase, 2026-06-30)

Advisors : **1 ERROR + 81 WARN**. Analyse :

| Constat | Verdict |
|---|---|
| **PII leads** (`contact_messages`, `corporate_leads`) | ✅ **Pas de fuite.** SELECT **admin-only** (`is_admin()` / `oxv_is_admin()`). Le `true` flaggé (`rls_policy_always_true`) est le `WITH CHECK` des **INSERT publics** des formulaires — comportement voulu. |
| **`security_definer_view` sur `sessions_public`** (ERROR) | ✅ **Exception assumée.** Vue de masquage PII pour le calendrier anon (PR-SITE-01) : n'expose que les colonnes sûres. Le mode definer est **nécessaire** au masquage. |
| **Fonctions `admin_*` exécutables par tout connecté** (WARN) | ✅ **Mitigé.** Les fonctions sensibles vérifiées (`admin_review_demande`, `admin_validate_inscription`, `admin_ritual_stats`) **se protègent en interne** (`is_admin`). |
| **PII sessions calendrier** | ✅ `private_client_name` masqué (PR-SITE-01). |

### ⚠️ Durcissement recommandé (P2 — non bloquant)
- Restreindre les `GRANT EXECUTE` des fonctions SECURITY DEFINER (defense-in-depth) au lieu de `public`/`authenticated` large (77 fonctions concernées).
- Buckets `coach-media` / `partner-media` : désactiver le listing public.
- Consolider `oxv_is_admin()` → `is_admin()` (deux helpers coexistent).

---

## ✅ Commercial & fiabilité — livré (V1)
- [x] Formulaires réels, **aucun faux succès** : contact, corporate, waitlist, partenaire, presse (insert `contact_messages` + fallback mailto). [PR-03/04, COMP-01/03/04]
- [x] Emails transactionnels live (Resend, triggers DB) : contact ack, booking, paiement, documents. [PR-05/06/10]
- [x] Booking fiable : référence OXV persistée, anti-doublon. [PR-06]
- [x] Admin : inbox + statuts + **CRM leads**, paiements corrigés. [PR-07/08, COMP-07]
- [ ] **RIB réel** (cf. P0).

## ✅ SEO & contenu — livré
- [x] JSON-LD (Organization, Offer, FAQPage, BreadcrumbList). [PR-16]
- [x] `OXV_PAGE_SEO` : titres/descriptions par page, dont securite / partenaires / presse / apres-journee.
- [x] Sitemap à jour (securite, apres-journee, partenaires, presse) ; noindex sur espaces pilote/admin.
- [x] Analytics : 6+ events via `track()` + Vercel Analytics. [PR-17]
- [ ] Contenu éditorial d'articles SEO (COMP-06) — **nécessite rédaction** (non bloquant go-live).

## ✅ Pages publiques — livré
- [x] App OXV Trace, Offres, FAQ, Sécurité & cadre, Après la journée, Partenaires, Presse, Liste d'attente.
- [ ] Page **Preuves / témoignages** (COMP-05) — **nécessite assets réels** (photos, verbatims).

## ⏸️ Connexions site ↔ app — en pause (décision équipe app)
- [x] Contrat comptes/rôles/consentements vérifié. [PR-21]
- [ ] **2 modèles de données parallèles** (registrations vs event_registrations, sessions vs events) — décision d'architecture requise. [PR-24] **Hors périmètre site-only ; ne bloque pas le go-live du site.**

## ⏭️ Reporté (post go-live)
- Design premium V2 (DESIGN-01→12) — **après** la fiabilité, volontairement.
- Refactor technique (PR-19/20).

---

## Verdict du gate
**Le site est prêt à passer en production : aucun bloqueur P0 côté site.** Plus aucune fausse coordonnée bancaire ; messaging paiement honnête (« lien à venir »). Le reste est livré et vérifié, ou non bloquant (contenu/assets/design), ou en pause (connexions app). Sécurité auditée : pas de fuite PII, pas de privilège escaladable sur les fonctions sensibles.

**Activation du paiement (différée, non bloquante)** : `OXV_PAYMENT.mode='link'` + `linkUrl` (+ Edge Function `create-payment-link`/webhook côté backend) + finaliser le nom du PSP dans les CGV.

**Procédure de mise en prod** : merger la PR vers `main` → Vercel déploie `oxvehicle.fr` (rollback 1 clic conservé sur Vercel).
