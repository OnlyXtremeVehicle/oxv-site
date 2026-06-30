# PR-SITE-10 — Admin documents (email validation / refus)

> Objectif : documents protégés, statuts visibles pilote/admin, **et notification email réelle** au pilote à la validation/refus.
> Surfaces : 🗄️ Supabase (Edge Function + trigger) + 📱 repo app (source). Pas de changement `index.html`. Date : 2026-06-30.
> **Statut : ✅ livré.** Vérification adversariale (3 lentilles) + correctif idempotence.

## 1. Constat

La gestion admin des documents **fonctionne déjà** et écrit des **colonnes/enums valides** (contrairement à payments) :
- `documents` a bien `validated_at` + `validated_by` (uuid), `rejection_reason`, `status` enum `{pending,validated,rejected,expired}`.
- `adminValidateDoc` → `status='validated'` (+ validated_at/by, rejection_reason=null) ; `confirmRejectDocument` → `status='rejected'` (+ motif obligatoire ≥10 car.) ; `adminResetDoc` → `pending`. Tous valides.

**Manque** : les toasts disaient « pilote informé par email » mais **aucun email n'était envoyé** (placeholder).

## 2. Livré

Branchement de l'email réel via le **pattern trigger → Edge Function** (comme PR-05) :
- **Edge Function `send-document-status`** (déployée, ACTIVE, `verify_jwt=false`, dormante sans secret) : charge le document + user côté serveur, envoie un email Resend **validé** (vert) ou **refusé** (rouge, avec motif + invitation à redéposer), journalise `email_log`. Échappement XSS complet.
- **Trigger `trg_document_status_email`** (AFTER UPDATE `documents`) : se déclenche **uniquement** sur transition de statut vers `validated`/`rejected` (pas sur reset→pending). Non bloquant.
- Les toasts existants (« pilote informé par email ») deviennent donc **vrais** — aucun changement `index.html` nécessaire.

## 3. Vérification adversariale (workflow, 3 lentilles)

| Lentille | Verdict |
|---|---|
| Deno (correction) | ✅ pass — auth, branchement validé/refusé, escapeHtml, colonnes email_log valides |
| Trigger / anti-boucle | ✅ pass — **preuve** : la fonction ne fait aucun UPDATE sur documents → pas de re-fire ; seul trigger sur la table ; enum valide |
| Idempotence | ⚠️→✅ — a détecté un **major** (corrigé) |

**Correctif appliqué (major)** : la dédup anti-retry comptait **toutes** les lignes `email_log` (y compris les échecs `bounced`) → un premier envoi échoué bloquait le retry 2 min (email jamais délivré). Corrigé : la dédup ne compte que les envois **réussis** (`status='sent'`) → un échec n'empêche plus le retry, un succès reste protégé. Redéployé (v2).

Points acceptés (non bloquants) :
- **TOCTOU concurrent** (théorique) : un seul UPDATE par action admin → un seul fire ; les retries pg_net série sont dédupés. Pas de durcissement (unique index) jugé nécessaire.
- `email_log.sent_at` a bien un `DEFAULT now()` (confirmé empiriquement en PR-05).

## 4. Note transverse
`notify-admin-lead` (PR-05) utilise une dédup similaire **sans** filtre `status='sent'` (et sans fenêtre) → même classe (sur-suppression après échec), mais **bas enjeu** (notification interne équipe, fire unique). À harmoniser si besoin dans une passe de durcissement.

## 5. Vérification end-to-end
La chaîne trigger→pg_net→Edge Function→Resend→email_log est **déjà prouvée end-to-end en prod** (test PR-05). `send-document-status` réutilise exactement ce mécanisme (fonction ACTIVE, trigger activé). Un test live ciblé a été **refusé par le garde-fou** (modifier le document d'un vrai utilisateur enverrait un vrai email non autorisé par « on continue ») — non contourné.

## 6. Critères d'acceptation
- [x] Documents protégés (RLS own_or_admin — déjà en place).
- [x] Statuts visibles pilote/admin (déjà en place).
- [x] Valider/refuser (permis, assurance, etc.) — fonctionnel, colonnes valides.
- [x] **Notifier le pilote** par email (validation + refus avec motif) — désormais réel.

## 7. Test manuel (avant prod)
1. Admin → fiche pilote → valider un document → le pilote reçoit « Document validé — … ».
2. Refuser un document avec motif → le pilote reçoit « Document à corriger — … » + motif.
3. Reset → pending : aucun email.

**Verdict : ✅ PR-SITE-10 livrée.** Phase 3 (admin) bien avancée (07, 08, 10). Reste pour le go-live : connexions app (Phase 2 : 21-27), Page App (13), nettoyage (18), puis design (V2).
