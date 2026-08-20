# PR-SÉCURITÉ — Formulaire Membre Fondateur (chantier 3)

> Surface : 🔒 Edge function `capture-membre-fondateur` + 🗄️ Supabase. Date : 2026-08-01.
> **Statut : ✅ livré — migration appliquée, fonction v8 DÉPLOYÉE et vérifiée en production.**
>
> Le document de reprise renvoyait à un `PR_SECURITE_FORMULAIRE_FONDATEUR.md` rédigé
> côté site : il n'existe dans **aucune branche de ce clone**. Ce fichier prend sa place.

## 1. Le constat, revérifié

`membre-fondateur.html:127` porte, en clair, dans une page servie publiquement :

```js
const FORM_TOKEN = "oxvmf_…"; // = valeur du secret OXV_FORM_TOKEN
```

Et la fonction v7 en production :

```ts
const formToken = Deno.env.get("OXV_FORM_TOKEN");
if (formToken && req.headers.get("x-oxv-form-token") !== formToken) return json({ error: "Forbidden" }, 403);
```

Deux défauts distincts :

1. **Le jeton ne protège rien.** Il est publié avec la page qu'il est censé protéger.
   Aucun secret placé dans un fichier statique n'est un secret — ce n'est pas un
   oubli à corriger, c'est une propriété du support. Le rotationner ne change rien :
   la nouvelle valeur serait publiée elle aussi.
2. **Le contrôle est en échec OUVERT.** `if (formToken && …)` : secret absent ⇒
   plus aucune vérification. C'est le piège signalé — supprimer la variable
   *ouvre* l'endpoint au lieu de le fermer.

Chaque POST accepté déclenche, sans authentification : une insertion en base,
**un email envoyé depuis `contact@oxvehicle.fr` vers une adresse choisie par
l'appelant**, et **une demande de signature Yousign facturée**.

**Yousign est bien actif en production** : l'unique ligne de `founding_members` porte
`statut = 'signature_envoyee'`. Le risque de coût n'est pas théorique.

Défaut supplémentaire trouvé en relisant : `prenom` est **interpolé sans échappement**
dans le HTML de l'email. Le domaine OXV pouvait donc relayer du balisage arbitraire.

**Vérifié bon, en revanche** : `founding_members` a RLS active sans aucune policy.
Lecture anonyme testée en réel (clé anon, PostgREST) → `[]`. Aucune fuite de PII.

## 2. Ce qui protège réellement — appliqué en base

Migration `founding_members_anti_abus` (appliquée) :

- **`founding_submit_attempts`** — une ligne par soumission acceptée, `ip_hash` SHA-256,
  RLS active **sans aucune policy**, `REVOKE ALL` sur `anon`/`authenticated` : seul le
  service-role y accède. Même forme que `app_pairing_redeem_attempts` (précédent PR-HUB-04).
- **`founding_members_email_unique`** sur `lower(email)` — un email, une candidature.

## 3. Fonction v8 — déployée

