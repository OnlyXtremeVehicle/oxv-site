# Décisions fondateur — 2026-07-04

> Session mission « PROMPT COMPLET » (lots 0→E + interview D.4 partielle). Source : arbitrages Gabin en session.

## 1. Tableau comparatif des offres (Lot E — arbitré ligne à ligne)
Le tableau livré fait foi : prix 390/690/2 490 € TTC · télémétrie **complète sur les 3 offres** · banque photo & vidéo livrée dans l'app **identique sur les 3 offres** (plus de « 10-15 clichés », onboard monté ni drone promis) · café d'accueil / **déjeuner traiteur** ×2 (fin du « gastronomique 3 services ») · coach partenaire **en option dès Access** · événements partenaires dans l'app (Access/Signature), **journée d'ouverture de saison** (Heritage).

## 2. Salve d'interview (4 réponses)
1. **Saison suivante** : Heritage conserve « Accès anticipé ».
2. **App OXV Mirror** : abonnement 15 €/mois séparé pour Access/Signature ; **Heritage inclut 1 an d'abonnement** (150 € de valeur).
3. **Médias** : banque identique pour tous — confirmé.
4. **Rapport QDI** : « Personnalisé sous 48 h · 5 dimensions » **conservé sur Signature/Heritage** (la réponse prime sur la ligne « simplifié » du tableau initial) ; Access = bilan simplifié. ⚠️ **Engagement opérationnel assumé** (« il va nous falloir le faire réellement ») → à porter côté app : analyse 5 branches + restitution sous 48 h après chaque session Signature.

## 3. Multi-circuit (§2.2 CLAUDE.md — application ajustée)
« Aujourd'hui nous n'avons que ce circuit donc reformulons légèrement en gardant Haute Saintonge en tête. »
→ **Pas de purge** : Haute Saintonge reste en tête partout. Retouches légères de positionnement : OXV = plateforme basée à Bordeaux, Haute Saintonge = **premier circuit partenaire**, autres emplacements « en cours de sélection » (llms.txt, À propos, Presse). La page circuit garde l'intégralité de son storytelling Beltoise.

## 3 bis. Interviews F / G / H / I (même session)
- **Lot F (calendrier)** : libellé jour+date+offre+format · **véhicule du pilote inscrit affiché** (calendrier connecté + Mes sessions) · filtres mois + offre · **jauge de remplissage factuelle** (vue `session_availability`, sans PII — corrige le comptage RLS faussé) · export .ics par session.
- **Lot G (corporate)** : formulaire une page, obligatoires minimaux (société, contact, email, format, effectif), budget en tranches neutres (jamais les prix B2B internes), chaîne serveur existante + **délai « 48 h ouvrées »** partout (send-contact-ack v5). Invokes `send-email` morts retirés (la fonction n'a jamais existé).
- **Lot H (typo/photos)** : direction **« Goodwood »** — titres en Cormorant Garamond italique, casse naturelle ; labels/data/boutons inchangés. 3 sujets photo validés, **génération IA en attendant le shooting** (jamais sur la page Preuves, jamais légendé « Beltoise »).
- **Lot I (grille coach)** : grille −5/−10/−15 % **supprimée** → paliers d'avantages **non tarifaires cumulables** (visibilité annuaire/app → priorité de réservation → invitations événements). Cohérence avec « parrainage sans réduction ».

## 4. Sécurité (les deux « oui »)
1. **Policy `contact_messages`** durcie : `with check (user_id is null or user_id = auth.uid())` — usurpation testée et bloquée (42501), cas nominaux OK (migration `contact_messages_insert_hardening_site30`).
2. **Revokes catégories A+B** appliqués (migration `definer_grants_hardening_p2_ab`) : 15 fonctions trigger fermées à tous les rôles clients + 7 fonctions `my_*` fermées à `anon`. Vérifié : 36 → **14 fonctions definer exécutables par anon** (les catégories C/D conservées volontairement, cf audit). Triggers actifs, `authenticated` conservé sur les `my_*`.
