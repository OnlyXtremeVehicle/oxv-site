# PR-HUB-04 — Liaison compte site ↔ app Mirror (audit + plan)

> Surface : 🌐 site + 🗄️ DB + 📄 doc d'intégration app. Date : 2026-07-01. **Statut : audit ✅ / plan validé en interne / implémentation en cours.** Première PR-HUB (aucune dépendance fondateur).

## 1. Audit de l'existant (vérifié live)

| Élément | État |
|---|---|
| Identité partagée | ✅ **déjà acquise** : même Supabase (`auth.users` + `public.users` communs), PR-SITE-21 vérifiée. 1 compte = 1 identité site+app, rien à créer. |
| `devices` / `device_assignments` / `device_health_logs` | Existent mais = **boîtiers télémétrie RaceBox** (matériel), pas l'appairage du téléphone. Hors périmètre. |
| Table de codes d'appairage | ❌ inexistante |
| Edge Function d'appairage | ❌ inexistante (pattern secret + service-role déjà éprouvé sur 6 fonctions) |
| UI « Connecter l'app » côté compte | ❌ inexistante (l'espace compte a profil/documents/paiements/…) |
| Deep links | `oxvcoach://bilan/{id}` déjà émis par la page progression (inertes avant publication app) |

**Conclusion d'audit** : le besoin réel n'est pas « lier les comptes » (fait) mais **faciliter la première connexion dans l'app** sans ressaisir de mot de passe : un code court, à durée limitée, à usage unique.

## 2. Plan (schéma + flux)

**Table `app_pairing_codes`** (migration trackée) :
`id uuid PK · user_id uuid → users · code text (8 car., unique, généré serveur) · created_at · expires_at (10 min) · used_at · used_user_agent text`
RLS : owner SELECT ses propres codes (affichage) ; **aucun INSERT/UPDATE client** — tout passe par l'Edge Function (service-role). Index unique partiel sur les codes actifs.

**Edge Function `pair-app`** (JWT utilisateur requis pour `generate`, aucun secret côté client) :
- `action=generate` : authentifié → invalide les codes actifs précédents, crée un code 8 caractères (alphabet non ambigu), expire à +10 min, le renvoie.
- `action=redeem` : l'app poste `{ code }` → vérification (existe, non expiré, non utilisé) → marque `used_at` → `auth.admin.generateLink(type='magiclink')` pour l'email du compte → renvoie `{ token_hash }` ; l'app appelle `verifyOtp({ type:'magiclink', token_hash })` et obtient sa session. Usage unique, aucune donnée sensible en transit hors token à usage unique.

**UI site** : carte « Connecter l'app OXV » dans l'espace compte (préférences) — bouton « Générer mon code », affichage grand format mono + compte à rebours 10 min, états vide/expiré honnêtes, mention « sortie de l'app : printemps 2027 ».

**Doc d'intégration app** : `docs/site/INTEGRATION_APP_PAIRING.md` (endpoint, payloads, erreurs, exemple `verifyOtp`).

## 3. Sécurité
Code 8 car. alphabet 32 symboles ≈ 1,1×10¹² combinaisons, fenêtre 10 min, usage unique, invalidation des précédents, rate-limit naturel (JWT requis pour générer) + verrou : 5 tentatives de redeem/min/IP via table de comptage. Jamais de code en clair dans les logs.

## 4. Critères d'acceptation
- [ ] Un client connecté génère un code visible dans son espace, expirant à 10 min.
- [ ] `redeem` avec code valide → token de session app ; code réutilisé/expiré → erreur propre.
- [ ] RLS testée (anon/authenticated/autre user : aucun accès croisé).
- [ ] Doc d'intégration app livrée.
