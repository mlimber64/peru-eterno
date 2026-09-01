-- ============================================================================
--  Perú Eterno — Informes de error (crash reporting propio)
-- ----------------------------------------------------------------------------
--  Sin esto, el día del lanzamiento no hay forma de enterarse de un fallo en
--  producción: los errores de Dart no matan el proceso, así que Android Vitals
--  de Play Console (que sí ve crashes nativos y ANRs, gratis y sin SDK) no los
--  registra. Quedan invisibles salvo que un usuario se moleste en escribir.
--
--  Se guarda en el propio Supabase en vez de usar Sentry o Crashlytics: así no
--  entra ningún procesador externo ni SDK de terceros, que es justo lo que la
--  política de privacidad promete que no hay.
--
--  QUÉ NO SE GUARDA AQUÍ, a propósito: nada que el usuario haya escrito, ni su
--  correo, ni el contenido que estaba leyendo. Solo el tipo de error, su traza
--  y datos técnicos del dispositivo.
--
--  Idempotente: se puede ejecutar varias veces sin error.
-- ============================================================================

create table if not exists public.app_error_reports (
  id           uuid primary key default gen_random_uuid(),

  -- Nullable a propósito: un error puede ocurrir antes de que termine el
  -- inicio de sesión anónimo. `on delete set null` conserva el informe
  -- aunque el usuario borre su cuenta — ya no apunta a nadie.
  user_id      uuid references auth.users(id) on delete set null,

  created_at   timestamptz not null default now(),

  app_version  text,
  platform     text,
  os_version   text,
  locale       text,

  error_type   text,
  message      text,
  stack_trace  text,

  -- Dónde ocurrió (biblioteca de Flutter, pantalla…), si se sabe.
  context      text,

  -- `true` = error no capturado que llegó a PlatformDispatcher; `false` =
  -- error de framework que Flutter reportó pero del que la app sobrevivió.
  is_fatal     boolean not null default false,

  -- Cotas de tamaño: sin esto, un bucle de error con trazas enormes puede
  -- llenar la base. La app además trunca antes de enviar.
  constraint app_error_reports_message_len check (char_length(message) <= 2000),
  constraint app_error_reports_stack_len check (char_length(stack_trace) <= 8000)
);

create index if not exists app_error_reports_created_idx
  on public.app_error_reports (created_at desc);

alter table public.app_error_reports enable row level security;

-- INSERT sí, SELECT no. Un usuario puede reportar su propio fallo pero no
-- puede leer los informes de nadie —ni los suyos—: esta tabla se consulta
-- desde el dashboard de Supabase, que salta RLS con service_role.
--
-- Se permite también a `anon` porque un error puede saltar antes de que
-- termine el sign-in anónimo, y perder justo los fallos de arranque sería
-- perder los más importantes. Con la anon key pública cualquiera podría
-- insertar basura aquí; el riesgo es bajo y acotado por los `check` de
-- longitud. Si alguna vez aparece abuso, basta con quitar `anon` de la
-- policy: se perderían solo los errores previos a la sesión.
drop policy if exists "report own error" on public.app_error_reports;
create policy "report own error" on public.app_error_reports
  for insert to anon, authenticated
  with check (user_id is null or auth.uid() = user_id);

-- ============================================================================
--  Limpieza: los informes caducan a los 90 días
-- ----------------------------------------------------------------------------
--  Un error de hace tres meses ya no dice nada útil, y la política de
--  privacidad no promete guardar diagnósticos indefinidamente. Engánchala a
--  un cron si se quiere automática:
--    select cron.schedule('purge-errors','0 4 * * *',
--                         'select public.purge_old_error_reports()');
-- ============================================================================
create or replace function public.purge_old_error_reports()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  purged integer;
begin
  with deleted as (
    delete from public.app_error_reports
     where created_at < now() - interval '90 days'
    returning id
  )
  select count(*) into purged from deleted;
  return purged;
end;
$$;

revoke all on function public.purge_old_error_reports() from public, anon, authenticated;
