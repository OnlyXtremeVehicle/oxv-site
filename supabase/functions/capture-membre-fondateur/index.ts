// OXV — Edge function : capture Membre Fondateur
// 1) insertion Supabase  2) email de confirmation (Resend)  3) demande de signature (Yousign v3)
//
// Secrets :  supabase secrets set KEY=value
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   (fournis par la plateforme)
//   OXV_FORM_TOKEN           jeton du formulaire — voir « Ce qui protège quoi » ci-dessous
//   RESEND_API_KEY
//   YOUSIGN_API_KEY          (optionnel — si absent, la boucle signature est ignorée)
//   YOUSIGN_BASE_URL         sandbox: https://api-sandbox.yousign.app/v3   prod: https://api.yousign.com/v3
//   LOI_BUCKET, LOI_PATH     ex: documents / Lettre_Intention_Membre_Fondateur_OXV.pdf
//   FROM_EMAIL               ex: contact@oxvehicle.fr
//
// Placement de la signature : géré par Smart Anchor. Le PDF déposé DOIT contenir la balise
// {{s1|signature|180|78}} (présente, en blanc, dans la Lettre d'intention fournie). Aucune
// coordonnée à maintenir : le champ suit la balise même si le texte est modifié.
//
// ────────────────────────────────────────────────────────────────────────────
// CE QUI PROTÈGE QUOI (v8, 2026-08-01)
//
// `OXV_FORM_TOKEN` est publié en clair dans membre-fondateur.html, page servie
// publiquement. Il ne peut donc PAS protéger cet endpoint : quiconque lit la
// source du formulaire l'obtient. Il n'écarte que les POST paresseux. C'est
// structurel — aucun secret placé dans une page statique n'est un secret.
//
// Ce qui protège réellement, chaque appel déclenchant un envoi d'email depuis
// contact@oxvehicle.fr (réputation du domaine) et une demande de signature
// Yousign (facturée) :
//   1. origine exigée et restreinte (le CORS `*` est supprimé) ;
//   2. limitation par IP hachée : 3 / heure et 10 / 24 h ;
//   3. déduplication par email : un email déjà présent renvoie ok SANS ré-insérer,
//      ré-envoyer ni re-facturer — et sans révéler qu'il existait déjà ;
//   4. plafond global de 10 activations Yousign / 24 h : coupe-circuit de coût ;
//   5. échappement HTML des champs repris dans l'email : le domaine OXV ne relaie
//      pas de contenu arbitraire ;
//   6. gate en échec FERMÉ : `OXV_FORM_TOKEN` absent ⇒ 503, plus jamais passage libre.
// ────────────────────────────────────────────────────────────────────────────

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_ORIGINS = new Set([
  "https://www.oxvehicle.fr",
  "https://oxvehicle.fr",
]);

// Limites. Volontairement basses : 30 places au total, un visiteur légitime
// soumet une fois.
const MAX_PER_HOUR = 3;
const MAX_PER_DAY = 10;
const MAX_YOUSIGN_PER_DAY = 10;

function corsFor(origin: string | null) {
  const h: Record<string, string> = {
    "Access-Control-Allow-Headers": "content-type, x-oxv-form-token",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
  if (origin && ALLOWED_ORIGINS.has(origin)) h["Access-Control-Allow-Origin"] = origin;
  return h;
}
const json = (body: unknown, status = 200, origin: string | null = null) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsFor(origin), "Content-Type": "application/json" },
  });

// Pseudonymisation de l'IP. Le sel est la clé service-role, déjà présente et à
// haute entropie : sans lui, un SHA-256 d'IPv4 se rebrute en 2^32 essais.
// Aucune IP n'est jamais écrite en clair, et une rotation de clé ne fait que
// remettre les compteurs à zéro.
async function hashIp(ip: string, pepper: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(pepper + "|" + ip));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Les champs libres sont repris dans un email envoyé depuis notre domaine :
// ils y entrent comme texte, jamais comme balisage.
function esc(s: string) {
  return s.replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));
}

