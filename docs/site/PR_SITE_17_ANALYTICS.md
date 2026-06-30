# PR-SITE-17 — Analytics conversion

> Surface : 🌐 site (`index.html`). Date : 2026-06-30. **Statut : ✅ livré.**

## 1. Approche
Couche **tool-agnostique** + **Vercel Web Analytics** (déjà présent sur le projet ; domaine `oxvehicle.fr`, hébergé Vercel). RGPD-friendly, sans cookie.

`window.track(event, props)` envoie vers :
- **Vercel Web Analytics** (`window.va('event', …)`) ;
- **Plausible** (`window.plausible`) si branché un jour ;
- **dataLayer** (compatible GTM) — toujours alimenté.
Encapsulé dans un `try/catch` : **l'analytics ne casse jamais l'UX**.

Découverte : le site avait déjà le script Vercel (`/_vercel/insights/script.js`, fin de `<head>`) mais **sans shim** `va`. Ajout du shim de file d'attente standard (head) ; doublon de script évité.

## 2. Les 6 événements instrumentés
| Événement | Déclencheur |
|---|---|
| `view_offer` | navigation vers la page Offres (`goTo('offers')`) |
| `click_booking` | clic CTA réservation (`ctaPrimaryGo`, `source: cta_primary`) |
| `start_booking` | ouverture du tunnel (`bkOpen`) |
| `complete_booking` | réservation confirmée (`bkConfirmBooking`, props `offer` + `amount`) |
| `submit_contact` | envoi du formulaire contact réussi |
| `submit_corporate` | envoi du formulaire corporate réussi (prop `company`) |

## 3. Activation (toi)
Vercel Web Analytics doit être **activé dans le dashboard Vercel** du projet (onglet Analytics) — aucune clé ni snippet supplémentaire requis, le script et les events sont déjà en place. Les events personnalisés (`view_offer`, etc.) apparaîtront dans Vercel Analytics → Events.
- Pour passer à Plausible/PostHog plus tard : ajouter leur snippet ; `track()` les alimentera automatiquement, sans toucher aux 6 points d'instrumentation.

## 4. Critères d'acceptation
- [x] Mesure des 6 événements clés (view_offer, click_booking, start/complete_booking, submit_contact, submit_corporate).
- [x] Dashboard simple sans tracking sensible inutile (Vercel Analytics sans cookie, pas de PII envoyée — seulement `offer`/`amount`/`company` agrégés).

**Verdict : ✅ PR-SITE-17 livrée.** La piste conversion (13–17) est complète.
