# Décisions fondateur — 2026-07-18

> Session « lot ECRANS_PAVILLON + spec coach/partenaire ». Source : brief vocal + zip fondateur + interview (4 réponses).

## 1. Lot ECRANS_PAVILLON — livré (PR #27)

Brief complet fourni par le fondateur (prompt + addenda 01→04 + contrat temps réel v2, arbitrages A7/A9/A10/A11/A12/A13 verrouillés les 17-18/07). Implémenté monofichier (CLAUDE.md §1 prime : pas de `pavillon.js`). 5 routes hors nav/sitemap, gardées : `/pavillon/accueil` (TV publique HDMI, 4 états), `/pavillon/coach` (TV stand, 4 modes), `/pavillon/controle` (télécommande tablette), `/pavillon/regie` (état piste + drapeaux double confirmation), `/pavillon/admin` (photos curatées). Démo `?demo=1`, tests `?tests=1` (21/21).

**Reste pour le service réel (dans l'ordre)** :
1. **Migrations à valider puis exécuter** (`docs/site/pavillon/migrations/`) : vues `pavillon_pilotes_jour`/`pavillon_meteo`, table+bucket `pavillon_photos`. Sans elles : écran « Configuration Pavillon incomplète » (voulu).
2. `TODO_ARBITRAGE` : rôle `display` (compte TV dédié — aujourd'hui garde = compte authentifié) · rôle `staff` (admin/regie gardés par role=admin) · policies realtime (canaux en authentifié simple) · contrat QDI (champ NULL partout).
3. `DEPENDANCE_APP` : émission canal 1 (positions RaceBox 25 Hz → 1 Hz, event `position`) — seul morceau côté app.

## 2. Onglet coach (site) — 4 arbitrages du 18/07 (options recommandées retenues)

1. **Prix : tarifs publiés, transaction directe.** Le coach affiche ses tarifs sur sa fiche ; la réservation passe par le site mais le paiement reste direct coach↔pilote (hors OXV, pas de PSP requis). Doctrine §2.1 intacte : le coach exerce sous sa propre responsabilité.
2. **Sessions : créneaux adossés aux journées OXV, validés admin avant publication.** Le coach propose ; le fondateur valide.
3. Périmètre site (vocal fondateur) : organisation, réservation, prix, retours de visite du coach. **La restitution QDI reste sur l'app.** Connexion site↔app = base Supabase partagée, « réelle et fiable ».

## 3. Espace partenaire (site) — arbitrages du 18/07

1. **Validation : tout passe par l'admin, par élément.** Le partenaire crée entreprise/produits/offres/événements en autonomie ; RIEN n'apparaît dans l'app (catalogue/map) avant approbation fondateur de chaque élément.
2. **Catalogue : vitrine + mise en relation.** Produit, prix indicatif, contact/lien — la transaction se fait chez le partenaire. (Vente via OXV = plus tard, après PSP/SIRET.)
3. Cible d'affichage (vocal fondateur) : produits/offres → **catalogue de l'app** ; événements → **map de l'app**. Gestion des rôles côté site, affichage côté app.

## 4. À faire (prochain lot SITE)

Spec puis implémentation : espace coach (fiche+tarifs, proposition de créneaux → validation admin, réservations reçues, retours de visite) · espace partenaire (entité, produits/offres, événements géolocalisés, workflow de validation admin, exposition via vues/tables lisibles par l'app). Zéro table parallèle : partir de `coach_profiles`/`coach_pilots`/`partners`/`partner_leads` existants — inventaire préalable obligatoire.