// Appel Yousign qui lève une erreur détaillée sur réponse non-2xx (diagnostic dans les logs).
async function yFetch(url: string, init: RequestInit, key: string) {
  const r = await fetch(url, { ...init, headers: { Authorization: `Bearer ${key}`, ...(init.headers ?? {}) } });
  const body = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`Yousign ${r.status} ${url.split("/v3/")[1] ?? url}: ${JSON.stringify(body)}`);
  return body as Record<string, string>;
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");

  if (req.method === "OPTIONS") {
    if (!origin || !ALLOWED_ORIGINS.has(origin)) return new Response("forbidden", { status: 403 });
    return new Response("ok", { headers: corsFor(origin) });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405, origin);

  // 0) Origine. Le formulaire est servi par oxvehicle.fr et appelle supabase.co :
  //    l'appel est toujours cross-origin, donc un navigateur envoie TOUJOURS
  //    `Origin`. Son absence ne peut pas venir du formulaire.
  if (!origin || !ALLOWED_ORIGINS.has(origin)) return json({ error: "Forbidden" }, 403, origin);

  // 1) Gate applicatif — en échec FERMÉ. Secret absent ⇒ le service est indisponible,
  //    jamais ouvert (piège de la v7 : `if (formToken && …)` laissait tout passer).
  const formToken = Deno.env.get("OXV_FORM_TOKEN");
  if (!formToken) {
    console.error("OXV_FORM_TOKEN absent — service fermé");
    return json({ error: "Service indisponible" }, 503, origin);
  }
  if (req.headers.get("x-oxv-form-token") !== formToken) return json({ error: "Forbidden" }, 403, origin);

  let d: Record<string, string | boolean>;
  try { d = await req.json(); } catch { return json({ error: "Invalid JSON" }, 400, origin); }

  const prenom = String(d.prenom ?? "").trim().slice(0, 80);
  const nom = String(d.nom ?? "").trim().slice(0, 80);
  const email = String(d.email ?? "").trim().slice(0, 254);
  if (!prenom || !nom || !email) return json({ error: "Champs requis manquants" }, 400, origin);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) return json({ error: "Email invalide" }, 400, origin);
  if (d.consent_rgpd !== true) return json({ error: "Consentement requis" }, 400, origin);

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, serviceKey);

  // 2) Limitation par IP hachée.
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "inconnue";
  const ipHash = await hashIp(ip, serviceKey);
  const now = Date.now();
  const dayAgo = new Date(now - 86_400_000).toISOString();
  const hourAgo = new Date(now - 3_600_000).toISOString();

  await supabase.from("founding_submit_attempts").delete().lt("created_at", dayAgo); // purge > 24 h

  const { data: recent } = await supabase
    .from("founding_submit_attempts")
    .select("created_at")
    .eq("ip_hash", ipHash)
    .gte("created_at", dayAgo);

  const attempts = recent ?? [];
  const lastHour = attempts.filter((a) => a.created_at >= hourAgo).length;
  if (lastHour >= MAX_PER_HOUR || attempts.length >= MAX_PER_DAY) {
    return json({ error: "rate_limited" }, 429, origin);
  }
  await supabase.from("founding_submit_attempts").insert({ ip_hash: ipHash });

  // 3) Déduplication par email. Réponse identique à un succès : ne jamais
  //    apprendre à un tiers qu'une adresse est déjà inscrite.
  //    Comparaison en `eq` sur la forme minuscule — surtout pas en `ilike`, où
  //    un `%` soumis par l'appelant deviendrait un joker et ferait remonter la
  //    ligne d'autrui. Une ligne héritée en casse mixte échappe à ce test : c'est
  //    l'index unique sur lower(email) qui la rattrape (23505 ci-dessous), avant
  //    tout envoi d'email et toute facturation.
  const emailLc = email.toLowerCase();
  const { data: deja } = await supabase
    .from("founding_members")
    .select("id")
    .eq("email", emailLc)
    .maybeSingle();
  if (deja) return json({ ok: true, id: deja.id }, 200, origin);

  // 4) Insertion
  const { data: row, error } = await supabase
    .from("founding_members")
    .insert({
      prenom, nom, email: emailLc,
      fonction_pro: String(d.fonction_pro ?? "").trim().slice(0, 160) || null,
      vehicule: String(d.vehicule ?? "").trim().slice(0, 160) || null,
      session_pref: (d.session_pref === "lundi" || d.session_pref === "vendredi") ? d.session_pref : null,
      consent_rgpd: true,
    })
    .select("id")
    .single();

  // Course entre deux soumissions simultanées : l'index unique tranche, et la
  // seconde reçoit la même réponse que la première.
  if (error) {
    if (error.code === "23505") return json({ ok: true }, 200, origin);
    return json({ error: "DB", detail: error.message }, 500, origin);
  }

  // 5) Email de confirmation (Resend)
  const from = Deno.env.get("FROM_EMAIL") ?? "contact@oxvehicle.fr";
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: `OXV <${from}>`,
      to: [emailLc],
      subject: "OXV — Réception de votre manifestation d'intérêt",
      html: `<div style="font-family:Inter,Arial,sans-serif;color:#0A0A0A;max-width:480px">
        <p style="letter-spacing:.28em;font-weight:700;font-size:22px">O<span style="color:#C8102E">X</span>V</p>
        <p>Bonjour ${esc(prenom)},</p>
        <p>Nous accusons réception de votre intérêt pour rejoindre le cercle des Membres Fondateurs d'OXV.</p>
        <p>Le document à signer vous parvient dans un message distinct.</p>
        <p style="color:#8A8A8A;font-style:italic;font-size:13px;margin-top:24px">« Vous ne pilotez contre personne d'autre que vous-même. » — Le principe OXV</p>
      </div>`,
    }),
  }).catch(() => {});

  // 6) Demande de signature (Yousign v3) — ignorée si YOUSIGN_API_KEY absent
  const yk = Deno.env.get("YOUSIGN_API_KEY");
  const yb = Deno.env.get("YOUSIGN_BASE_URL");
  if (yk && yb) {
    // Coupe-circuit de coût : au-delà du plafond journalier, la candidature est
    // conservée et la signature différée — elle n'est jamais perdue, seulement
    // repoussée à une reprise manuelle (statut `signature_differee`).
    const { count: yCount } = await supabase
      .from("founding_members")
      .select("id", { count: "exact", head: true })
      .not("yousign_request_id", "is", null)
      .gte("created_at", dayAgo);

    if ((yCount ?? 0) >= MAX_YOUSIGN_PER_DAY) {
      console.error(`Plafond Yousign atteint (${yCount}/24 h) — signature différée pour ${row.id}`);
      await supabase.from("founding_members").update({ statut: "signature_differee" }).eq("id", row.id);
      return json({ ok: true, id: row.id }, 200, origin);
    }

    try {
      // 6a) Récupérer la Lettre d'intention depuis Supabase Storage
      const { data: file, error: dlErr } = await supabase.storage
        .from(Deno.env.get("LOI_BUCKET") ?? "documents")
        .download(Deno.env.get("LOI_PATH") ?? "Lettre_Intention_Membre_Fondateur_OXV.pdf");
      if (dlErr || !file) throw new Error(`LOI introuvable: ${dlErr?.message ?? "fichier vide"}`);

      // 6b) Créer la demande (draft)
      const sr = await yFetch(`${yb}/signature_requests`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: `LOI Membre Fondateur — ${prenom} ${nom}`, delivery_mode: "email", timezone: "Europe/Paris" }),
      }, yk);

      // 6c) Uploader le document (multipart — ne pas fixer Content-Type).
      //     parse_anchors=true est OBLIGATOIRE : sans lui Yousign ne scanne pas les
      //     balises {{...}} du PDF (total_anchors=0), le signataire n'a aucun champ
      //     et l'activation échoue en 400 signer.field_required.
      const fd = new FormData();
      fd.append("file", file, "LOI_OXV.pdf");
      fd.append("nature", "signable_document");
      fd.append("parse_anchors", "true");
      const doc = await yFetch(`${yb}/signature_requests/${sr.id}/documents`, { method: "POST", body: fd }, yk);

      // 6d) Créer le signataire.
      //     Placement par Smart Anchor : la balise {{s1|signature|180|78}} du PDF crée le champ.
      //     => on n'envoie PAS de tableau `fields`.
      await yFetch(`${yb}/signature_requests/${sr.id}/signers`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          info: { first_name: prenom, last_name: nom, email: emailLc, locale: "fr" },
          signature_level: "electronic_signature",
          signature_authentication_mode: "no_otp",
        }),
      }, yk);

      // — Repli coordonnées manuelles (si vous retirez la balise du PDF) —
      // Origine en HAUT-GAUCHE de la page. A4 = 596 x 842 px. Ratio imposé width/height = 2.3.
      // Remplacer le corps de 6d ci-dessus par :
      //   info: { first_name: prenom, last_name: nom, email, locale: "fr" },
      //   signature_level: "electronic_signature",
      //   signature_authentication_mode: "no_otp",
      //   fields: [{ document_id: doc.id, type: "signature", page: 1, x: 72, y: 700, width: 180, height: 78 }],
      // (x/y a caler avec l'outil « Field Position » de Yousign.)

      // 6e) Activer → Yousign envoie l'email de signature
      await yFetch(`${yb}/signature_requests/${sr.id}/activate`, { method: "POST" }, yk);

      await supabase.from("founding_members")
        .update({ statut: "signature_envoyee", yousign_request_id: sr.id })
        .eq("id", row.id);
    } catch (e) {
      // La captation reste valide ; l'echec est trace (statut + logs) et non silencieux.
      console.error("Yousign:", e instanceof Error ? e.message : e);
      await supabase.from("founding_members").update({ statut: "signature_erreur" }).eq("id", row.id);
    }
  }

  return json({ ok: true, id: row.id }, 200, origin);
});
