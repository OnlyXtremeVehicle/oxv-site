-- ============================================================
-- La vocation du véhicule : ce qu'il EST
-- ============================================================
-- APPLIQUÉE en production le 2026-09-01 (colonne + préremplissage).
-- Décision fondateur : « vocation déclarée ».
--
-- POURQUOI. Le rapport masse/puissance est un QUOTIENT : il jette l'échelle.
-- 135 ch pour 540 kg et 585 ch pour 2 200 kg donnent le même nombre. D'où,
-- avant cette colonne :
--   · Classe III de 180 ch (Caterham 360R) à 2 011 ch (Lotus Evija) ;
--   · Classe II contenant une Peugeot 308 GTi ET une Porsche 996 GT3, une
--     Ferrari Testarossa, un Audi RS Q8 de 2,3 t et une Caterham de 540 kg.
--
-- La vocation est DÉCLARÉE, jamais calculée. Aucun couple (ch, kg) ne dit
-- qu'une voiture est une compacte de série plutôt qu'un coupé à vocation
-- piste : c'est un fait sur l'objet, pas sur ses mesures.
--
-- ── DEUX ÉTAPES, ET SEULE LA PREMIÈRE EST FAITE ─────────────
-- ÉTAPE 1 (ici) : la colonne, sa contrainte, son préremplissage par règle.
--   La colonne `classe` n'est PAS touchée. Ajouter une colonne ne change rien ;
--   changer la classe change qui roule avec qui. Le fondateur valide les
--   vocations avant que la règle ne bouge.
--
-- ÉTAPE 2 (à venir, sur validation) : `classe` devient fonction de la vocation
--   ET du rapport. Le rapport ne disparaît pas — il gradue À L'INTÉRIEUR d'une
--   vocation, avec des bornes propres à chacune. Forme proposée :
--
--     vocation      Classe I          Classe II           Classe III
--     serie         ratio >= 4,0      3,0 <= r < 4,0      r < 3,0
--     gt            ratio >= 4,5      3,0 <= r < 4,5      r < 3,0
--     supersport    —                 ratio >= 3,5        r < 3,5
--     barquette     —                 ratio >= 2,5        r < 2,5
--     suv           ratio >= 4,0      ratio < 4,0         —
--
--   Effet sur les cas qui ont déclenché la demande : la 308 GTi (serie, 4,43)
--   passe en Classe I ; la 911 997 Carrera (gt, 4,29), l'Alpine A110 (gt, 4,40)
--   et l'Alfa 4C (gt, 4,27) restent en II ; la Caterham 620R (barquette, 1,85)
--   reste en III sans être « avec les Ferrari » au sens du plateau.

ALTER TABLE public.vehicules_eligibles ADD COLUMN IF NOT EXISTS vocation text;

ALTER TABLE public.vehicules_eligibles DROP CONSTRAINT IF EXISTS vehicules_eligibles_vocation_connue;
ALTER TABLE public.vehicules_eligibles ADD CONSTRAINT vehicules_eligibles_vocation_connue
  CHECK (vocation IS NULL OR vocation IN ('serie', 'gt', 'supersport', 'barquette', 'suv'));

COMMENT ON COLUMN public.vehicules_eligibles.vocation IS
  'Ce que le vehicule EST. serie = compacte ou berline sportive de grande serie. gt = coupe ou roadster a vocation piste. supersport = supersportive. barquette = voiture legere de piste. suv = SUV et crossovers. Declaree, jamais calculee.';

CREATE INDEX IF NOT EXISTS vehicules_eligibles_vocation_idx
  ON public.vehicules_eligibles (vocation) WHERE statut = 'actif';

