-- ============================================================================
--  Perú Eterno — Borrado de datos por el propio usuario
-- ----------------------------------------------------------------------------
--  Complementa 20260812_user_progress.sql, que deliberadamente NO incluía
--  policies de DELETE. Esa decisión bloquea un requisito de tienda: tanto
--  Google Play ("Eliminación de datos y de la cuenta") como App Store exigen
--  que el usuario pueda borrar desde dentro de la app los datos que la app
--  guarda sobre él. Sin estas policies, la opción "Borrar mis datos" de
--  Ajustes no puede tocar el servidor.
--
--  Alcance: cada usuario solo puede borrar SUS filas (auth.uid() = user_id).
--  Sigue sin existir ninguna vía para borrar filas ajenas.
--
--  El borrado del propio usuario de `auth.users` no se puede hacer desde el
--  cliente (necesita service_role): lo hace la Edge Function
--  supabase/functions/delete-account. Si esa función no está desplegada, la
--  app cae al borrado de filas que habilita esta migración — los datos
--  desaparecen igual, y solo queda la fila anónima de auth.users sin nada
--  asociado.
--
--  Idempotente: se puede ejecutar varias veces sin error.
-- ============================================================================

-- 1. user_profiles
drop policy if exists "own profile delete" on public.user_profiles;
create policy "own profile delete" on public.user_profiles
  for delete to authenticated using (auth.uid() = user_id);

-- 2. user_streaks
drop policy if exists "own streak delete" on public.user_streaks;
create policy "own streak delete" on public.user_streaks
  for delete to authenticated using (auth.uid() = user_id);

-- 3. user_chapter_progress
drop policy if exists "own chapter progress delete" on public.user_chapter_progress;
create policy "own chapter progress delete" on public.user_chapter_progress
  for delete to authenticated using (auth.uid() = user_id);

-- 4. user_collectibles
drop policy if exists "own collectibles delete" on public.user_collectibles;
create policy "own collectibles delete" on public.user_collectibles
  for delete to authenticated using (auth.uid() = user_id);

-- 5. user_story_endings
drop policy if exists "own story endings delete" on public.user_story_endings;
create policy "own story endings delete" on public.user_story_endings
  for delete to authenticated using (auth.uid() = user_id);

-- ============================================================================
--  Retención: cuentas anónimas inactivas
-- ----------------------------------------------------------------------------
--  La política de privacidad promete borrar las cuentas anónimas sin
--  actividad durante 24 meses. Esta función hace ese barrido sobre los datos
--  de progreso; queda lista para engancharla a un cron (Supabase → Database →
--  Cron, o pg_cron: select cron.schedule('purge-inactive', '0 3 * * 0',
--  'select public.purge_inactive_anonymous_data()')).
--
--  La inactividad se calcula desde las propias filas de progreso, NO desde
--  user_profiles: esa tabla existe pero la app nunca escribe en ella (ver
--  lib/services/user_progress_sync_service.dart), así que usarla como
--  referencia habría marcado a todos los usuarios como inactivos.
--
--  No borra filas de auth.users (requiere privilegios de admin): para eso,
--  la Edge Function delete-account o un job con service_role.
-- ============================================================================
create or replace function public.purge_inactive_anonymous_data()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  cutoff timestamptz := now() - interval '24 months';
  stale  uuid[];
begin
  select coalesce(array_agg(user_id), '{}'::uuid[])
    into stale
    from (
      select user_id, max(activity) as last_activity
        from (
          select user_id, updated_at  as activity from public.user_streaks
          union all
          select user_id, updated_at  as activity from public.user_chapter_progress
          union all
          select user_id, unlocked_at as activity from public.user_collectibles
          union all
          select user_id, unlocked_at as activity from public.user_story_endings
        ) as activity_log
       group by user_id
    ) as last_seen
   where last_activity < cutoff;

  delete from public.user_streaks          where user_id = any(stale);
  delete from public.user_chapter_progress where user_id = any(stale);
  delete from public.user_collectibles     where user_id = any(stale);
  delete from public.user_story_endings    where user_id = any(stale);
  delete from public.user_profiles         where user_id = any(stale);

  return coalesce(array_length(stale, 1), 0);
end;
$$;

revoke all on function public.purge_inactive_anonymous_data() from public, anon, authenticated;
