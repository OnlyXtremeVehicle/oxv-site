# PR-SITE-04 — Corporate leads (insert réel + metadata structurée)

> Objectif : les demandes corporate sont enregistrées dans `contact_messages` avec `source='corporate_form'`, metadata structurée, sans faux succès, avec fallback mailto.
> Surface : 🌐 site + 🗄️ DB (vérif). Vérifiée par workflow adversarial (4 lentilles). Date : 2026-06-30.

## 1. Décision : table cible = `contact_messages` (centralisation)

Deux options existaient :
- **`corporate_leads`** : table dédiée, parfaitement structurée (company, sector, contact_name, contact_role, email, phone, day_format, guests, target_date, message) — mais **0 ligne** (jamais utilisée), et **isolée** de l'inbox admin.
- **`contact_messages`** : table partagée (contact + corporate + presse + privacy + waitlist via `source` + `metadata`).

➡️ **Retenu : `contact_messages`**, conformément à la décision explicite du plan V1 (« centraliser les demandes ») et au CRM V2.1 (`lead_source` inclut `corporate_form`). L'inbox admin (PR-07) lira ainsi **un seul flux**.
➡️ **`corporate_leads` est redondante** (0 ligne) → à déprécier/supprimer dans une PR de nettoyage DB (à confirmer). *Dis-moi si tu préfères au contraire la table dédiée.*

## 2. Problèmes corrigés (avant → après)

| Avant | Après |
|---|---|
| `source: 'corporate-form'` (tiret) → casse les filtres CRM | `source: 'corporate_form'` (underscore, harmonisé) |
| Champs corporate concaténés en texte dans `message` | **metadata JSONB structurée** : `company, sector, role, event_type, guest_count, preferred_period, free_text` (+ `phone` dans la colonne `phone`) |
| Toast succès **hors** try/catch → faux succès si insert échoue | Toast succès **uniquement après** `if (error) throw error` |
| Aucun message d'erreur | Toast d'erreur + **fallback mailto** `corporate@oxvehicle.fr` (sujet+corps encodés) → lead jamais perdu |
| Loading = `pointerEvents` seul | État « Envoi en cours… » sur le `<span>` du bouton, restauré en `finally` |
| `submitB2B` + `fakeUpload` morts (ids `corp-*` inexistants) | **Supprimés** |

Colonne `message` (NOT NULL) toujours remplie via un récapitulatif lisible ; le détail atomique est dans `metadata`.

## 3. Vérification adversariale (workflow `pr04-corporate-verify`, 4 lentilles)

| Lentille | Verdict |
|---|---|
| Faux-succès / contrôle de flux | ✅ pass — aucun chemin ne déclenche le succès sans insert réussi |
| Données / schéma | ✅ pass — `source`, 6 clés metadata, message NOT NULL, colonnes valides |
| Câblage / code mort | ✅ pass — `submitB2B`/`fakeUpload` totalement retirés, `#corpForm onsubmit→submitCorporate` intact |
| Fallback / régression | ✅ pass — mailto encodé, validation préservée, reset uniquement au succès |

**Correctif issu de la revue** (nit `minor` remonté par 2 lentilles) : `btn.textContent = …` écrasait le `<span>` interne des boutons (perte du wrapper stylé). Corrigé sur **les deux** formulaires (contact PR-03 + corporate) en ciblant `btn.querySelector('span')`.

## 4. Suivis (non bloquants)

- **`metadata.event_type`/`guest_count`** stockent le libellé brut du `<select>` / texte libre (ex. « OXV Corporate Standard (…) », « 18 pilotes ») → non normalisés. À améliorer quand les options `cf-format` auront des `value` codifiées (lien PR-14 Offres). 
- **`budget_range`** (prévu au plan) non collecté : le formulaire n'a pas de champ budget → à ajouter côté formulaire si voulu.
- **`corporate_leads`** : table vide redondante → décision dépréciation.
- **`submitFoundingForm`** (cercle Founding) : a probablement le même schéma de source à harmoniser → à traiter (PR-18 ou dédiée).
- **mailto sans client mail** configuré : l'assignation peut être silencieuse (UX) — le lead reste saisi dans le formulaire (pas de reset en échec).

## 5. Critères d'acceptation

- [x] Lead corporate enregistré dans `contact_messages` (`source='corporate_form'`).
- [x] metadata structurée.
- [x] Aucun faux succès.
- [x] Fallback mailto propre si Supabase échoue.

## 6. Test manuel restant (avant merge)

1. Remplir le formulaire corporate → toast succès, ligne en base avec metadata correcte.
2. Couper le réseau → toast d'erreur + ouverture du client mail prérempli (pas de faux succès, saisie conservée).

**Verdict : ✅ PR-SITE-04 prête.** Prochaine : PR-SITE-05 (Emails transactionnels).
