# Intégration app — appairage par code (PR-HUB-04)

> Pour le dépôt de l'app mobile. Endpoint **déployé et testé** le 2026-07-01. Le compte est déjà commun (même Supabase) : ce flux évite seulement la saisie du mot de passe dans l'app.

## Flux utilisateur
1. Le client, connecté sur oxvehicle.fr → Compte → Préférences → **« Connecter l'app »** → bouton *Générer mon code* → code 8 caractères affiché (ex. `KM4T 7WXP`), valable **10 minutes**, **usage unique**.
2. Dans l'app : écran « J'ai un code OXV » → saisie du code.
3. L'app appelle `redeem`, reçoit un `token_hash`, appelle `verifyOtp` → session Supabase ouverte.

## Endpoint
`POST https://fouvuqkdxarjpjbqnsjq.supabase.co/functions/v1/pair-app` (JSON, pas de JWT requis pour `redeem`)

### redeem (côté app)
```json
{ "action": "redeem", "code": "KM4T7WXP" }
```
Réponses :
- `200` → `{ "token_hash": "…", "verify_type": "magiclink" }`
- `400` → `{ "error": "invalid_or_expired" }` (code faux, déjà utilisé, ou > 10 min — message unique volontaire, ne pas distinguer côté UI)
- `429` → `{ "error": "rate_limited" }` (10 tentatives/min/IP — afficher « réessayez dans une minute »)

Le code peut être saisi avec espaces/minuscules : le serveur normalise (`A-Z 2-9`, 8 caractères, sans 0/O/1/I/L).

### Ouverture de session (supabase-js v2)
```ts
const { token_hash, verify_type } = await redeemResponse.json();
const { data, error } = await supabase.auth.verifyOtp({ type: verify_type, token_hash });
// data.session = session complète (access + refresh token) — persister comme un login normal
```

## Sécurité (côté serveur, déjà en place)
- Code : alphabet 32 symboles × 8 → ~1,1 × 10¹² combinaisons ; fenêtre 10 min ; usage unique (consommation atomique) ; un seul code actif par utilisateur (le nouveau invalide l'ancien).
- Anti-brute-force : 10 redeem/min/IP (IP hashée SHA-256, jamais stockée en clair, purge > 1 h).
- `generate` exige le JWT utilisateur (le site l'attache automatiquement) → impossible de générer un code pour autrui.
- Table `app_pairing_codes` : RLS testée (anon = 0 ligne, autre user = 0, propriétaire = ses codes seulement, INSERT client refusé).

## Vérifications déjà effectuées côté site
- `redeem` code invalide → HTTP 400 `invalid_or_expired` ✅ (test réel)
- `generate` sans JWT → HTTP 401 `auth_required` ✅ (test réel)
- Reste à tester côté app : redeem d'un code **valide** → `verifyOtp` → session (nécessite le build app).
