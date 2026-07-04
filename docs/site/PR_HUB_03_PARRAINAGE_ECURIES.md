# PR-HUB-03 — Parrainage « Écuries » (option C fondateur)

> Surface : 🌐 site + 🗄️ DB. Date : 2026-07-01. **Statut : ✅ livrée.** Décisions Q5 + Q5-bis : pas de réduction — le parrainage construit une **écurie** ; hiérarchie = **taille du groupe**.

## 1. Modèle (option C)
- **Code parrain** : `users.affiliation_code` (colonne existante réutilisée, index unique), format `OXV-PRENOM-XXXX`, généré côté serveur.
- **Écurie** (`crews` + `crew_members`) : le 1ᵉʳ filleul crée l'écurie du parrain (qui en devient **capitaine**). Un pilote = une seule écurie.
- **Anti-abus** : auto-parrainage interdit, double adhésion interdite, et **seuls les filleuls ayant validé leur premier paiement comptent** dans les paliers (trigger sur `payments`).
- **Paliers par taille (membres validés)** : **5** → priorité de réservation collective · **10** → box dédié un jour de session · **20** → **écurie nommée sur le Plateau** (le capitaine la nomme ; l'affichage public est contrôlé par la vue `crews_public`, sans identités).
- **Fast-track** : le formulaire de candidature capte déjà le code (`demandes_inscription.referral`, colonne existante — mon doublon `referral_code` créé par erreur d'audit a été supprimé) ; badge **« ⚡ Parrainé · fast-track »** dans l'admin-demandes → priorité de traitement. Doctrine : la hiérarchie d'écurie est sociale, jamais un classement de pilotage.

## 2. Livré
- Migration `crews_referral_hub03` + fix `crews_rls_recursion_fix_hub03` : tables, RLS, fonctions definer (`oxv_get_my_referral_code`, `oxv_redeem_referral`, `oxv_name_my_crew`, `oxv_my_crew_id`), trigger validation, vue publique palier 20.
- **Client** (Préférences) : carte « Mon écurie & parrainage » — code affichable, rejoindre par code, état d'écurie (membres/validés/capitaine), progression des paliers, nommage capitaine.
- **Plateau** : bloc « Les écuries » (nommées, ≥ 20 validés) — état vide honnête.
- **Admin** : badge fast-track sur les demandes parrainées ; formulaire de demande relabellé (« code parrain… candidature en priorité »).

## 3. Vérifications empiriques
- Génération : `OXV-LOUIS-6BE9` ✓ · redeem crée l'écurie + rejoint ✓ · double adhésion → `deja_dans_une_ecurie` ✓ · code faux → `code_invalide` ✓.
- **Bug réel trouvé par test et corrigé** : récursion infinie RLS sur `crew_members` (policy auto-référente) → helper definer `oxv_my_crew_id()`.
- Tiers : 0 écurie / 0 membre visibles ✓ · membre : voit SA crew (1) et ses 2 membres ✓ · anon : `crews_public` seulement ✓.
- **Données de test nettoyées** (écurie supprimée, code remis à null). `node --check` OK, 0 nav cassée, 64/64 sections.

## 4. Critères d'acceptation
- [x] Code unique par client, capté au signup/candidature (fast-track badge admin).
- [x] Anti-abus : auto-parrainage interdit, comptage après paiement validé.
- [x] Écuries : création auto, capitaine, paliers 5/10/20, nommage, affichage plateau contrôlé.
- [x] Suivi client (carte préférences) + vue admin (badge demandes ; détail via tables admin-visibles).
