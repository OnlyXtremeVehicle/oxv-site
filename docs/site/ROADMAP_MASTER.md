# OXV — Roadmap maître consolidée (V1 + V1.1 + V2)

> Document d'orchestration unique pour les 3 dossiers :
> - **V1** Plan d'action (fiabilisation) — PR-SITE-01 → 20
> - **V1.1** Connexions site ↔ app + média — PR-SITE-21 → 31
> - **V2** Refonte esthétique premium — PR-DESIGN-01 → 12
> Date : 2026-06-30. Branche de travail : `claude/focused-lalande-d05140`.

## Principe directeur (commun aux 3 dossiers)
> Le site **vend** l'expérience. L'app **prolonge** la trace. L'admin **livre** les médias. Le client **retrouve** son histoire dans l'app.

**Ordre non négociable :** sécuriser → fiabiliser commercialement → connecter à l'app → administrer → convertir → moderniser le design → nettoyer/refactorer. **Pas de refonte design avant la fiabilité. Pas de migration framework prématurée.**

---

## 1. Les 3 surfaces (cadrage du périmètre)

Chaque PR touche une ou plusieurs surfaces. C'est **déterminant** pour savoir ce que je peux livrer ici :

| Surface | Ce que c'est | Mon accès dans cette session |
|---|---|---|
| 🌐 **Site** | `index.html` (ce repo) | ✅ Total |
| 🗄️ **DB** | Supabase `oxv-platform` (**partagé site + app**) | ✅ Total (MCP : SQL, migrations, RLS) |
| 📱 **App** | App mobile OXV (**autre dépôt**) | ❌ Absent de cette session |