-- Préréglage des 532 vocations, par règle sur la marque puis sur le modèle.
-- Du plus spécifique au plus général ; `serie` est le défaut, jamais un choix.
UPDATE public.vehicules_eligibles SET vocation = CASE

  -- Barquettes et voitures légères de piste. Ni pare-brise ni compromis.
  WHEN marque IN ('Caterham','Ariel','KTM','Radical','BAC','Praga','Vuhl',
                  'Donkervoort','Elemental','Zenos','Westfield','Ultima',
                  'Norma','Ginetta','Secma','PGO','Dallara')
    THEN 'barquette'
  WHEN modele IN ('2-Eleven','3-Eleven','Spider','JS2') THEN 'barquette'

  -- SUV et crossovers. Gardés au référentiel (décision fondateur), mais
  -- nommés : deux tonnes qui freinent au même endroit que 1 400 kg.
  WHEN modele ~* '^(Urus|Cayenne|Macan|RS Q8|RS Q3|X3 M|Stelvio|Model Y|EV6|Ioniq 5 N|Formentor)$'
    THEN 'suv'

  -- Supersportives.
  WHEN marque IN ('Ferrari','Lamborghini','McLaren','Pagani','Koenigsegg',
                  'Bugatti','Noble','Ruf')
    THEN 'supersport'
  WHEN (marque = 'Porsche' AND modele IN ('Carrera GT','918'))
    OR (marque = 'Ford' AND modele = 'GT')
    OR (marque = 'Lexus' AND modele = 'LFA')
    OR (marque = 'Maserati' AND modele = 'MC20')
    OR (marque = 'Lotus' AND modele = 'Evija')
    THEN 'supersport'

  -- Coupés et roadsters à vocation piste.
  WHEN marque = 'Porsche' AND modele IN ('911','Cayman','Boxster','928','944','968','924')
    THEN 'gt'
  WHEN marque IN ('Alpine','TVR','Morgan','Wiesmann','Spyker','Lotus')
    THEN 'gt'
  WHEN marque = 'Aston Martin' THEN 'gt'
  WHEN marque = 'Renault' AND modele = 'Alpine' THEN 'gt'
  WHEN marque = 'Alfa Romeo' AND modele IN ('4C','GTV6') THEN 'gt'
  WHEN marque = 'Jaguar' AND modele IN ('F-Type','E-Type','XKR','XKR-S','XKR-S GT') THEN 'gt'
  WHEN marque = 'Nissan' AND modele IN ('GT-R','Skyline','Z','370Z','350Z','300ZX','Silvia','200SX')
    THEN 'gt'
  WHEN marque = 'Mazda' AND modele IN ('RX-7','RX-8','MX-5') THEN 'gt'
  WHEN marque = 'Toyota' AND modele IN ('Supra','GR Supra','GT86','GR86','MR2','Celica','Corolla')
    THEN 'gt'
  WHEN marque = 'Subaru' AND modele = 'BRZ' THEN 'gt'
  WHEN marque = 'Honda' AND modele IN ('S2000','NSX','Prelude') THEN 'gt'
  WHEN marque = 'BMW' AND modele IN ('Z3','Z4') THEN 'gt'
  WHEN marque = 'Mercedes-AMG' AND modele ~* '^(SLK|SLS|GT|GT R|GT 63 S|SL63|SLK32|SLK55)$' THEN 'gt'
  WHEN marque = 'Audi' AND modele IN ('TT','TT RS','TTS','R8') THEN 'gt'
  WHEN marque = 'Chevrolet' AND modele IN ('Corvette','Camaro') THEN 'gt'
  WHEN marque = 'Ford' AND modele = 'Mustang' THEN 'gt'
  WHEN marque = 'Dodge' AND modele = 'Viper' THEN 'gt'
  WHEN marque = 'Lexus' AND modele IN ('RC F','LC','IS F') THEN 'gt'
  WHEN marque = 'Maserati' AND modele = 'GranTurismo' THEN 'gt'
  WHEN marque = 'Bentley' THEN 'gt'
  WHEN marque = 'Polestar' AND modele = '1' THEN 'gt'
  WHEN marque = 'Mitsubishi' AND modele IN ('3000GT','FTO') THEN 'gt'
  WHEN marque = 'Abarth' AND modele = '124' THEN 'gt'
  WHEN marque = 'Renault' AND modele = 'Clio' AND generation ~* 'V6' THEN 'gt'
  WHEN marque = 'Opel' AND modele = 'Speedster' THEN 'gt'
  WHEN marque = 'Volkswagen' AND modele = 'Corrado' THEN 'gt'

  -- Tout le reste : compactes et berlines sportives de grande série.
  ELSE 'serie'
END;

-- Résultat du préréglage sur les 449 lignes actives :
--   gt 180 · serie 171 · supersport 61 · barquette 25 · suv 12
--
-- ⚠️ CE QUE LE PRÉRÉGLAGE NE SAIT PAS FAIRE, et qui reste au fondateur :
-- 47 lignes sortent des bornes attendues de leur vocation — une « série » très
-- rapide (Taycan Turbo GT, 1 034 ch), une « gt » très lente (MX-5 ND2, 5,71),
-- une « supersport » modeste (Ferrari 348, 4,64). Aucune règle sur la marque ne
-- tranche ces cas : ils se lisent un par un.
