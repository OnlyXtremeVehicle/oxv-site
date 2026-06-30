# PR-SITE-18 — Inventaire & nettoyage mocks / faux modules

> Objectif : aucun faux module présenté comme réel ; aucun libellé/commentaire trompeur.
> Surface : 🌐 site (`index.html`). Date : 2026-06-30. **Statut : ✅ livré** (vérifié par inventaire grep).

## 1. Déjà traité par les PR précédentes
| Élément (audit initial) | Traité en |
|---|---|
| `fakeUpload` (faux upload B2B) + `submitB2B` (faux succès) | PR-04 (supprimés) |
| Placeholders emails `[OXV Email queued]` / toasts mensongers | PR-05 (emails réels via triggers) |
| RIB factice `FR76 XXXX` | PR-06 (centralisé, marqué « à compléter ») |
| `MOCK_PAYMENTS` (nom trompeur, vraie donnée) | PR-08 (renommé `OXV_PAYMENTS`) |
| Stub Stripe mort `book: #stripe` | PR-06 (supprimé) |
| Claims app faux (« temps réel / HUD / Ghost LIVE ») | PR-13 (corrigés) |

## 2. Nettoyé dans cette PR
1. **Libellé articles faux** (admin, « Comment ça marche ») : disait « enregistrés **dans ce navigateur** (localStorage) » → **faux**, les articles sont en Supabase (vérifié : `from('articles')` select/update/upsert/delete + table existante). Corrigé : « dans la base OXV (Supabase), partagés entre admins ». Suppression de la phrase contradictoire « une table Supabase pourra être branchée ».
2. **Mockup « Lecture de votre session » (Coach IA)** : les 4 cartes utilisaient un ton **prescriptif** (« Travaillez… », « Visualisez… », « Continuez sur cette voie ») + tags « ⚠ Priorité », contredisant la doctrine produit **« miroir, pas un coach »** (le vrai app interdit les verbes directifs). Reformulées en **observations descriptives** (« la dimension où la trace varie le plus », « la trace le montre — à vous d'en faire ce que vous voulez ») + tags neutres (« ○ Plus de marge » / « ● Point fort ») + mention « un exemple de lecture, pas une consigne ». Le bloc reste honnêtement étiqueté « Exemple de rapport QDI » (l.16024).
3. **Commentaires de code périmés** corrigés (accuracy) : `stub avec coming-soon` (pages en fait implémentées), `couche données (localStorage)` / `CRUD localStorage` (articles en Supabase), `TODO Supabase : remplacer les setTimeout` (auth déjà réelle), `placeholder Resend` (email via trigger PR-05).

## 3. Examiné et laissé volontairement (non « faux module »)
- **Mockup progression (scores QDI, niveaux)** : déjà honnêtement étiqueté « **Exemple de rapport QDI tel que vous le recevrez. Vos données réelles apparaîtront après votre première session · 2027** » (l.16024). Acceptable — c'est annoncé comme un exemple, pas comme la donnée réelle du pilote.
- **Tooltips de virage page Circuit** (« Visualisez le point de corde de T5 ») : briefing **piste réel** (guide du tracé), légitimement instructionnel ; la doctrine « miroir » concerne l'app, pas le briefing circuit. Laissés.
- **`placeholder=` (attributs input)** et **`TODO` de code** restants : légitimes (placeholders de formulaire, vrais TODO techniques), pas des faux modules.
- **App mobile « BIENTÔT »** (footer) : annonce honnête.
- **~18 `console.log`** de diagnostic : hygiène prod (à nettoyer avant build final), pas des faux modules — non bloquant.

## 4. Vérification (inventaire grep)
- `dans ce navigateur` : 0 · `stub avec coming-soon`/`placeholder Resend`/`TODO Supabase`/`CRUD localStorage` : 0 · impératifs reco (`Travaillez/Visualisez/Continuez`) dans le mockup app : 0 (les 2 restants = page Circuit, hors scope) · « dans la base OXV » présent ✅.

## 5. Critères d'acceptation
- [x] Aucun faux module présenté comme réel (fakeUpload/submitB2B/emails/MOCK_PAYMENTS/stub Stripe déjà retirés ; libellé articles & mockup Coach IA corrigés).
- [x] Libellés et commentaires alignés sur la réalité (Supabase, auth réelle, emails réels).

## 6. Suivis (non bloquants)
- Nettoyage des `console.log` de diagnostic avant build de prod.
- Harmonisation vocabulaire **QDI** (site) vs **« marge »** (app) — passe éditoriale / V2.
- Découpage technique d'`index.html` → **PR-SITE-19**.

**Verdict : ✅ PR-SITE-18 livrée.**
