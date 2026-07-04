# Décisions fondateur — réponses au bloc de questions (2026-07-01)

| # | Sujet | Décision | Conséquence |
|---|---|---|---|
| 1 | Prix | **Site fait foi** : Access 390 € · Signature 690 € · Heritage 2 490 € (pack 4 sessions) | Aucun changement site ; le prompt maître est amendé sur ce point |
| 2 | Nom app | **OXV Mirror** | ✅ appliqué : 15 occurrences renommées (Trace = nom du concept/feature « la Trace », conservé) |
| 3 | QDI | **Assumé et conservé** : QDI complet 5 branches, avec de **vraies références** (méthodologie documentée, défendable), **visibilité publique au choix du pilote** | Nouvelle PR **PR-HUB-11** : doc méthodologie référencée + opt-in visibilité (`users.community_visibility` existe déjà) ; la doctrine « pas de scoring » du prompt maître est **amendée par le fondateur** |
| 4 | Éligibilité | Checklist **validée** : permis, CNI, attestation assurance, CT + pneus/freins déclaratif, niveau sonore, casque, décharge signée, briefing. **Validation par l'admin après chaque réservation** | **PR-HUB-02 débloquée** (spec figée) |
| 5 | Parrainage | **Pas de réduction.** Le parrainage = **fast-track** (dispense de validation admin à l'inscription) + **intégration directe à un groupe social** ; **hiérarchie** croissante avec le nombre de filleuls | **PR-HUB-03 re-spécifiée** : `referral_codes`/`referrals` + statut « vouched » + groupes + niveaux (bronze→…) ; à re-maquetter avant dev |
| 6 | SIRET | Oui — dès l'immatriculation ; factures en **placeholder** d'ici là | **PR-HUB-01 débloquée** |
| 7 | PSP | **Stripe validé**, mais **attendre le SIRET** avant toute création de compte | `OXV_PAYMENT.mode='pending'` maintenu ; préparation intégration OK, aucun compte créé |
| 8 | Invités B2B | « Je ne sais pas trop » | **Recommandation (mini-ADR ci-dessous)** : table `session_guests` sans compte |
| 9 | Merge design V2 | **Pas encore** | On continue sur `claude/design-v2` ; merge sur demande |
| 10 | Abonnements Mirror | **Oui, vendre dès la phase 1**, tarifs différenciés : **pilote 15 €/mois ou 150 €/an** · **coach 750 €/saison** · **partenaire B2B** avec avantages propres | Nouvelle PR **PR-HUB-12** : offre Mirror sur le site (3 publics). ⚠️ manque le **prix partenaire B2B** + le détail des avantages par public → question de suivi |

## Mini-ADR — invités B2B (Q8, recommandation)
**Problème** : un invité d'une journée corporate doit-il avoir un compte ?
**Options** : (a) compte `users` complet — lourd (RGPD, mots de passe, comptes morts), (b) table `session_guests(session_id, nom, email, statut)` sans compte — léger, suffisant pour check-in/éligibilité light/médias nominatifs.
**Recommandation : (b) `session_guests`**, avec passerelle optionnelle « créer mon compte » si l'invité veut récupérer ses médias dans l'app. Coût faible, réversible. **Statut : proposé, en attente d'objection — sera implémenté avec le premier chantier B2B.**

## Questions de suivi (non bloquantes aujourd'hui)
- Q10-bis : prix + avantages **partenaire B2B** de l'abonnement Mirror ; et confirmer les avantages exacts inclus pour pilote (Data Lab illimité ? médias ?) et coach.
- Q5-bis : nom/valeurs des niveaux de hiérarchie parrainage et avantages par niveau.
