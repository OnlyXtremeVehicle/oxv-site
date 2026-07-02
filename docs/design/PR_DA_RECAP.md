# Refonte DA V3 « Premium Racing Minimal » — récapitulatif des 12 lots

> Branche : `claude/design-v2`. Date : 2026-07-01. Source : `OXV_Site_Direction_Artistique_Complete_V3.docx`. **Statut : ✅ 12/12 lots livrés.** Prod (`main`) intacte jusqu'au merge.

| Lot | Livré |
|---|---|
| **DA-01 Tokens** | Palette V3 (`--carbon #050505`, `--anthracite #0B0D10`, `--acier #1A1D22`, `--offwhite #F5F2EA`, `--red-oxv #D80F1F`, `--blue-data #4A8CFF`, `--gold-data #C9A24A`) ; typo Space Grotesk (titres) / Inter (corps) / IBM Plex Mono (data) ; re-pointage `--cream`/`--night-card`/`--oxv-red`/`--oxv-gold`. Data-viz QDI **intouchée**. |
| **DA-02 Navigation** | Fonds nav carbone/anthracite ; CTA sticky rouge (`#navCtaJoin`). |
| **DA-03 Hero** | « L'expérience circuit augmentée. » + « Roulez. Gardez la trace. Comprenez votre session. » ; CTA « Demander une place » (rouge) + « Découvrir l'expérience » (scroll). |
| **DA-04 Home** | Nouvelle section **Expérience Avant/Pendant/Après** (« La journée est préparée / L'app se tait. OXV observe / La session devient lisible ») ; nouvelle section **Média** (flux capture → import/attribution → validation → livraison app, sans fausse galerie) ; fix doctrine (« classements de régularité » supprimé) ; kickers renumérotés 01→08. |
| **DA-05 Offres** | Prix en IBM Plex Mono + € or data ; carte Signature accent **rouge** (au lieu d'or). Prix inchangés. |
| **DA-06 Page Application** | Nouvelle page publique `application` : 7 espaces (Pass, Trace du jour, Data Lab, Médias livrés, Carnet, Coach opt-in, Saison — accents bleu data) + bloc « **Ce que l'app ne dira jamais** » + CTA. Footer « App OXV Trace 2027 » (remplace le toast), CTA home, SEO map, sitemap. |
| **DA-07 UI kit** | `.btn-primary` : or → **rouge OXV, texte blanc** (tous les CTA du site) ; cartes bento anthracite. |
| **DA-08 Corporate** | Bloc « Média pour vos invités » + « Application & reporting » avant le formulaire de devis. |
| **DA-09 Mobile/perf** | Images : 7 `<img>`, lazy OK, hero eager (correct) ; grilles auto-fit (empilage mobile natif) ; police Syncopate inutilisée **retirée du chargement**. |
| **DA-10 Motion** | Système `.reveal` existant (137 usages) conforme (apparition douce) ; 0 usage bounce ; aucun effet gaming ajouté. |
| **DA-11 SEO visuel / assets** | **Réparé 7 assets 404 (déjà cassés en prod)** : `brand/insignia.svg` + `brand/favicon.svg` (vrai insigne extrait du symbol inline) + favicons PNG 16/32/192/512, apple-touch-icon, favicon.ico (monogramme OXV carbone/rouge, fallback en attendant des exports définitifs). OG cover existante conservée. |
| **DA-12 QA** | 61/61 sections · 0 marqueur · 0 nav cassée · 53 pages · 6/6 JSON-LD · 0 couleur legacy (`#C8102E`/`#C4A459` = 0) · doctrine clean · assets complets · `node --check` OK. |

## Charte résiduelle purgée
- `#C4A459` (37×, états « pending » admin/compte) → `#C9A24A` (or V3).
- `#E63946`/`#FFB703`/`#FFC93C` restants = **data-viz QDI + SVG circuit** (fonctionnels, préservés volontairement).

## Notes
- **Contraintes respectées** : aucun prix modifié, aucun formulaire/booking/admin/auth touché, routeur SPA intact, aucune promesse prescriptive.
- Les favicons PNG sont des monogrammes générés (fallback propre) — à remplacer par des exports définitifs de l'insigne quand disponibles ; `favicon.svg` (prioritaire pour les navigateurs modernes) est déjà le vrai insigne.
- Visuels hero = images stock existantes ; à remplacer après le premier shooting réel (DA §20 shot list).

---

## Addendum — refonte profonde + réorganisation « grandes marques » (2026-07-01)

Suite au retour utilisateur (« pas juste la couleur et les polices »), deux passes supplémentaires :

### Refonte profonde du langage visuel (`a758181`)
- Fin de l'italique-majuscules sur ~35 familles de grands titres + 59 titres inline → sentence case, tracking -0.02em, poids 600, titres monochromes.
- Kickers/eyebrows : or → **mono rouge OXV**. CTA : mono-uppercase → sans 14-15px/500. Cartes : glassmorphism → anthracite plat. Hero jusqu'à 128px. **Mockups téléphone OXV Trace** (pur CSS, bleu data) home + page application.

### Réorganisation structurelle (`cd4e55a`)
- **Home resserrée au récit DA §18** : Hero → Expérience → Offres → App → Média → **Confiance (nouveau)** → CTA final.
- Sections deep-dive relogées : QDI/data → page **application** · rituels J-7/J-2/J-1 → page **« Votre journée »** (ex Après-journée, retitrée, couvre avant+après, SEO/footer alignés) · écosystème → page **à-propos**.
- **Nav épurée** : 10 → 5 liens (Offres · Circuit · Application · Corporate · Actualités), **un seul CTA** « Demander une place » (JS de bascule connecté/déconnecté aligné) ; burger mobile enrichi (Application, Votre journée).

### Compatibilité vérifiée (à chaque étape)
- **5 variables CSS jamais définies corrigées** (`--obsidian` = fond section data transparent en prod !, `--void`, `--cream-glow`, `--copper-bright`, `--red-warn`).
- 62/62 sections · 0 nav cassée · sections déplacées vérifiées dans les bonnes pages · 0 var indéfinie · 6/6 JSON-LD · hooks JS intacts (aucun sur les sections déplacées, `heroClock`/`navCtaJoin`/`updateCalGate` préservés) · `node --check` OK.
