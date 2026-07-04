# PR-HUB-07 — Retours clients & preuves

> Surface : 🌐 site + 🗄️ DB + ⏰ email J+1. Date : 2026-07-01. **Statut : ✅ livrée.** Boucle complète : retour → moyennes/alertes admin → témoignage double-accord → page Preuves.

## 1. Audit préalable
Rien d'existant pour les retours de session (`coach_reviews` = avis sur les coachs, 0 ligne ; `moderation_report_reviews` = modération). **Créé en réutilisant les patterns en place** : cron+edge fn (comme les relances éligibilité), idempotence `email_log`, RLS éprouvées, `registrations.status='attended'` comme déclencheur, page Preuves comme destination.

## 2. Livré
- **`session_feedback`** (migration vérifiée) : 1 retour par réservation **effectuée** (note 1-5, NPS 0-10, verbatim, `publish_ok` pilote, `published` admin). RLS : le pilote écrit/edite le sien **uniquement si la résa est `attended`** (testé : insert refusé sur résa non effectuée ✅) ; trigger-garde : impossible de s'auto-publier (`published` réservé admin). Vue **`testimonials_public`** (double accord pilote+admin, sans user_id — anon testé : 0/0 ✅).
- **Email J+1 automatique** : edge fn `feedback-request` (résa effectuée dont la session était hier, idempotent, mention « jamais publié sans votre accord ») + **cron quotidien 07:00 UTC actif** (vérifié). Test réel : HTTP 200 `sent:0`.
- **Client** (Mes sessions) : invite « Comment s'est passée votre journée du X ? » par résa effectuée sans retour → **modale** (note 1-5, NPS, verbatim, case d'autorisation) ; retour existant → « Modifier ». `track('submit_feedback')`.
- **Admin** (Bilan) : bloc **Retours clients** — note moyenne, **NPS moyen réel** (retiré de « À venir »), compteur, **alertes note < 3**, et **curation** des témoignages autorisés (Publier / Retirer).
- **Page Preuves** : « Ce qu'en disent les pilotes » — grille de témoignages publiés (★, verbatim, prénom, mois) ; l'état honnête « saison 2027 » reste tant qu'il n'y a rien.

## 3. Critères d'acceptation
- [x] Formulaire post-session (email J+1 automatique + espace pilote).
- [x] Note, NPS, verbatim, autorisation de publication.
- [x] Vue admin : moyennes + alertes < 3 + curation.
- [x] Témoignages double-accord alimentent la page Preuves (et la home via Preuves).
- [x] RLS testée : pas de retour sans session effectuée, pas d'auto-publication, public = vue seule.
