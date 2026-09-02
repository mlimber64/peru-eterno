// ============================================================================
//  verify-purchase — valida una suscripción contra Google Play y concede el
//  acceso premium en `user_entitlements`
// ----------------------------------------------------------------------------
//  Es el único sitio con permiso para escribir el acceso premium (la tabla no
//  tiene policies de INSERT/UPDATE para el cliente). Recibe el token de compra
//  que devuelve Play, pregunta a Google si esa suscripción existe y sigue
//  activa, y solo entonces escribe la fecha de expiración que Google reporta
//  — no una calculada con el reloj del teléfono.
//
//  Despliegue:
//    supabase secrets set GOOGLE_PLAY_PACKAGE_NAME=com.perueternno.peru_eterno
//    supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT="$(cat service-account.json)"
//    supabase functions deploy verify-purchase
//
//  El service account se crea en Google Cloud, se le da acceso en Play
//  Console (Usuarios y permisos → permiso "Ver datos financieros" y "Gestionar
//  pedidos y suscripciones") y se vincula el proyecto de Cloud con Play
//  Console. Ver RELEASE.md.
//
//  Sin esos secretos configurados la función responde 501 y la app sigue
//  funcionando con su comportamiento anterior (acceso local): así se puede
//  desplegar antes de tener la cuenta de Play lista.
// ============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

/// Debe coincidir con PremiumProvider.weeklyProductId / annualProductId.
const PLAN_BY_PRODUCT: Record<string, string> = {
  peru_eterno_premium_weekly: 'weekly',
  peru_eterno_premium_annual: 'annual',
};

/// Estados de Google que consideramos acceso vigente. `IN_GRACE_PERIOD` es un
/// pago fallido que Google sigue reintentando: cortar el acceso ahí castiga a
/// un usuario que probablemente solo tiene la tarjeta caducada.
const ACTIVE_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
  'SUBSCRIPTION_STATE_CANCELED', // Cancelada pero aún no vencida: sigue teniendo acceso hasta expiryTime.
]);

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

/// Token de acceso de Google a partir del service account (JWT RS256 firmado
/// con Web Crypto, sin dependencias externas).
async function googleAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const b64url = (data: string) =>
    btoa(data).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

  const unsigned = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claims))}`;

  // La clave viene en PEM PKCS#8 con "\n" escapados dentro del JSON.
  const pem = serviceAccount.private_key
    .replace(/\\n/g, '\n')
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );

  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${signatureB64}`,
    }),
  });

  if (!response.ok) {
    throw new Error(`token de Google: ${response.status} ${await response.text()}`);
  }
  const data = await response.json();
  return data.access_token as string;
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

  const packageName = Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME');
  const rawServiceAccount = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT');
  if (!packageName || !rawServiceAccount) {
    // Todavía no hay credenciales de Play: la app lo interpreta como "sigue
    // con tu comportamiento local" en vez de como un error.
    return json({ error: 'play_not_configured' }, 501);
  }

  // 1. Identificar a quien llama por SU token, nunca por un id del cuerpo.
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'missing_authorization' }, 401);

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  const user = userData?.user;
  if (userError || !user) return json({ error: 'invalid_token' }, 401);

  // 2. Datos de la compra.
  let body: { productId?: string; purchaseToken?: string; platform?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }

  const productId = body.productId ?? '';
  const purchaseToken = body.purchaseToken ?? '';
  const plan = PLAN_BY_PRODUCT[productId];
  if (!plan || !purchaseToken) {
    return json({ error: 'unknown_product' }, 400);
  }
  if ((body.platform ?? 'android') !== 'android') {
    // iOS usa StoreKit y otra API de validación; cuando toque, va aquí.
    return json({ error: 'platform_not_supported' }, 501);
  }

  // 3. Preguntar a Google si la suscripción existe y sigue viva.
  let expiryTime: string | null = null;
  let subscriptionState = '';
  try {
    const serviceAccount = JSON.parse(rawServiceAccount);
    const accessToken = await googleAccessToken(serviceAccount);

    const playResponse = await fetch(
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptionsv2/tokens/${purchaseToken}`,
      { headers: { Authorization: `Bearer ${accessToken}` } },
    );

    if (playResponse.status === 404 || playResponse.status === 410) {
      return json({ error: 'purchase_not_found' }, 404);
    }
    if (!playResponse.ok) {
      return json(
        { error: 'play_api_error', detail: await playResponse.text() },
        502,
      );
    }

    const purchase = await playResponse.json();
    subscriptionState = purchase.subscriptionState ?? '';
    const lineItems = purchase.lineItems ?? [];
    // La expiración más lejana entre las líneas de la suscripción.
    for (const item of lineItems) {
      if (item.expiryTime && (!expiryTime || item.expiryTime > expiryTime)) {
        expiryTime = item.expiryTime;
      }
    }
  } catch (error) {
    return json({ error: 'verification_failed', detail: String(error) }, 502);
  }

  if (!ACTIVE_STATES.has(subscriptionState) || !expiryTime) {
    return json({ error: 'not_active', state: subscriptionState }, 403);
  }

  // 4. Conceder. Se guarda la expiración que dice GOOGLE, no una calculada.
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { error: upsertError } = await admin.from('user_entitlements').upsert(
    {
      user_id: user.id,
      plan,
      expires_at: expiryTime,
      platform: 'android',
      product_id: productId,
      purchase_token: purchaseToken,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  );

  if (upsertError) {
    // El índice único de purchase_token salta si ese recibo ya concedió
    // acceso a otra cuenta: es un intento de compartir la compra.
    const shared = upsertError.code === '23505';
    return json(
      { error: shared ? 'token_already_used' : 'grant_failed', detail: upsertError.message },
      shared ? 409 : 500,
    );
  }

  return json(
    { plan, expires_at: expiryTime, is_active: true, state: subscriptionState },
    200,
  );
});
