// =============================================================================
// OXV — Edge Function : validate-inscription  (RÉELLE)
// =============================================================================
// Traite une demande d'inscription (table public.demandes_inscription) :
//
//   action = "accept"      -> crée le compte Supabase Auth (service_role) avec
//                             le bon rôle, crée/complète la ligne public.users
//                             (id == auth.users.id, email unique), génère un
//                             lien "définir mon mot de passe" (recovery),
//                             envoie l'e-mail d'acceptation, journalise dans
//                             email_log, passe la demande en 'acceptee'.
//   action = "reject"      -> envoie l'e-mail de refus, passe en 'refusee'.
//   action = "acknowledge" -> envoie l'accusé de réception (statut inchangé).
//
// AUTH : serveur-à-serveur par secret partagé.
//   En-tête  : x-oxv-admin-secret: <VALIDATE_INSCRIPTION_SECRET>
//   DORMANTE par défaut : si le secret n'est PAS configuré, la fonction refuse
//   tout appel (503 function_disabled). On l'arme en posant le secret.
//
// DÉPLOIEMENT : verify_jwt = false (auth maison par secret, pas de JWT).
//
// Secrets requis pour fonctionner une fois armée :
//   VALIDATE_INSCRIPTION_SECRET  (le secret S2S — absent = dormante)
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (présents d'office)
//   RESEND_API_KEY               (déjà utilisé par ritual_dispatcher)
// Optionnels :
//   SITE_URL (def. https://www.oxvehicle.fr) — base du lien de redirection
// =============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  renderApproval,
  renderRejection,
  renderAcknowledgement,
} from './emails.ts';

const RESEND_API_URL = 'https://api.resend.com/emails';
const FROM = 'OXV <contact@oxvehicle.fr>';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-oxv-admin-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// type_demande (pilote | pilote_pro | coach) -> user_role (pilot | admin | coach)
// NB : il n'existe pas de rôle "pilote_pro" dans l'enum user_role ; un pilote pro
// reste un 'pilot'. La distinction pro pourra être portée par un autre champ.
function mapRole(typeDemande: string): 'pilot' | 'coach' {
  return typeDemande === 'coach' ? 'coach' : 'pilot';
}

interface ResendResult {
  ok: boolean;
  resend_message_id: string | null;
  error: string | null;
}

async function sendViaResend(
  apiKey: string,
  to: string,
  subject: string,
  html: string,
  text: string,
  category: string,
): Promise<ResendResult> {
  try {
    const res = await fetch(RESEND_API_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: FROM,
        to: [to],
        subject,
        html,
        text,
        reply_to: 'contact@oxvehicle.fr',
        tags: [{ name: 'category', value: category }],
      }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      return {
        ok: false,
        resend_message_id: null,
        error: `resend_${res.status}: ${JSON.stringify(data).slice(0, 200)}`,
      };
    }
    return { ok: true, resend_message_id: data?.id ?? null, error: null };
  } catch (e) {
    return { ok: false, resend_message_id: null, error: String(e) };
  }
}

