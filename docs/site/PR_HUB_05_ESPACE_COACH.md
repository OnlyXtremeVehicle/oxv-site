# PR-HUB-05 — Espace Coach (côté site)

> Surface : 🌐 site. Date : 2026-07-01. **Statut : ✅ livrée (volet site).** Zéro migration : le site se branche sur l'écosystème coach EXISTANT de l'app.

## 1. Découverte d'audit (décisive)
L'app a déjà construit **18 tables coach** (profils, relation coach↔élève à double consentement, annotations, permissions RGPD, disponibilités, bookings, avis, drafts IA validés humain, roulages). Le rôle `coach` existe dans l'enum (`pilot, admin, coach, partner, pro_pilot`). **Créer un modèle site parallèle aurait répété l'erreur `events`** (leçon A1) → le site consomme l'existant, l'app reste l'outil de travail du coach (« le site vend, l'app prolonge »).

## 2. Livré (3 blocs site, lecture seule via RLS existante)
- **Vitrine publique « Nos coachs partenaires »** (page Coach) : profils `coach_profiles` **publiés** (photo, headline, spécialités, bio, palmarès, prix saison, réseaux) + note moyenne `coach_reviews` (visible connecté, dégradation propre en anonyme). État vide honnête. → vend l'offre Signature/coaching.
- **« Mon coach »** (Ma progression) : si le pilote a une relation `coach_pilots` active (double consentement app), carte coach (photo/headline) + renvoi vers l'app pour les échanges. Invisible sinon.
- **Admin « Coachs partenaires »** (tableau de bord) : liste des comptes `role=coach`, statut du profil (publié/brouillon/absent), nombre d'élèves actifs, lien fiche ; mention licence **750 €/saison — facturable via le module factures (HUB-01)**.

## 3. Sécurité vérifiée (protocole §8)
- RLS existantes réutilisées : profils publiés lisibles par tous · relation lisible par le pilote concerné · admin tout.
- **Isolation financière testée** : un coach (simulé, sans flag admin) voit **0 paiement / 0 facture** ✓ — le garde-fou « un coach ne voit jamais le financier » tient par construction (`payments_select_own_or_admin`).
- 🔎 **Constat de données** (aucune action prise) : l'unique compte `role=coach` est `administration@oxvehicle.fr` (le fondateur, `is_admin=true` → voit tout, normal pour lui). Le rôle coach sur ce compte semble être un artefact de test app — à nettoyer ou conserver, décision fondateur.

## 4. Reste côté app (hors périmètre site, déjà couvert par l'app)
Planning coach, fiche élève détaillée, rédaction des comptes-rendus (annotations + drafts IA validés) : **c'est l'outil app**, déjà modélisé. Le site n'en fait pas un doublon.

## 5. Critères d'acceptation
- [x] Rôle coach + RLS stricte (existants, vérifiés — financier inaccessible).
- [x] Vitrine publique coachs (profils publiés) pour vendre Signature.
- [x] Client : visibilité de son coach dans son espace.
- [x] Admin : gestion/suivi des coachs + licence 750 € rattachable aux factures.
- [x] Aucun modèle parallèle créé.
