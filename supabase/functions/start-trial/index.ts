// ============================================================================
//  start-trial — activa la prueba gratuita (3 días en el plan semanal, 7 en el
//  anual), una sola vez por cuenta
// ----------------------------------------------------------------------------
//  La prueba vivía en `SharedPreferences` (`premium_has_used_trial`), así que
//  desinstalar y reinstalar la app la volvía a activar: prueba infinita, gratis.
//
//  Aquí el "ya la usaste" vive en `user_entitlements.trial_used`, que el
//  cliente puede leer pero no escribir. Sobrevive a reinstalar la app **si el
//  usuario vinculó su cuenta a un correo**; con una sesión anónima nueva se
//  vuelve a tener derecho a prueba.
//
//  El cierre definitivo de ese hueco no es código: es configurar la prueba
//  como oferta gratuita del plan en Play Console. Google la asocia entonces a
//  la cuenta de Google, que sí sobrevive a cualquier reinstalación o cambio de
//  teléfono. Ver RELEASE.md.
//
//  Despliegue:
//    supabase functions deploy start-trial
// ============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

// Días de prueba por plan. Misma tabla que `PremiumProvider.trialDaysFor` en la
// app: si se cambia aquí, cambiarla allí. La duración la decide el servidor; el
// cliente solo dice qué plan tiene elegido, nunca cuántos días quiere.
const TRIAL_DAYS: Record<string, number> = { weekly: 3, annual: 7 };
const DEFAULT_TRIAL_PLAN = 'weekly';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!supabaseUrl || !serviceRoleKey || !anonKey) {
    return json({ error: 'missing_environment' }, 500);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'missing_authorization' }, 401);

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  const user = userData?.user;
  if (userError || !user) return json({ error: 'invalid_token' }, 401);

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: existing, error: readError } = await admin
    .from('user_entitlements')
    .select('trial_used, plan, expires_at')
    .eq('user_id', user.id)
    .maybeSingle();

  if (readError) {
    return json({ error: 'read_failed', detail: readError.message }, 500);
  }

  if (existing?.trial_used === true) {
    return json({ error: 'trial_already_used' }, 409);
  }

  // No se pisa una suscripción de pago vigente con una prueba.
  if (existing?.expires_at && new Date(existing.expires_at) > new Date() &&
      existing.plan !== 'trial' && existing.plan !== 'none') {
    return json({ error: 'already_subscribed' }, 409);
  }

  let requestedPlan = DEFAULT_TRIAL_PLAN;
  try {
    const body = await req.json();
    if (typeof body?.plan === 'string' && body.plan in TRIAL_DAYS) {
      requestedPlan = body.plan;
    }
  } catch (_) {
    // Sin cuerpo o no es JSON: se usa el plan por defecto.
  }
  const trialDays = TRIAL_DAYS[requestedPlan];

  const expiresAt = new Date(Date.now() + trialDays * 24 * 60 * 60 * 1000);

  const { error: upsertError } = await admin.from('user_entitlements').upsert(
    {
      user_id: user.id,
      plan: 'trial',
      expires_at: expiresAt.toISOString(),
      trial_used: true,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  );

  if (upsertError) {
    return json({ error: 'grant_failed', detail: upsertError.message }, 500);
  }

  return json(
    {
      plan: 'trial',
      expires_at: expiresAt.toISOString(),
      trial_used: true,
      is_active: true,
    },
    200,
  );
});
