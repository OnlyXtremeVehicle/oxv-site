# PR-SITE-07 — Admin inbox (boîte de réception)

> Objectif : l'admin lit et traite toutes les demandes (`contact_messages` : contact, corporate, founding) avec statuts et notes internes.
> Surface : 🌐 site (`index.html`) uniquement — aucune migration (table + RLS déjà en place). Date : 2026-06-30.
> **Statut : ✅ livré.** Vérification adversariale (3 lentilles) PASS + corrections appliquées.

## 1. Livré

Nouvelle section admin **« Boîte de réception »** :
- **Page** `#page-admin-inbox` (gabarit Paiements : sidebar+nav, header, 4 KPIs, filtres, table) + **modal de lecture** `#inboxModal`.
- **Nav** : item « Boîte de réception » (avec badge non-lus `navBadgeInbox`) ajouté **avant Médias dans les 13 navs admin** + dans la grille de raccourcis du dashboard.
- **Routing** : `'admin-inbox'` dans `adminPages` (page protégée) + branche loader dans `goToAdmin`.
- **JS** (`loadAdminInbox`, `inboxRender`, `inboxUpdateKpis`, `inboxOpen`, `inboxSetStatus`, `inboxStatusCurrent`, `inboxSaveNote`, `inboxReply`, `refreshInboxBadge`) :
  - Lecture `contact_messages` (200 derniers, `created_at` desc).
  - **Filtres** par statut (new/read/replied/spam/archived) et source (contact/corporate/founding).
  - **KPIs** : non lus, corporate, répondus, total.
  - **Statuts** : ouverture d'un message le marque `read` (auto, si `new`) ; boutons Répondu / Archiver / Spam → `UPDATE status` (+ `read_at`/`read_by`/`replied_at`).
  - **Notes internes** : stockées dans `metadata.admin_notes` (merge non destructif, pas de migration).
  - **Répondre** : `mailto:` pré-rempli vers l'expéditeur.
  - **Badge non-lus** : `refreshInboxBadge` (count `status='new'`), appelé au dashboard, au chargement inbox, et à chaque changement de statut.

## 2. Sécurité

- **RLS** : `contact_messages_admin_all = FOR ALL USING (is_admin())` → seul l'admin lit/modifie. Accès gardé par `goToAdmin` (`isCurrentUserAdmin`) + `adminPages`.
- **XSS** : tout contenu saisi par le public (nom, email, sujet, message, clés/valeurs `metadata`) passe par `escapeHtml` dans le rendu liste **et** le modal. Vérifié par la lentille xss-regression.

## 3. Vérification adversariale (workflow, 3 lentilles) — PASS

| Lentille | Verdict |
|---|---|
| Logique JS | ✅ pass — aucun statut hors enum écrit, colonnes valides, idempotence locale, await OK |
| Intégration / routing | ✅ pass — routing/loader/badge câblés, 13 navs cohérentes, tous les ids DOM présents 1×, page unique |
| XSS / régression | ✅ pass — échappement complet ; `replace_all` n'a touché que les navs (13/13 intactes) |

**Corrections appliquées suite à la revue :**
- Boutons du modal → helper gardé `inboxStatusCurrent(status)` (évite un TypeError si `_inboxCurrent` indéfini).
- Item « Boîte de réception » ajouté aussi à la grille de raccourcis du dashboard (`admin-nav-btn`) pour la complétude.

**Nits laissés (non bloquants) :** filtre source « contact » en égalité stricte (`contact_form`) ; `read_by` écrit mais non re-sélectionné (traçabilité UI seulement) ; `mailto` adresse non encodée (risque négligeable, garde présente).

## 4. Données

Suppression d'un artefact de test pré-existant (`source='test_claude'`, ligne de test d'une session antérieure) pour ne pas polluer l'inbox. L'entrée réelle `contact_form` (statut `replied`) est conservée.

## 5. Lien CRM (V2.1 / PR-COMP-07)

PR-07 couvre le cycle `status` natif (new/read/replied/spam/archived) + notes internes. Le CRM enrichi (`lead_status`, `priority`, `owner`, `next_action_at`) reste pour **PR-COMP-07** (stockable dans `metadata` ou via colonnes dédiées).

## 6. Critères d'acceptation
- [x] Admin voit toutes les demandes (contact, corporate, founding) dans un seul flux.
- [x] Filtres par source et statut.
- [x] Traitement : lire, marquer répondu/spam/archivé, notes internes, répondre (mailto).
- [x] Badge non-lus dans la nav.

## 7. Test manuel (avant prod)
1. Admin → « Boîte de réception » : la liste s'affiche, badge non-lus cohérent.
2. Ouvrir un message → passe en « Lu », badge décrémenté ; metadata corporate visible.
3. Marquer Répondu / Archiver / Spam → statut mis à jour, liste rafraîchie.
4. Soumettre un nouveau contact/corporate depuis le site public → apparaît en « Nouveau ».

**Verdict : ✅ PR-SITE-07 livrée.** Prochaine (Phase 3) : PR-SITE-08 (Admin paiements — dont le correctif du statut `'paid'`→`'succeeded'`).