// Journalise l'envoi dans public.email_log (best-effort : ne bloque jamais le flux)
async function logEmail(
  admin: ReturnType<typeof createClient>,
  params: {
    userId: string | null;
    emailType: string;
    subject: string;
    template: string;
    result: ResendResult;
    to: string;
    demandeId: string;
  },
): Promise<string | null> {
  try {
    const { data, error } = await admin
      .from('email_log')
      .insert({
        user_id: params.userId,
        email_type: params.emailType,
        subject: params.subject,
        template_used: params.template,
        status: params.result.ok ? 'sent' : 'bounced',
        metadata: {
          to: params.to,
          demande_id: params.demandeId,
          resend_message_id: params.result.resend_message_id,
          error: params.result.error,
        },
      })
      .select('id')
      .single();
    if (error) {
      console.warn('[validate-inscription] email_log insert:', error.message);
      return null;
    }
    return (data as { id: string } | null)?.id ?? null;
  } catch (e) {
    console.warn('[validate-inscription] email_log threw:', String(e));
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  // --- 0) Auth serveur-à-serveur + état dormant ------------------------------
  const SECRET = Deno.env.get('VALIDATE_INSCRIPTION_SECRET');
  if (!SECRET) {
    return json(
      {
        error: 'function_disabled',
        detail:
          'VALIDATE_INSCRIPTION_SECRET non configuré — fonction dormante. ' +
          'Posez le secret pour l’armer.',
      },
      503,
    );
  }
  const provided = req.headers.get('x-oxv-admin-secret') ?? '';
  if (provided !== SECRET) return json({ error: 'unauthorized' }, 401);

  // --- 1) Environnement ------------------------------------------------------
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
  const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const RESEND_KEY = Deno.env.get('RESEND_API_KEY');
  const SITE_URL = Deno.env.get('SITE_URL') ?? 'https://www.oxvehicle.fr';

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // --- 2) Corps --------------------------------------------------------------
  let payload: {
    demande_id?: string;
    action?: string;
    admin_note?: string | null;
    reviewed_by?: string | null;
    dry_run?: boolean;
  };
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'bad_json' }, 400);
  }
  const {
    demande_id,
    action = 'accept',
    admin_note = null,
    reviewed_by = null,
    dry_run = false,
  } = payload;
  if (!demande_id) return json({ error: 'missing_demande_id' }, 400);
  if (!['accept', 'reject', 'acknowledge'].includes(action)) {
    return json({ error: 'invalid_action', detail: action }, 400);
  }
  const reviewerId = reviewed_by && UUID_RE.test(reviewed_by) ? reviewed_by : null;

  // --- 3) Charger la demande -------------------------------------------------
  const { data: demande, error: demErr } = await admin
    .from('demandes_inscription')
    .select('*')
    .eq('id', demande_id)
    .single();
  if (demErr || !demande) return json({ error: 'demande_not_found' }, 404);

  // accept/reject n'opèrent que sur 'en_attente' ; acknowledge tolère en_attente.
  if (action !== 'acknowledge' && demande.statut !== 'en_attente') {
    return json(
      { error: 'demande_already_processed', statut: demande.statut },
      409,
    );
  }

  const reference = `OXV-${String(demande.id).replace(/-/g, '').slice(0, 8).toUpperCase()}`;
  const firstName = demande.first_name ?? '';

  if (!RESEND_KEY) {
    // Sécurité : sans clé Resend, on n'effectue aucune mutation silencieuse.
    return json(
      { error: 'resend_not_configured', detail: 'RESEND_API_KEY manquante.' },
      500,
    );
  }

  // ===========================================================================
  // ACKNOWLEDGE — accusé de réception (statut inchangé)
  // ===========================================================================
  if (action === 'acknowledge') {
    const mail = renderAcknowledgement({ firstName, reference });
    if (dry_run) {
      return json({
        ok: true,
        dry_run: true,
        action,
        would_send: 'inscription_received',
        to: demande.email,
        subject: mail.subject,
      });
    }
    const result = await sendViaResend(
      RESEND_KEY,
      demande.email,
      mail.subject,
      mail.html,
      mail.text,
      'inscription_received',
    );
    const logId = await logEmail(admin, {
      userId: demande.created_user_id ?? null,
      emailType: 'inscription_received',
      subject: mail.subject,
      template: 'inscription_received_v1',
      result,
      to: demande.email,
      demandeId: demande_id,
    });
    return json({
      ok: true,
      action,
      email_sent: result.ok,
      email_error: result.error,
      email_log_id: logId,
    });
  }

  // ===========================================================================
  // REJECT — refus
  // ===========================================================================
  if (action === 'reject') {
    const mail = renderRejection({ firstName, reference, adminNote: admin_note });
    if (dry_run) {
      return json({
        ok: true,
        dry_run: true,
        action,
        would_set_statut: 'refusee',
        would_send: 'inscription_rejected',
        to: demande.email,
        subject: mail.subject,
      });
    }
    const { error: upErr } = await admin
      .from('demandes_inscription')
      .update({
        statut: 'refusee',
        admin_note,
        reviewed_by: reviewerId,
        reviewed_at: new Date().toISOString(),
      })
      .eq('id', demande_id);
    if (upErr) return json({ error: 'update_failed', detail: upErr.message }, 500);

    const result = await sendViaResend(
      RESEND_KEY,
      demande.email,
      mail.subject,
      mail.html,
      mail.text,
      'inscription_rejected',
    );
    const logId = await logEmail(admin, {
      userId: null,
      emailType: 'inscription_rejected',
      subject: mail.subject,
      template: 'inscription_rejected_v1',
      result,
      to: demande.email,
      demandeId: demande_id,
    });
    return json({
      ok: true,
      action,
      statut: 'refusee',
      email_sent: result.ok,
      email_error: result.error,
      email_log_id: logId,
    });
  }

  // ===========================================================================
  // ACCEPT — création du compte + lien + e-mail
  // ===========================================================================
  const role = mapRole(demande.type_demande);

  if (dry_run) {
    return json({
      ok: true,
      dry_run: true,
      action: 'accept',
      would_create_user: demande.email,
      role,
      would_set_statut: 'acceptee',
      would_send: 'inscription_approved',
    });
  }

  // 1) Compte Auth (email confirmé d'office ; il définira son mot de passe)
  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email: demande.email,
    email_confirm: true,
    user_metadata: {
      first_name: demande.first_name,
      last_name: demande.last_name,
      source: 'demande_inscription',
    },
  });

  let newUserId: string | null = created?.user?.id ?? null;

  // Compte déjà existant -> on le récupère plutôt que d'échouer
  if (createErr) {
    const already = /already registered|already been registered|exists/i.test(
      createErr.message,
    );
    if (!already) {
      return json(
        { error: 'create_user_failed', detail: createErr.message },
        500,
      );
    }
    const { data: list } = await admin.auth.admin.listUsers();
    const found = list?.users?.find(
      (u) => (u.email ?? '').toLowerCase() === demande.email.toLowerCase(),
    );
    newUserId = found?.id ?? null;
    if (!newUserId) return json({ error: 'existing_user_not_found' }, 500);
  }

  // 2) Profil public.users (id == auth uid). Upsert tolérant aux champs absents.
  const profileRow: Record<string, unknown> = {
    id: newUserId,
    email: demande.email,
    first_name: demande.first_name,
    last_name: demande.last_name,
    role,
    email_verified: true,
  };
  if (demande.phone) profileRow.phone = demande.phone;
  if (demande.birth_date) profileRow.birth_date = demande.birth_date;
  if (demande.city) profileRow.city = demande.city;

  const { error: upsertErr } = await admin
    .from('users')
    .upsert(profileRow, { onConflict: 'id' });
  if (upsertErr) {
    const { error: minErr } = await admin.from('users').upsert(
      {
        id: newUserId,
        email: demande.email,
        first_name: demande.first_name,
        last_name: demande.last_name,
        role,
      },
      { onConflict: 'id' },
    );
    if (minErr) {
      return json({ error: 'profile_upsert_failed', detail: minErr.message }, 500);
    }
  }

  // 3) Lien "définir mon mot de passe" (recovery)
  let actionLink: string | null = null;
  const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
    type: 'recovery',
    email: demande.email,
    options: { redirectTo: `${SITE_URL}/?p=reset-password` },
  });
  if (linkErr) {
    console.warn('[validate-inscription] generateLink:', linkErr.message);
  } else {
    actionLink =
      (linkData?.properties as { action_link?: string } | undefined)
        ?.action_link ?? null;
  }

  // 4) E-mail d'acceptation + journalisation
  const mail = renderApproval({ firstName, reference, actionLink });
  const result = await sendViaResend(
    RESEND_KEY,
    demande.email,
    mail.subject,
    mail.html,
    mail.text,
    'inscription_approved',
  );
  const logId = await logEmail(admin, {
    userId: newUserId,
    emailType: 'inscription_approved',
    subject: mail.subject,
    template: 'inscription_approved_v1',
    result,
    to: demande.email,
    demandeId: demande_id,
  });

  // 5) Demande -> acceptee
  const { error: finErr } = await admin
    .from('demandes_inscription')
    .update({
      statut: 'acceptee',
      admin_note,
      reviewed_by: reviewerId,
      reviewed_at: new Date().toISOString(),
      created_user_id: newUserId,
    })
    .eq('id', demande_id);
  if (finErr) {
    return json({ error: 'finalize_failed', detail: finErr.message }, 500);
  }

  return json({
    ok: true,
    action: 'accept',
    statut: 'acceptee',
    user_id: newUserId,
    role,
    email_sent: result.ok,
    email_error: result.error,
    email_log_id: logId,
    // Renvoyé pour fallback admin si l'e-mail échoue (appelant déjà authentifié par secret).
    action_link: actionLink,
  });
});
