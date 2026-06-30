# PR-COMP-07 — Suivi CRM des leads (inbox admin)

> Surface : 🌐 site (`index.html`, module admin inbox). Date : 2026-06-30. **Statut : ✅ livré.** Dépend de [PR-SITE-07](PR_SITE_07_ADMIN_INBOX.md).

## 1. Objectif
Transformer l'inbox (lecture/statuts de messages) en mini-pipeline commercial (V2.1 §8) : qualifier chaque lead (contact/corporate/partenaire/waitlist), prioriser, planifier la relance — sans quitter l'admin, sans nouvel outil.

## 2. Livré
- **Pipeline lead** (`metadata.crm.lead_status`) : Lead → Contacté → Qualifié → Proposition → Gagné / Perdu.
- **Priorité** (`metadata.crm.priority`) : normale / haute / urgente — indicateur visuel dans la liste (↑ haute, ⚑ urgente).
- **Relance** (`metadata.crm.next_action`) : date de prochaine action.
- **UI modal** : bloc « Suivi commercial » (3 champs + bouton *Enregistrer le suivi*) → `inboxSaveCrm()`.
- **Liste** : badge de statut lead sous le statut message ; tri visuel par priorité.
- **Traçabilité** : `crm.updated_at` + `crm.updated_by` à chaque sauvegarde.

## 3. Choix d'implémentation
- **Aucune migration** : tout est stocké dans `contact_messages.metadata.crm` (jsonb déjà présent, déjà servi par les politiques RLS admin existantes). Réversible, zéro risque schéma.
- Le `crm` est **exclu** des metaRows génériques de la modal (comme `admin_notes`/`ack_sent_at`) pour ne pas s'afficher en doublon.
- Distinct du `status` message (new/read/replied/spam/archived) : le statut message = traitement de l'inbox ; le statut lead = avancement commercial. Les deux coexistent proprement.
- Merge non destructif de `metadata` (spread) à chaque update — aligné sur `inboxSaveNote`.

## 4. Vérification
- `INBOX_CRM_STATUS` (1), `inboxSaveCrm` (def + onclick), ids `inboxCrm{Status,Priority,Next}` (3 occurrences chacun : HTML + lecture + écriture), `crm` exclu des metaRows, **48/48 `<section>`**.
- Round-trip testé logiquement : ouverture peuple les champs depuis `metadata.crm` ; sauvegarde re-render → badge + priorité visibles immédiatement.

## 5. Critères d'acceptation
- [x] Chaque lead peut être qualifié (statut pipeline) et priorisé.
- [x] Date de relance planifiable.
- [x] Visible d'un coup d'œil dans la liste (badge + priorité).
- [x] Aucun schéma cassé, réversible.

## 6. Suivi possible
- Filtre/onglet par statut lead (vue pipeline) et tri par `next_action` (relances du jour).
- Export CSV des leads pour reporting.

**Verdict : ✅ PR-COMP-07 livrée.**
