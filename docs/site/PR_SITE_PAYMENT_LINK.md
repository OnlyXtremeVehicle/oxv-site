# PR-SITE — Paiement par lien (CB / Visa / PayPal / Apple Pay) + retrait des faux RIB

> Surface : 🌐 site (`index.html`). Date : 2026-06-30. **Statut : ✅ livré.** Déclencheur : décision produit — paiement par **lien hébergé** (CB/Visa/PayPal/Apple Pay) « une fois prêt », plus de virement final.

## 1. Problème
Le parcours affichait un **faux RIB** (`FR76 XXXX…`, BIC `XXXXXXXX`) en fin de réservation, dans l'espace pilote et côté admin, et tous les textes supposaient un **virement** / nommaient **Stripe**. Or le paiement se fera via un **lien de paiement sécurisé** multi-moyens, pas encore prêt. Risque : afficher de fausses coordonnées bancaires et des promesses incohérentes.

## 2. Solution — point de bascule unique `OXV_PAYMENT`
Objet de config front, **source unique de vérité** :
```js
window.OXV_PAYMENT = { mode:'pending', linkUrl:'', linkByOffer:null, methods:['CB','Visa','PayPal','Apple Pay'] };
```
- **`mode:'pending'` (aujourd'hui)** → état honnête : « Votre réservation est enregistrée. Un lien de paiement sécurisé (CB, Visa, PayPal, Apple Pay) vous sera envoyé par email pour confirmer votre place. » + référence + montant. **Aucun IBAN/BIC.**
- **`mode:'link'` + `linkUrl`** (le jour J) → bouton **« Payer maintenant »** vers le lien + liste des méthodes. Fallback gracieux sur `pending` si l'URL est vide.
- Helpers : `oxvPaymentLink(offerType)` (gère `linkByOffer` par offre) + `bkRenderPaymentConfirm(reg, priceDeposit, offerType)` (rend `#bkConfirmPayment`).

**Pour activer le paiement** : passer `mode:'link'` et renseigner `linkUrl` (ou `linkByOffer`). Une seule ligne à changer.

## 3. Portée des changements (10 zones)
- **Booking étape 5** : bloc faux-RIB → `#bkConfirmPayment` dynamique ; sous-titre + bandeau réécrits.
- **Booking étape 4** : option « Carte bancaire » → « Paiement en ligne sécurisé » ; bandeau lancement réécrit ; récap « Mode paiement » → « Montant dû ».
- **`bkConfirmBooking`** : suppression de l'objet `OXV_RIB` local + des `bkSetTxt` RIB → un seul `bkRenderPaymentConfirm(...)`. **INSERT registrations/payments STRICTEMENT inchangés.**
- **Espace pilote** : bloc IBAN/BIC + bandeau Stripe → encart « Paiement en ligne sécurisé · aucune coordonnée bancaire à saisir ». Ancre `#ibanSection` → `#paymentSection` (scroll préservé).
- **Admin paiements** : faux IBAN/BIC → renvoi vers `OXV_PAYMENT` ; modale « Valider le virement » → « Valider le paiement » (mécanisme de validation manuelle **conservé**) ; bandeau + confirm réécrits.
- **Textes publics** : home, « comment ça marche » (aligné J-7 / CGV), CTA calendrier, **FAQ visible + JSON-LD identiques**, manifeste — neutralisés en « paiement en ligne sécurisé ».
- **CGV** : Art.3 (virement→moyens proposés), RGPD (« exclusivement Stripe » → « prestataire PCI-DSS »), sous-traitant Stripe → « prestataire de paiement sécurisé (PCI-DSS) ».

## 4. Méthode (mode rigoureux)
- **Audit parallèle** (4 lentilles, 43 trouvailles) → plan de synthèse → implémentation → **vérification adversariale** (3 lentilles : régression JS, contradictions résiduelles, honnêteté/UX) → **3× PASS**, puis correction des points relevés (incohérence admin « virement » vs « Paiement OXV », label récap, vestiges `#ibanSection`/commentaires).

## 5. Vérification finale
- **0** faux RIB (`FR76 XXXX`/`XXXXXXXX`/`OXV_RIB`), **0** `bkRib*` orphelin, **0** `ibanSection`, **0** Stripe/virement client-facing.
- `OXV_PAYMENT` + `bkRenderPaymentConfirm` + `#bkConfirmPayment` présents ; **6/6 JSON-LD valides** ; FAQ visible ↔ JSON-LD identiques ; **52/52 `<section>`**.
- INSERT registrations/payments inchangés (anti-doublon + heritage_packs intacts) ; `payment_method` reste `bkState.selectedPayment`.

## 6. Hors périmètre (suivi)
- **Backend** : Edge Function `create-payment-link` (création de session PSP, stockage `stripe_payment_intent_id`/URL, webhook de confirmation) → remplacera la validation manuelle. Emails `send-payment-confirmed`/`send-booking-confirmation` à aligner.
- **CGV** : finaliser le **nom + la juridiction du prestataire** une fois le PSP choisi (placeholder « prestataire PCI-DSS » en attendant).
- **Code mort** : `loadBilling` (≈25416-25557) référence des ids DOM inexistants (no-op) → à nettoyer ou recâbler.

**Verdict : ✅ livré.** Le site n'affiche plus aucune fausse coordonnée bancaire ; le paiement s'activera par simple bascule `OXV_PAYMENT.mode='link'`.
