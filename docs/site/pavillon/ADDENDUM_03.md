# ADDENDUM 03 — LOT ÉCRANS PAVILLON

**A10 verrouillé par M. Fillat le 18/07/2026 sous forme de RELAIS DÉCLARATIF. Aucune connexion à la direction de course du circuit n'existe ni n'est simulée.**

## A10 — Drapeaux : relais déclaratif manuel

**Contrat temps réel — canal 4 étendu (v2, rétrocompatible) :**
```json
{ "v": 2, "etat": "ouverte" | "pause" | "fermee" | "veille",
  "drapeau": "jaune" | "rouge" | null,
  "drapeau_ts": "2027-07-08T14:32:00Z",
  "message": "optionnel", "ts": "…" }
```

**Règles (bloquantes en QA) :**
1. **Le drapeau vert n'existe pas dans le système.** Valeurs possibles : `jaune`, `rouge`, `null`. `null` = aucun bandeau. Un relais périmé ne peut donc jamais rassurer à tort — l'erreur possible est toujours du côté de la prudence.
2. Émetteur : espace Staff/Ops (lot app). Le staff relaie ce que la direction de course affiche ; il lève le drapeau (`null`) manuellement.
3. Affichage : bandeau pleine largeur en haut des DEUX écrans (`/pavillon/accueil` et `/pavillon/coach`, tous modes), sous le header.
   - `jaune` : bandeau fond `#0A0A0A`, liseré supérieur et inférieur 3px `#FFB703`, texte « DRAPEAU JAUNE » Syncopate 700, JetBrains Mono pour le reste. (Le jaune `#FFB703` est ici un code de signalisation piste universel, pas une couleur QDI — usage distinct, documenté en commentaire.)
   - `rouge` : liserés `#C8102E`, texte « DRAPEAU ROUGE — PISTE NEUTRALISÉE ».
   - Dans les deux cas : « Signalé {HH:MM} » + mention fixe « Information indicative — seuls les signaux du circuit font foi. »
4. Le bandeau prime visuellement sur tout contenu de l'écran mais ne masque rien (les écrans restent lisibles dessous).
5. Aucune animation clignotante — le bandeau apparaît/disparaît en 200 ms, puis reste stable (un écran qui clignote en continu cesse d'être lu).
6. Persistance : le dernier message reçu fait l'état ; au chargement sans message, `drapeau = null`.

**QA supplémentaire :**
- [ ] Grep : la chaîne « vert » n'existe pas dans le code drapeaux ; le type n'admet que `jaune | rouge | null`.
- [ ] Message `drapeau: "vert"` reçu (émetteur défectueux) → traité comme valeur inconnue : ignoré, warn, bandeau inchangé.
- [ ] Bandeau visible dans les 4 modes coach et les 4 états accueil (`?demo=1&drapeau=jaune|rouge`).
- [ ] La mention légale est présente dans chaque rendu du bandeau (assertion sur le texte).
- [ ] `drapeau_ts` affiché en heure locale Europe/Paris.

**Note RDV assureur (hors code) :** présenter le dispositif comme relais d'information horodaté, sans drapeau vert, avec mention d'autorité des signaux physiques. Ne jamais le qualifier de système de signalisation dans un document contractuel.
