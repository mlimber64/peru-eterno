// ============================================================================
//  delete-account — borrado completo de la cuenta anónima y sus datos
// ----------------------------------------------------------------------------
//  La app puede borrar sus propias filas desde el cliente (ver las policies
//  de DELETE en supabase/migrations/20260901_data_deletion.sql), pero NO
//  puede borrar su usuario de `auth.users`: eso requiere la service_role key,
//  que nunca debe viajar dentro de un binario publicado.
//
//  Esta función cierra ese hueco: valida el JWT del usuario que llama, borra
//  sus filas y finalmente elimina su usuario de auth. Es lo que hace que
//  "Borrar mis datos" sea un borrado de cuenta real y no solo un vaciado.
//
//  Despliegue:
//    supabase functions deploy delete-account
//
//  No hace falta configurar secretos: SUPABASE_URL y
//  SUPABASE_SERVICE_ROLE_KEY los inyecta la plataforma automáticamente.
//
//  Si esta función no está desplegada, la app sigue funcionando: cae al
//  borrado de filas vía RLS (ver AccountDataService._deleteRemote).
// ============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

/// Tablas con datos del usuario. Debe coincidir con
/// AccountDataService.userTables en el cliente.
const USER_TABLES = [
  'user_chapter_progress',
  'user_collectibles',
  'user_story_endings',
  'user_streaks',
  'user_profiles',
];

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

  // 1. Identificar a quien llama a partir de SU token — nunca de un id
  //    recibido en el cuerpo de la petición, que sería suplantable.
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json({ error: 'missing_authorization' }, 401);
  }

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await callerClient.auth.getUser();
  const user = userData?.user;
  if (userError || !user) {
    return json({ error: 'invalid_token' }, 401);
  }

  // 2. Borrar sus datos con service_role (salta RLS, pero siempre filtrando
  //    por el id que acabamos de verificar).
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  for (const table of USER_TABLES) {
    const { error } = await adminClient.from(table).delete().eq('user_id', user.id);
    if (error) {
      return json({ error: 'delete_failed', table, detail: error.message }, 500);
    }
  }

  // 3. Borrar el usuario de auth. A partir de aquí el id deja de existir y
  //    la app abre una sesión anónima nueva por su cuenta.
  const { error: deleteUserError } = await adminClient.auth.admin.deleteUser(
    user.id,
  );
  if (deleteUserError) {
    return json(
      { error: 'auth_delete_failed', detail: deleteUserError.message },
      500,
    );
  }

  return json({ deleted: true }, 200);
});
