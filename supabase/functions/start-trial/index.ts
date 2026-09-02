// ============================================================================
//  start-trial — activa la prueba gratuita de 7 días, una sola vez por cuenta
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

const TRIAL_DAYS = 7;

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

  const expiresAt = new Date(Date.now() + TRIAL_DAYS * 24 * 60 * 60 * 1000);

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
