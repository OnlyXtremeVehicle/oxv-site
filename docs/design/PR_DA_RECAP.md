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
