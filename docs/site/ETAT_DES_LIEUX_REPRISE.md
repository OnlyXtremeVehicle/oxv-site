# État des lieux — reprise (prompt maître OXV Platform)

> Date : 2026-07-01. Livrable de la section 10.1 du prompt maître. Tout est vérifié (git réel, base réelle), rien de supposé.

## 1. État git — qui contient quoi

| Branche | Tête | Contenu | Statut |
|---|---|---|---|
| **`main`** (protégée) | `2335fed` | **PRODUCTION oxvehicle.fr** : fiabilisation V1 complète + V2.1 (COMP-01→10) + connexion app (progression) + finitions P3 + réconciliation du travail parallèle du fondateur (email-kit `emk*`, B2B, page charte, circuit 2,2 km) | ✅ déployée Vercel `target:production` |
| **`claude/design-v2`** | `88cf284` | **Refonte DA V3 complète (12/12 lots)** : tokens, typo Space Grotesk/IBM Plex Mono, home réorganisée façon grandes marques (hero→expérience→offres→app→média→confiance→CTA), page `application`, nav 10→5 liens, mockups téléphone, favicons réparés, 5 vars CSS indéfinies corrigées | ⏳ **14 commits d'avance sur main, NON mergée** — merge = décision fondateur |
| `claude/focused-lalande-d05140` | `3180b55` | Branche historique de la fiabilisation (contenu intégralement dans `main` via PR #2) | 🗄️ archivable |
| `feat/validate-inscription` | `815abfa` | Edge function `validate-inscription` réelle (dormante sans secret) — 1 commit jamais mergé | ⚠️ à évaluer/merger ou fermer |
| `hotfix/sessions-public-pii` | mergée (PR #1) ; +1 commit local `a7b7b98` dont le contenu (RPC `get_session_private_client`) est déjà dans main | 🗄️ archivable |
| `claude/retrieve-oxv-progress-lqj5y` | `abc1348` | inconnu (« index.html ») — probablement une récupération ancienne | ⚠️ à inspecter puis supprimer |

- **PR ouvertes : aucune.** PR #1 (hotfix PII) et PR #2 (fiabilisation) mergées.
- **Branche de travail courante : `claude/design-v2`** (la plus avancée). Toute nouvelle PR-HUB se fait dessus ou après son merge.
- ⚠️ Le prompt maître mentionne `refonte-home.html` / `refonte-home-v2.html` : **ces fichiers n'existent ni dans le worktree ni dans `origin/main`** (info périmée — rien à nettoyer).

## 2. Ce qui est FAIT (résumé par rapport aux 53 PR)

- **Phases 0-1 (sécurité + fiabilité)** : ✅ toutes livrées et en prod (PII, RLS, contact/corporate réels, emails Resend via triggers, booking fiable avec référence + anti-doublon).
- **Phase 2 (connexions)** : PR-21 ✅ · PR-24 ✅ décision **A1 verrouillée** (canonique = `sessions`/`registrations` ; `events` déprécié, COMMENT posés en base, plan de migration app documenté) · page « Ma progression » lit réellement `telemetry_sessions`/`app_session_analyses` (16/12 lignes réelles) · PR-22/23/26/27/28/29 = **écrans/flux côté app** (dépôt absent).
- **Phase 3 (admin)** : PR-07 inbox ✅ · PR-08 paiements ✅ · PR-09 édition sessions ✅ · PR-10 docs+emails ✅ · COMP-07 CRM ✅ (+ seed auto + alertes admin tous leads).
- **Phase 4 (conversion)** : PR-13→17 ✅ · COMP-01→06, 09 ✅ (waitlist, sécurité, presse, partenaires, preuves, 6 articles SEO, après-journée→« Votre journée »).
- **Phase 5 (design V2)** : ✅ **12/12 lots livrés** sur `claude/design-v2` (cf `docs/design/PR_DA_RECAP.md`) — **non mergée**.
- **Capstone COMP-10** : ✅ gate documentée, aucun bloqueur P0 site (`AUDIT_RESTE_A_FAIRE.md`).
- **Phase 6 (PR-18 ✅ / 19 / 20)** : découpage + ADR architecture **non faits** (planifiés étape 7 du prompt maître).

## 3. État réel de la base Supabase (vérifié live)

- Canonique : `sessions` (44) · `registrations` (5, attended=0) · `payments` (2) · `users` (14) · `heritage_packs`.
- App : `telemetry_sessions` (16) · `app_session_analyses` (12) · `laps`, `weather_snapshots` · famille `events` **vide et dépréciée (A1)** — FK B2B encore à repointer côté app.
- Edge Functions : send-contact-ack, send-booking-confirmation, send-payment-confirmed, notify-admin-lead **v2** (booking/corporate/waitlist/partner/press), send-document-status + `validate-inscription` (branche non mergée).
- Sécurité : advisors passés — pas de fuite PII ; WARN restants documentés intentionnels ; durcissement P2 en backlog (grants EXECUTE, buckets listables, `oxv_is_admin`→`is_admin`).
- `OXV_PAYMENT.mode='pending'` (aucun PSP actif) — conforme garde-fou §7.

## 4. Écarts entre le prompt maître et l'existant (à trancher — cf bloc questions)

| # | Sujet | Prompt maître | Site/base actuels |
|---|---|---|---|
| E1 | **Prix des offres** | Access **350 €** · Signature **590 €** · **Promotion 890 €** · Heritage **1 290 €** | Access **390 €** · Signature **690 €** · Heritage **2 490 €** (pack 4 sessions) ; « Promotion » existe en enum DB mais pas en offre publique |
| E2 | **Nom public de l'app** | **OXV Mirror** | **OXV Trace** partout (home, page application, footer) |
| E3 | **Doctrine scoring** | « pas de scoring **QDI** » | Le site a un système QDI complet (score /100, 5 piliers, page progression, section home, article SEO `/actualites/qdi`) |
| E4 | **Modèle éco app** | SaaS micro-entreprise : pilote ~15 €/mois ou 150 €/an ; coach 750 €/saison (Phase 1 2027) | Le site présente l'app comme incluse (« app premium illimitée » dans Heritage) ; pas de page tarifs app ; licence coach 750 € présente sur la page coach ✅ |
| E5 | Ordre design | « pas de refonte avant fiabilité » (design = étape 6) | La fiabilité **est faite** et le design V2 **aussi** (branche) — cohérent, mais merge à décider |

## 5. Prochaines étapes (ordre du prompt maître §5, adapté à l'état réel)

1. ✅ Ce document + roadmap mise à jour (PR-HUB intégrées).
2. Phase 1 fiabilité : **déjà en prod** → rien.
3. Écosystème : **PR-HUB-04** (liaison compte site↔app : code d'appairage) — *première PR, aucune dépendance fondateur*.
4. Exploitation : **PR-HUB-02** (éligibilité — checklist à valider) et **PR-HUB-01** (factures — SIRET en placeholder autorisé) puis PR-HUB-09, PR-HUB-05.
5. Croissance : PR-HUB-07, 06, 03, 08.
6. PR-HUB-10 : ≈ fait (design V2) → reste **merge + Lighthouse ≥ 90 + visuels réels après shooting**.
7. Dette : PR-SITE-19/20 (ADR découpage/architecture).
8. Gate COMP-10 re-passée avant push marketing.