Source : [`supabase/functions/capture-membre-fondateur/index.ts`](../../supabase/functions/capture-membre-fondateur/index.ts)
(le dépôt n'avait pas de `supabase/functions/` ; il est créé ici pour que la source
déployée cesse d'exister uniquement chez Supabase).

| # | Contrôle | Effet |
|---|---|---|
| 1 | Origine exigée et restreinte à `oxvehicle.fr` / `www.oxvehicle.fr` ; CORS `*` supprimé | Le formulaire appelle `supabase.co` : l'appel est toujours cross-origin, donc un navigateur envoie **toujours** `Origin`. Son absence ne peut pas venir du formulaire. |
| 2 | Limitation par IP hachée : **3 / heure**, **10 / 24 h** | Une boucle depuis une IP est bornée. Sel = clé service-role : sans sel, un SHA-256 d'IPv4 se rebrute en 2³². Aucune IP en clair, purge > 24 h. |
| 3 | Déduplication par email → `{ok:true}` **sans** ré-insérer, ré-envoyer, re-facturer | Réponse identique à un succès : un tiers n'apprend jamais qu'une adresse est déjà inscrite. Comparaison en `eq` sur minuscules — **jamais `ilike`**, où un `%` soumis deviendrait un joker et remonterait la ligne d'autrui. |
| 4 | Plafond global **10 activations Yousign / 24 h** | Coupe-circuit de coût. Au-delà : candidature conservée, `statut = 'signature_differee'`, jamais perdue. |
| 5 | Échappement HTML de `prenom` dans l'email + longueurs bornées + format d'email validé | Le domaine OXV ne relaie plus de contenu arbitraire. |
| 6 | Gate en **échec fermé** : `OXV_FORM_TOKEN` absent ⇒ **503** | Le piège de la v7 est supprimé. Le jeton reste, mais comme hygiène — il n'écarte que les POST paresseux, et le doc le dit en tête de fichier. |

Aucun de ces contrôles ne change le parcours d'un visiteur légitime, qui soumet une fois.

## 4. Comportement sur une deuxième soumission du même email

| | avant | maintenant (v8) |
|---|---|---|
| Ligne dupliquée | créée | refusée |
| 2ᵉ email + 2ᵉ Yousign **facturé** | **oui** | **non** |
| Ce que voit le visiteur | succès | succès (silencieux, sans nouvel envoi) |

Retour arrière de l'unicité si besoin : `drop index public.founding_members_email_unique;`
(rétablit le comportement d'avant, double facturation comprise).

## 5. Vérification en production — v8, 2026-08-01

Fonction déployée : **version 8, ACTIVE**, `verify_jwt: false`. Tests exécutés en
HTTPS réel contre l'endpoint de production :

| # | Appel | Attendu | Obtenu |
|---|---|---|---|
| 1 | POST sans `Origin`, jeton valide | 403 | **403** `{"error":"Forbidden"}` |
| 2 | POST `Origin: https://exemple.invalid` | 403 | **403** `{"error":"Forbidden"}` |
| 3 | POST bonne origine, mauvais jeton | 403 | **403** `{"error":"Forbidden"}` |
| 4 | POST complet, **email déjà en base** | 200 `{ok:true}` sans effet de bord | **200** `{"ok":true,"id":"35d7…"}`, `ACAO` = l'origine seule |
| 5 | 4ᵉ appel dans l'heure | 429 | **429** `{"error":"rate_limited"}` (appels 2 et 3 en 200) |
| 6 | `OPTIONS` bonne origine | 200 + `ACAO` | **200**, `ACAO` = origine, `Vary: Origin` |
| 7 | `OPTIONS` origine invalide | 403 | **403**, aucun `ACAO` |

Le test 4 traverse **toute** la fonction (origine → jeton → validation → limitation →
déduplication) et s'arrête avant l'insertion : c'est le chemin complet, sans effet de bord.

**Aucun effet de bord constaté** : `founding_members` reste à 1 ligne, 1
`signature_envoyee` — aucune insertion, aucun email, aucune facturation. Les 3 lignes
de `founding_submit_attempts` produites par les tests ont été **supprimées**.

**Non testé** : le chemin nominal complet (nouvel email → insertion → Resend → Yousign).
Le vérifier consommerait une signature facturée et un email réel. Il n'a pas été modifié
au-delà de l'échappement de `prenom` et du passage de l'email en minuscules.

## 6. Ce que cela ne règle pas — décision produit

Ces contrôles **bornent** l'abus ; ils ne le suppriment pas. Un endpoint public qui
déclenche un envoi d'email et une facturation reste, par construction, une surface.
La suppression franche demande de sortir l'action coûteuse du chemin anonyme :

- **Double opt-in** — la soumission n'insère qu'une ligne et envoie un lien de
  confirmation ; Yousign n'est appelé qu'après clic. Reste automatique, prouve que
  l'adresse appartient au demandeur.
- **Validation admin** — la demande de signature part d'un geste humain depuis
  l'espace admin. Le plus sûr, 30 places seulement, mais ce n'est plus instantané.

Les deux changent le parcours commercial du programme Membre Fondateur : c'est un
arbitrage, pas une correction technique.
