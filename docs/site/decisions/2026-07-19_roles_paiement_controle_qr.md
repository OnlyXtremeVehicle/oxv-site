# Décisions fondateur — 2026-07-19

> Session « espaces coach/partenaire + connexion partenaire ». Source : demandes écrites + vocal fondateur.

## 1. Rôles opérationnels dès la validation de candidature (LIVRÉ)
- Edge `validate-inscription` **v10** : accept coach → `role=coach` + `coach_permissions` + fiche brouillon ; accept partenaire → `role=partner` + `partner_accounts` créé **`validated`** (l'admin vient de valider la candidature, infos société comprises). Offres/événements restent validés **élément par élément** (arbitrage 18/07).
- Aiguillage par rôle à la connexion : admin → /admin · coach → /coach-espace · partner → /partenaire-espace · pilote → /compte. Toute page `compte*` est réorientée pour un coach/partenaire.
- Compte `administration@oxvehicle.fr` = **multi-casquettes officiel** (admin + coach + partenaire) — plus un artefact à nettoyer.

## 2. Espace coach valorisant (LIVRÉ)
Héro personnalisé (photo, nom, statut, publier/aperçu), tableau de bord, fiche riche (histoire/palmarès, spécialités, tarifs, liens, 12 médias YouTube/photos), fiche publique en modale sur la vitrine, publication self-service (candidature déjà validée). Bloc « Écran de session » → TV de stand (`/pavillon/coach`) + télécommande (`/pavillon/controle`). **À venir : même traitement pour l'espace partenaire.**

## 3. PAIEMENT — AUCUNE VALIDATION ADMIN (verbatim fondateur)
« Les paiements je n'ai pas besoin de valider. Une fois le compte OK, le pilote réserve et paye directement sa date de session. »
- **Conséquence** : à l'ouverture du PSP, le flux est réservation → paiement direct → confirmation automatique. Aucune étape d'approbation humaine du paiement. L'admin-paiements reste un outil de **suivi comptable**, pas un poste de validation.
- La « validation admin après chaque réservation » (HUB-02) est **remplacée** par le contrôle documentaire SUR SITE (ci-dessous) : la réservation/paiement ne sont jamais bloqués par l'état du dossier ; c'est l'accès piste le jour J qui en dépend.

## 4. CONTRÔLE SUR SITE PAR QR (contrat site ↔ app)
« Nous sommes juste là pour vérifier la validité des documents une fois sur site avec le scan du QR code profil. Le QR code pilote est dispo depuis l'application. Le contrôle se fera par un scan qui envoie un accès aux documents du pilote scanné et permet une vérification claire. »

**Contrat QR (normatif, côté app — DEPENDANCE_APP)** :
- Le QR du profil pilote encode l'URL : `https://www.oxvehicle.fr/controle-pilote/{user_id}` (UUID `public.users.id`).
- Côté site (LIVRÉ) : cette route ouvre le **dossier pilote admin** (documents + éligibilité GO/EN_ATTENTE/NO_GO). Garde admin ; si le staff n'est pas connecté au moment du scan, la cible est mémorisée et rouverte automatiquement après le login.
- Évolution possible (non requise V1) : jeton signé à la place de l'UUID nu si l'app veut des QR expirables — l'URL reste la même forme.

## 5. Correctifs du jour (constats fondateur)
- **Photo coach « téléversement refusé »** : la policy storage `coach-media` exigeait `is_coach()` strict — le compte multi-casquettes (role=admin) était refusé → élargie à `is_coach() OR is_admin()` (migration `fix_overload_relais_et_upload_coach_admin`).
- **« Confirmation de création de compte refusée »** : l'ajout de `p_dry_run` avait laissé une **surcharge fantôme** `admin_validate_inscription(uuid,text,text)` (ancien en-tête cassé) à côté de la nouvelle → appel RPC ambigu → échec. Ancienne supprimée ; résolution vérifiée. 3 candidatures en attente au moment du correctif.
