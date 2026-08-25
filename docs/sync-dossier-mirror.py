# -*- coding: utf-8 -*-
"""Synchronise la page /dossier-mirror depuis le depot app.

Source de verite : oxv-app/docs/presentation/ (handoff du 25/08/2026).
L'URL https://oxvehicle.fr/dossier-mirror est IMPRIMEE en QR dans le PDF :
le nom de fichier cible ne doit jamais changer.

Usage :
    python docs/sync-dossier-mirror.py [chemin_du_depot_app]

Ce que le script fait, a chaque nouvelle version du dossier :
  1. copie DOSSIER_FRENCH_TECH_2026-08-24.html -> dossier-mirror.html (racine)
  2. copie OXV_Mirror_Dossier_French_Tech.pdf  -> racine (meme nom)
  3. re-injecte les deux ajouts qui appartiennent au SITE, pas au dossier :
     - la meta viewport (le fichier source est un corps d'artefact copie sans
       son enveloppe : ses cinq media queries mobiles ne s'appliquent jamais
       sans elle)
     - le bloc de mesure d'audience (Plausible demande par le handoff +
       relais Vercel Analytics deja actif sur le domaine), sans cookie,
       avec l'evenement sur le bouton \u00ab Rouler \u00d78 \u00bb (#dPlay)
Les injections sont idempotentes : relancer le script ne duplique rien.
"""
import io
import os
import shutil
import sys

SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = sys.argv[1] if len(sys.argv) > 1 else r"C:/Users/Gabin/Documents/oxv-app"

SRC_HTML = os.path.join(APP, "docs", "presentation", "DOSSIER_FRENCH_TECH_2026-08-24.html")
SRC_PDF = os.path.join(APP, "docs", "presentation", "OXV_Mirror_Dossier_French_Tech.pdf")
DST_HTML = os.path.join(SITE, "dossier-mirror.html")
DST_PDF = os.path.join(SITE, "OXV_Mirror_Dossier_French_Tech.pdf")

VIEWPORT = u'<meta name="viewport" content="width=device-width, initial-scale=1">'

MESURE = u"""
<!-- oxv-site:mesure \u2014 ajout du site, re-injecte par docs/sync-dossier-mirror.py.
     Sans cookie. Pageview + evenement \u00ab demonstration essayee \u00bb sur #dPlay.
     Plausible n'enregistre qu'une fois le domaine oxvehicle.fr declare dans un
     compte Plausible ; le relais Vercel Analytics mesure des aujourd'hui. -->
<script>
  window.va = window.va || function () { (window.vaq = window.vaq || []).push(arguments); };
  window.plausible = window.plausible || function () { (window.plausible.q = window.plausible.q || []).push(arguments); };
  (function () {
    function mesure(nom) {
      try { window.va('event', { name: nom }); } catch (e) {}
      try { window.plausible(nom); } catch (e) {}
    }
    function armer() {
      var b = document.getElementById('dPlay');
      if (b) b.addEventListener('click', function () { mesure('dossier_demo_essayee'); });
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', armer);
    else armer();
  })();
</script>
<script defer src="/_vercel/insights/script.js"></script>
<script defer data-domain="oxvehicle.fr" src="https://plausible.io/js/script.js"></script>
"""


def principal():
    for src in (SRC_HTML, SRC_PDF):
        if not os.path.isfile(src):
            raise SystemExit("source introuvable : %s" % src)

    s = io.open(SRC_HTML, encoding="utf-8").read()
    n0 = len(s)

    # 1. viewport, juste apres la meta charset
    if 'name="viewport"' not in s:
        ancre = u'<meta charset="utf-8">'
        if ancre not in s:
            raise SystemExit("meta charset introuvable \u2014 structure du dossier changee, verifier avant de servir")
        s = s.replace(ancre, ancre + u"\n" + VIEWPORT, 1)
        print("  + viewport injecte")
    else:
        print("  = viewport deja present")

    # 2. bloc de mesure, en fin de document
    if u"oxv-site:mesure" not in s:
        s = s.rstrip() + u"\n" + MESURE
        print("  + bloc de mesure injecte (pageview + #dPlay)")
    else:
        print("  = bloc de mesure deja present")

    io.open(DST_HTML, "w", encoding="utf-8", newline="").write(s)
    print("  -> %s (%d -> %d caracteres)" % (os.path.basename(DST_HTML), n0, len(s)))

    shutil.copyfile(SRC_PDF, DST_PDF)
    print("  -> %s (%d octets)" % (os.path.basename(DST_PDF), os.path.getsize(DST_PDF)))

    if u'id="dPlay"' not in s:
        print("  !! avertissement : #dPlay absent du dossier \u2014 l'evenement ne se declenchera pas")


if __name__ == "__main__":
    principal()
