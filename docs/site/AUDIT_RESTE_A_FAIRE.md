# Audit complet — reste à faire (vérifié code + base, 2026-06-30)

> **GO-LIVE 2026-07-04** : PR #3 (design V3 + HUB + mission PROMPT COMPLET), #4 (hotfix boot) et #5 (visuels) mergées — **oxvehicle.fr sert la version complète (vérifié sur le HTML servi)**. Livré aussi ce jour : accusé candidature (trigger + edge), module admin-emails branché (table `email_templates` créée, surcharges actives sur contact_recu / corporate_recu / candidature_recue), adresses email réelles uniquement (contact@ + corporate@), sécurité P2 A+B appliquée, 65 index FK, vue session_availability.

> Audit fan-out (5 dimensions) vérifié contre `index.html`, `docs/site/`, et la base live `fouvuqkdxarjpjbqnsjq`. **Verdict : le site peut passer en prod — aucun bloqueur P0.** Le P0 historique (faux RIB) est levé ; `OXV_PAYMENT.mode='pending'` (paiement par lien non actif) → tous les manques liés au lien sont hors chemin actif.

## ✅ Corrigé suite à l'audit (avant-prod, livré ici)
- **Faux succès formulaire Founding Members** : `submitFoundingForm` affichait « Candidature envoyée » même si l'insert échouait (console.warn seulement). Corrigé → succès **uniquement** si `error==null`, sinon fallback mailto (pattern aligné contact/corporate/partenaire).
- **RGPD sous-traitant email** : la page Confidentialité attribuait les emails **transactionnels** à Brevo → faux. Corrigé : **Resend** = transactionnel (US, CCT) ; **Brevo** = newsletter (sur consentement). Cohérent avec le code (Resend live, Brevo = stub).
- **Sitemap** : ajout de `/founding`, `/coach`, `/plateau` (pages indexables liées en nav, absentes du sitemap).
- **Doc connexion** corrigé : données app **pas vides** (16 `telemetry_sessions`, 12 `app_session_analyses` réelles ; `registrations.attended`=0 en attente du check-in app).

## 🟡 Avant d'activer le paiement réel (différé, non bloquant pour ce merge)
- Nommer le **PSP** dans CGV/Privacy (placeholder « prestataire PCI-DSS ») **avant** de passer `OXV_PAYMENT.mode='link'`.
- **Edge Function `create-payment-link` + webhook PSP** (sinon aucune confirmation auto ne passe `payments.status='succeeded'`). Aujourd'hui validation manuelle = OK car mode pending.

## 📱 Côté app / équipe app
- **Migration A1** (dépréciation events) : code app `eventsService`/`adminAnalytics`/`dataExport`/`b2bReport` → `sessions`/`registrations` ; repoint FK `b2b_event_reports`/`event_partners`/`telemetry_sessions.event_id` → `sessions.id` ; drop `event_registrations` + `events` (greenfield, 0 donnée). Cf [PR_SITE_DEPRECATE_EVENTS](PR_SITE_DEPRECATE_EVENTS.md).
- Recâblage écrans app (Pass/réservations/QR/galerie) sur le modèle canonique ; confirmer RLS own-row `registrations`/`payments` (authenticated).
- Produire check-in (→ `registrations.attended`) pour allumer le KPI ; deep links `oxvcoach://` (handler + association de domaine) ; `send-session-cancelled` (email annulation).
- **Durcissement P2** (defense-in-depth) : **audit livré 2026-07-04** → [SECURITE_P2_GRANTS_AUDIT.md](SECURITE_P2_GRANTS_AUDIT.md) (36 fonctions anon-exécutables catégorisées, migration prête, en attente d'accord fondateur + regard app) ; listing public buckets `coach-media`/`partner-media` et consolidation `oxv_is_admin()`→`is_admin()` à coordonner avec l'équipe app.
- Convergence médias (galerie app ↔ `media`) + COMP-08 (politique média).
- Hygiène perf DB : **FK non indexées ✅ faites 2026-07-04** (65 index, migration `fk_indexes_perf_p2`, 0 restante) ; reste rls_initplan, policies permissives multiples, index inutilisés — post-lancement.

## 👤 En attente de toi (input/asset/décision)
- **Identité légale** (SIRET / forme sociale / TVA) dans les mentions — dès l'immatriculation.
- **COMP-05 Page Preuves** : photos, témoignages, captures Pass/Trace réels.
- **COMP-06** : rédaction des articles SEO prioritaires (cadre livré). Newsletter Brevo : **chaîne réelle livrée 2026-07-04** ([PR_SITE_12_NEWSLETTER_BREVO.md](PR_SITE_12_NEWSLETTER_BREVO.md)) — il ne manque que ta clé API Brevo + id de liste.
- **Activation paiement** : choix PSP + lien + nom dans CGV.
- **Micro-question B2B** : invité = compte `users` (→ `registrations`) ou invité sans compte (→ `session_guests`).

## ⏭️ Reporté volontairement
- **Design V2** (DESIGN-01→12) — après la fiabilité.
- **PR-19/20** (découpage `index.html`, décision stack) — après stabilisation.
- Finitions P3 (admin sessions PR-09, seed CRM contact, bouton test email, alertes leads non-corporate, stub BLE télémétrie).

## Sécurité (rappel, audité)
Pas de fuite PII (SELECT leads admin-only) ; `sessions_public` definer assumé ; fonctions `admin_*` auto-protégées. WARN advisors restants (`rls_policy_always_true` ×2 = INSERT public formulaires ; `security_definer_view`) **intentionnels**.

**Conclusion : merger la PR #2 après ces correctifs (faits), et NE PAS activer `mode='link'` tant que PSP nommé + webhook livrés.**
