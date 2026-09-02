-- ============================================================================
--  Perú Eterno — Analítica mínima propia
-- ----------------------------------------------------------------------------
--  Sin esto se lanza a ciegas: no hay forma de saber cuánta gente termina el
--  onboarding, cuántos vuelven al día siguiente, qué capítulos se leen ni en
--  qué punto se abandona. Con 20 capítulos y una racha diaria como gancho,
--  esas cuatro respuestas deciden qué se construye después.
--
--  Va en el propio Supabase, no en Firebase/Amplitude/PostHog, por la misma
--  razón que los informes de error (ver 20260901_error_reports.sql): la
--  política de privacidad promete que no hay SDK de terceros ni procesadores
--  externos, y añadir uno obligaría a reescribirla y a declararlo en el
--  formulario de Data Safety de Play.
--
--  QUÉ NO ENTRA AQUÍ, y lo garantiza la BASE, no el cliente:
--  `name` y `target` solo aceptan identificadores en minúsculas
--  (`^[a-z][a-z0-9_]*$`). Nada de texto libre, ni búsquedas escritas, ni
--  correos, ni títulos. Si algún día alguien intenta mandar aquí lo que el
--  usuario tecleó, el INSERT falla en vez de guardarlo en silencio.
--
--  Idempotente: se puede ejecutar varias veces sin error.
-- ============================================================================

create extension if not exists pgcrypto;

create table if not exists public.app_events (
  id          uuid primary key default gen_random_uuid(),

  -- Nullable a propósito: los primeros eventos del arranque ocurren antes de
  -- que termine el sign-in anónimo. `on delete set null` desliga el evento
  -- cuando el usuario borra su cuenta, igual que en los informes de error:
  -- la fila queda para el agregado pero ya no apunta a nadie.
  user_id     uuid references auth.users(id) on delete set null,

  created_at  timestamptz not null default now(),

  -- Sesión de app (se genera nueva en cada arranque). Permite medir embudos
  -- —cuántos abren el paywall en la misma sesión en que terminan el
  -- onboarding— sin necesidad de identificar a nadie.
  session_id  uuid not null,

  -- Qué pasó. Del catálogo de AnalyticsService; el check solo impone la
  -- FORMA, no la lista, para no tener que migrar la base cada vez que se
  -- añade un evento.
  name        text not null,

  -- Sobre qué: id de capítulo, de categoría, de historia, o el origen desde
  -- el que se abrió el paywall. Identificadores de contenido, nunca datos
  -- de la persona.
  target      text,

  -- Número asociado (puntaje del quiz, segundos de lectura, día de racha).
  value       int,

  app_version text,
  platform    text,
  locale      text,
  is_premium  boolean,

  constraint app_events_name_shape
    check (name ~ '^[a-z][a-z0-9_]{2,39}$'),
  constraint app_events_target_shape
    check (target is null or target ~ '^[a-z0-9][a-z0-9_-]{0,99}$')
);

-- Los tres cortes por los que se consulta esto: por fecha (cuántos hoy), por
-- evento (embudo) y por usuario (retención).
create index if not exists app_events_created_idx
  on public.app_events (created_at desc);
create index if not exists app_events_name_created_idx
  on public.app_events (name, created_at desc);
create index if not exists app_events_user_created_idx
  on public.app_events (user_id, created_at desc);

alter table public.app_events enable row level security;

-- INSERT sí, SELECT no —igual que los informes de error—. La app escribe;
-- leer es cosa del dashboard, que salta RLS con service_role. Ni el propio
-- usuario puede releer sus eventos, así que la anon key pública no sirve
-- para espiar a nadie.
--
-- Se permite a `anon` porque los eventos de arranque (app_open, el
-- onboarding) ocurren antes del sign-in anónimo, y perder justo esos sería
-- perder el principio del embudo, que es el tramo que más importa. El riesgo
-- de que alguien inserte basura con la anon key existe, está acotado por los
-- dos `check` de forma, y se corta quitando `anon` de esta policy.
drop policy if exists "log own event" on public.app_events;
create policy "log own event" on public.app_events
  for insert to anon, authenticated
  with check (user_id is null or auth.uid() = user_id);

-- ============================================================================
--  Vistas de lectura
-- ----------------------------------------------------------------------------
--  `security_invoker = on` a propósito: sin esto la vista correría con los
--  permisos de su dueño y SALTARÍA el RLS de arriba, así que cualquiera con
--  la anon key podría leer por la vista lo que la tabla le niega. Con
--  security_invoker, un cliente ve cero filas y el dashboard (service_role)
--  las ve todas — que es justo lo que se quiere.
-- ============================================================================

-- Cuánta gente distinta abre la app cada día, y cuántos eventos genera.
create or replace view public.analytics_daily
with (security_invoker = on) as
select
  (created_at at time zone 'UTC')::date as dia,
  count(distinct user_id)               as usuarios,
  count(*)                              as eventos
from public.app_events
group by 1
order by 1 desc;

-- El embudo: cuántas veces pasó cada cosa cada día y cuántas personas
-- distintas la hicieron. De aquí sale "cuántos terminan el onboarding",
-- "cuántos abren el paywall" y "cuántos leen la historia del día".
create or replace view public.analytics_events_daily
with (security_invoker = on) as
select
  (created_at at time zone 'UTC')::date as dia,
  name                                  as evento,
  count(*)                              as veces,
  count(distinct user_id)               as usuarios
from public.app_events
group by 1, 2
order by 1 desc, 3 desc;

-- Qué contenido se consume de verdad, para decidir qué escribir después.
create or replace view public.analytics_contenido
with (security_invoker = on) as
select
  name                                  as evento,
  target                                as contenido,
  count(*)                              as veces,
  count(distinct user_id)               as usuarios
from public.app_events
where target is not null
group by 1, 2
order by 3 desc;

-- ============================================================================
--  Retención (12 meses)
-- ----------------------------------------------------------------------------
--  La analítica pierde valor con el tiempo y la política de privacidad no
--  puede prometer "para siempre". Ejecutar a mano de vez en cuando, o desde
--  un cron de Supabase si algún día se activa pg_cron.
-- ============================================================================

create or replace function public.purge_old_app_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  borrados integer;
begin
  delete from public.app_events
  where created_at < now() - interval '12 months';
  get diagnostics borrados = row_count;
  return borrados;
end;
$$;

revoke all on function public.purge_old_app_events() from public, anon, authenticated;

-- ============================================================================
--  Fin de la migración.
-- ============================================================================
