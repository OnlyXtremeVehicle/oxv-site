# PR-SÉCURITÉ — Formulaire Membre Fondateur (chantier 3)

> Surface : 🔒 Edge function `capture-membre-fondateur` + 🗄️ Supabase. Date : 2026-08-01.
> **Statut : ✅ base durcie et appliquée · ⏳ fonction v8 écrite et versionnée, DÉPLOIEMENT EN ATTENTE.**
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

## 3. Fonction v8 — écrite, versionnée, **non déployée**

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

## 4. ⚠️ État intermédiaire actuel — à connaître

L'index unique est **actif** ; la fonction **v7** l'est encore. Conséquence sur une
**deuxième soumission avec le même email** :

| | avant | maintenant (v7 + index) | après v8 |
|---|---|---|---|
| Ligne dupliquée | créée | refusée (23505) | refusée |
| 2ᵉ email + 2ᵉ Yousign **facturé** | **oui** | **non** | non |
| Ce que voit le visiteur | succès | « Une erreur est survenue. » (HTTP 500) | succès silencieux |

C'est **strictement plus sûr** qu'avant — la double facturation est déjà coupée — au
prix d'un message inutile dans ce seul cas. La v8 le transforme en succès propre.

Retour arrière si besoin : `drop index public.founding_members_email_unique;`
(rétablit le comportement d'avant, double facturation comprise).

## 5. Action requise — déploiement

Le déploiement de la fonction n'a **pas** pu être exécuté depuis cette session (refusé
par la politique d'autorisation de l'outil). À lancer depuis le dépôt :

```bash
supabase functions deploy capture-membre-fondateur --project-ref fouvuqkdxarjpjbqnsjq --no-verify-jwt
```

À vérifier juste après, sans créer ni ligne ni email ni facturation :

1. `POST` sans en-tête `Origin` → **403**.
2. `POST` avec `Origin: https://exemple.invalid` → **403**.
3. `POST` avec la bonne origine et un mauvais `x-oxv-form-token` → **403**.
4. `POST` complet avec **l'email déjà présent en base** → **200 `{ok:true}`**, et
   `select count(*) from founding_members` inchangé (chemin de déduplication : il
   traverse toute la fonction sans effet de bord).
5. Le formulaire réel sur `oxvehicle.fr/membre-fondateur` : préflight OPTIONS accepté.

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
