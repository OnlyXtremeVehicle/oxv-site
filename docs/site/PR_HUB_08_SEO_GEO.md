# PR-HUB-08 — SEO & GEO (être trouvé par Google ET cité par les IA)

> Surface : 🌐 site + racine. Date : 2026-07-01. **Statut : ✅ livrée** (socle GEO + données structurées + calendrier éditorial). La rédaction des 10 articles reste à valider par le fondateur (règle du prompt maître).

## Livré
- **`llms.txt` à la racine** (GEO) : identité OXV, faits vérifiés citables (lieu, 2,2 km, 20 pilotes, prix 390/690/2 490 €, Mirror 15 €/mois·150 €/an·coach 750 €, annulation 7 j, paiement par lien), pages clés, 6 guides publiés, garde-fous doctrine (« à ne pas confondre »). Format llmstxt.org.
- **JSON-LD `SportsActivityLocation`** (LocalBusiness) : adresse postale complète (NAP), géolocalisation (45.4025, −0.156944), email — cohérent avec le footer et la page contact.
- **JSON-LD `Event` dynamique** : les 10 prochaines sessions injectées en `ItemList` de `SportsEvent` (dates réelles depuis `sessions_public` — anon-safe PR-01, indépendant du voile membres), offres agrégées 390–690 € en précommande.
- Déjà en place (rappel) : Organization, Offer, FAQPage, BreadcrumbList, Article (dynamique), Product Mirror — **8 familles de schémas** au total. Sitemap 37 URLs à jour, robots cohérent, analytics 8 événements.

## Calendrier éditorial — 10 articles à rédiger (validation fondateur)
| # | Titre de travail | Requête cible | CTA |
|---|---|---|---|
| 1 | Track day en Charente-Maritime : le guide | « track day charente maritime » | offres |
| 2 | Rouler sur le circuit de Haute Saintonge | « circuit haute saintonge roulage » | circuit |
| 3 | Prix d'une journée circuit : le vrai budget | « prix journée circuit » | offres |
| 4 | Quelle voiture pour rouler sur circuit ? | « éligibilité voiture circuit » | securite (check-up HUB-02) |
| 5 | Niveau sonore sur circuit : limites et contrôle | « limite sonore circuit db » | securite |
| 6 | Télémétrie 25 Hz : ce qu'on mesure vraiment | « télémétrie track day » | application |
| 7 | Préparer sa voiture pour un track day | « préparer voiture circuit » | securite |
| 8 | Journée circuit en Nouvelle-Aquitaine | « journée circuit nouvelle aquitaine » | calendrier |
| 9 | Après le track day : lire ses données | « analyser données circuit » | apres-journee |
| 10 | Offrir un track day : le guide | « offrir journée circuit cadeau » | offers |

(6 guides déjà publiés en complément : première fois, équipement, track day vs stage, télémétrie, RC piste, entreprise.)

## Critères d'acceptation
- [x] `llms.txt` factuel et à jour (à maintenir à chaque changement de prix/offre).
- [x] LocalBusiness + Event(s) structurés, NAP cohérente.
- [x] Calendrier éditorial 10 requêtes prioritaires (rédaction → validation fondateur).
- [x] Sitemap/robots/analytics déjà tenus (PR-16/17, COMP-06).