> **Bonne nouvelle structurante :** le site et l'app partagent **le même Supabase**. Les tables (`events`, `registrations`, `sessions`, `devices`, `subscriptions`, `vehicles`, `documents`, `telemetry_sessions`, `media`, `session_media`, `media_exports`) et les buckets (`session-media`, `pilot-media`, `coach-media`…) existent déjà. Les « connexions » V1.1 sont donc surtout du **câblage sur une base unifiée**, pas une intégration à créer.
>
> **Conséquence :** pour les PR « connexions » (21-31), je livre **site + DB + contrat de données** ici ; les **écrans app** restent à faire dans le dépôt app (je fournis les vues/RPC et la doc d'intégration prêtes à consommer).

---

## 2. Programme en 7 phases

### ✅ Phase 0 — Sécurité (FAIT)
| PR | Surface | Statut |
|---|---|---|
| PR-SITE-01 PII sessions | 🌐🗄️ | ✅ Fait (calendrier→`sessions_public`, nom privé via RPC) |
| PR-SITE-02 Audit RLS | 🗄️ | ✅ Fait (RLS saine, durcissement grants anon appliqué) |

### 🔜 Phase 1 — Fiabilité commerciale (P0) — *prochaine*
| PR | Objet | Surface |
|---|---|---|
| PR-SITE-03 | Contact réel (supprimer faux succès, `source`) | 🌐🗄️ |
| PR-SITE-04 | Corporate leads (metadata structurée, source harmonisée, table cible) | 🌐🗄️ |
| PR-SITE-05 | Emails transactionnels (Edge Functions, Resend en secret) | 🌐🗄️ |
| PR-SITE-06 | Booking fiable (RIB réel, anti-doublon, enum paiement, référence) | 🌐🗄️ |

### 🔗 Phase 2 — Connexions site ↔ app (P0) — *socle écosystème*
| PR | Objet | Surface |
|---|---|---|
| PR-SITE-21 | Contrat commun comptes/rôles/consentements (matrice rôle×accès) | 🗄️📱 |
| PR-SITE-22 | Réservation site visible dans l'app | 🗄️📱 |
| PR-SITE-23 | Pass OXV dérivé de `registration` (QR, check-in, statuts) | 🗄️📱 |
| PR-SITE-24 | Sessions site ↔ Events app (unifier les calendriers) | 🗄️📱 |
| **PR-SITE-27** | **Flux média admin site → app client (prioritaire)** | 🌐🗄️📱 |

### 🛠️ Phase 3 — Administration (P1)
| PR | Objet | Surface |
|---|---|---|
| PR-SITE-07 | Admin inbox (`contact_messages` : lecture, statuts, filtres) | 🌐🗄️ |
| PR-SITE-08 | Admin paiements (unifier validation + registration) | 🌐🗄️ |
| PR-SITE-10 | Admin documents (notif email validation/refus) | 🌐🗄️ |
| PR-SITE-25 | Documents & véhicules partagés site/app | 🗄️📱 |
| PR-SITE-26 | Paiement synchronisé dans le Pass app | 🗄️📱 |
| PR-SITE-28 | Admin bridge : réservation validée → participant event app | 🗄️📱 |
| PR-SITE-29 | Emails site + notifications app (silence en roulage) | 🗄️📱 |

### 📈 Phase 4 — Conversion & contenu (P1/P2)
| PR | Objet | Surface |
|---|---|---|
| PR-SITE-13 | Page App OXV Trace (Pass, Trace, Data Lab, Carnet, Saison) | 🌐 |
| PR-SITE-14 | Offres claires (public, durée, inclus/non, prix, CTA) | 🌐 |
| PR-SITE-15 | FAQ conversion (niveau, assurance, données, paiement, annulation) | 🌐 |
| PR-SITE-11 | Admin médias réel (upload Storage vs URL) | 🌐🗄️ |
| PR-SITE-12 | Articles Supabase (libellés trompeurs, newsletter Brevo) | 🌐🗄️ |
| PR-SITE-16 | SEO enrichi (Organization, Event, FAQPage, Offer, BreadcrumbList) | 🌐 |
| PR-SITE-17 | Analytics conversion (6 événements clés) | 🌐 |
| PR-SITE-30 | Support/contact unifié (lier message ↔ user_id) | 🗄️📱 |
| PR-SITE-31 | Analytics cross-platform (site → réservation → app) | 🌐🗄️📱 |

### 🎨 Phase 5 — Refonte esthétique premium (V2)
| PR | Objet | Prio |
|---|---|---|
| PR-DESIGN-01 | Audit visuel + design inventory (`docs/design/01_*`) | P0 |
| PR-DESIGN-02 | Design tokens OXV (couleurs/typo/spacing/cards/shadows) | P0 |
| PR-DESIGN-03 | Hero home premium | P0 |
| PR-DESIGN-04 | Home sections (Experience, App, Média, Corporate, Calendrier) | P0 |
| PR-DESIGN-05 | Offres premium (cards Access/Signature/Heritage/Corporate) | P0 |
| PR-DESIGN-06 | Page App produit | P1 |
| PR-DESIGN-07 | Page Média + galerie (flux admin→app, droits) | P1 |
| PR-DESIGN-08 | Corporate premium (scénarios, hospitality, CTA B2B) | P1 |
| PR-DESIGN-09 | Mobile polish (CTA sticky, formulaires, perf) | P1 |
| PR-DESIGN-10 | Motion sobre (reveal, hover, `prefers-reduced-motion`) | P2 |
| PR-DESIGN-11 | SEO visuel (OG, alt, schema, titres) | P2 |
| PR-DESIGN-12 | Design QA (cross-device, Lighthouse, a11y) | P0 (final) |

> Calendrier indicatif V2 (doc V2 §14) : S1 inventory+tokens · S2 home · S3 offres+app · S4 média+corporate · S5 mobile+perf · S6 QA+SEO.

### 🧹 Phase 6 — Technique (P2/P3)
| PR | Objet |
|---|---|
| PR-SITE-18 | Inventaire & retrait des mocks/faux succès |
| PR-SITE-19 | Découpage progressif d'`index.html` (config, client, services, pages, CSS) |
| PR-SITE-20 | Décision architecture future (rester custom vs Astro/Next/Vite) |

---

## 3. Dépendances clés (ce qui bloque quoi)

```
01 PII ─┬─► 03 Contact ─┐
02 RLS ─┘               ├─► 05 Emails ──► 29 Emails+push app
                        │
06 Booking ──► 23 Pass OXV ──► 26 Paiement sync app
   │            │
   │            └─► 28 Admin bridge → participant app
21 Comptes/rôles ──► 22 Résa visible app, 24 Sessions↔Events, 25 Docs/véhicules
   │
   └─► 27 Flux média (admin import 🌐 + DB 🗄️ + galerie app 📱)
        │
        └─► PR-DESIGN-07 Page Média (vitrine du flux)

DESIGN-01 audit ──► DESIGN-02 tokens ──► DESIGN-03..09 (toutes les pages)
DESIGN-* ──────────────────────────────► DESIGN-12 QA (dernier)
18 Nettoyage ──► 19 Découpage ──► 20 Architecture
```

Règles : **toute la Phase 5 (design) attend les tokens (DESIGN-02)**, qui attendent l'audit (DESIGN-01). **PR-27 (média) attend PR-21 (user_id commun) + PR-06 (registration)**. **PR-19 (découpage) se fait après stabilisation**, par petites PR sans régression visuelle.

---

## 4. Ma méthode par PR (boucle répétée)

Pour **chaque** PR, je déroule la même boucle traçable :

1. **Audit ciblé** (lecture seule) → `docs/site/PR_xx_*.md` ou `docs/design/xx_*.md` : fichiers inspectés, risques, état réel.
2. **Décision** : je te montre l'écart et l'approche, je tranche les choix structurants avec toi.
3. **Implémentation** sur la branche : code `index.html` + migration Supabase si besoin (via MCP, trackée).
4. **Vérification** : empirique DB (rôles, grants, RLS) + manuelle/preview navigateur pour l'UI.
5. **Commits séparés** (doc / code / migration) + mise à jour du suivi de tâches.
6. **Gate** : je coche les critères d'acceptation du dossier avant de passer à la PR suivante.

**Garde-fous permanents :** aucune clé API côté client · aucune fuite PII/média · aucun faux succès · aucune notification pendant le roulage · pas de refonte design avant fiabilité · pas de bucket média client public.

---

## 5. Gates de production (consolidés)

**Sécurité & commercial (V1)** : PII OK · contact & corporate enregistrés · email réservation envoyé · admin voit les demandes · paiement pending visible · documents validables · aucun faux succès · robots/sitemap cohérents.

**Écosystème (V1.1)** : 1 compte site = 1 compte app · réservation site visible app · Pass OXV depuis registration · véhicule/document saisis une seule fois · paiement validé change le statut app · média importé visible **au bon client uniquement** · média mal attribué retirable immédiatement · partenaire ne voit aucun média privé · aucune notif en roulage · consentements site/app cohérents · logs admin média.

**Design (V2)** : OXV compris en < 5 s · CTA réservation/corporate clairs · mobile lisible · images compressées/lazy · contrastes & alt & clavier · cohérence app (Pass/Trace/Data Lab/Carnet/Saison/Média) · flux média expliqué · rien de privé exposé.

---

## 6. État d'avancement

- ✅ Audits : `AUDIT_GLOBAL_V1.md`, `PR_SITE_01_AUDIT_PII.md`, `PR_SITE_02_AUDIT_RLS.md`
- ✅ PR-SITE-01, PR-SITE-02 livrées (2 commits + 1 migration prod)
- 🔜 Prochaine : **Phase 1 — PR-SITE-03 (Contact réel)**

Total programme : **43 PR** (20 + 11 + 12). Phases 0→1 = socle ; 2 = écosystème ; 3-4 = exploitation/conversion ; 5 = premium ; 6 = dette technique.
