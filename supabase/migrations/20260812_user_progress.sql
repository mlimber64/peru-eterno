-- ============================================================================
--  Perú Eterno — Progreso de usuario (Supabase / PostgreSQL)
-- ----------------------------------------------------------------------------
--  A diferencia de supabase/schema.sql (contenido editorial, lectura pública
--  para 'anon'), estas tablas guardan datos PRIVADOS por usuario: racha,
--  quiz, coleccionables y finales de Narrativa Interactiva. Hoy solo viven en
--  SharedPreferences (se pierden al cambiar de dispositivo); esta migración
--  es la base para sincronizarlos.
--
--  Usuario = sesión anónima de Supabase Auth (ver
--  lib/services/supabase_auth_service.dart) — sin registro ni contraseña.
--  RLS: cada fila solo es visible/editable por su propio dueño
--  (auth.uid() = user_id). No se permite DELETE desde el cliente.
--
--  Idempotente: se puede ejecutar varias veces sin error.
-- ============================================================================

-- gen_random_uuid() (Supabase la habilita por defecto; idempotente por si no).
create extension if not exists pgcrypto;

-- Reutiliza la función de supabase/schema.sql; si esta migración se corre
-- sola (proyecto nuevo), la crea igual.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================================
--  1. user_profiles
-- ============================================================================
create table if not exists public.user_profiles (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  created_at   timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

alter table public.user_profiles enable row level security;

drop policy if exists "own profile select" on public.user_profiles;
create policy "own profile select" on public.user_profiles
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "own profile insert" on public.user_profiles;
create policy "own profile insert" on public.user_profiles
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "own profile update" on public.user_profiles;
create policy "own profile update" on public.user_profiles
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================================
--  2. user_streaks
-- ============================================================================
create table if not exists public.user_streaks (
  user_id             uuid primary key references auth.users(id) on delete cascade,
  current_streak      int  not null default 0,
  max_streak          int  not null default 0,
  last_completed_date text,                     -- 'YYYY-MM-DD', igual que el local
  updated_at          timestamptz not null default now()
);

drop trigger if exists trg_user_streaks_updated on public.user_streaks;
create trigger trg_user_streaks_updated
  before update on public.user_streaks
  for each row execute function public.set_updated_at();

alter table public.user_streaks enable row level security;

drop policy if exists "own streak select" on public.user_streaks;
create policy "own streak select" on public.user_streaks
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "own streak insert" on public.user_streaks;
create policy "own streak insert" on public.user_streaks
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "own streak update" on public.user_streaks;
create policy "own streak update" on public.user_streaks
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================================
--  3. user_chapter_progress
--     Un registro por (usuario, capítulo de Historia). "Marcar como leído" +
--     resultado del quiz.
-- ============================================================================
create table if not exists public.user_chapter_progress (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  chapter_id  text not null,
  is_read     boolean not null default false,
  quiz_score  int,
  updated_at  timestamptz not null default now(),
  unique (user_id, chapter_id)
);

create index if not exists user_chapter_progress_user_idx on public.user_chapter_progress (user_id);

drop trigger if exists trg_user_chapter_progress_updated on public.user_chapter_progress;
create trigger trg_user_chapter_progress_updated
  before update on public.user_chapter_progress
  for each row execute function public.set_updated_at();

alter table public.user_chapter_progress enable row level security;

drop policy if exists "own chapter progress select" on public.user_chapter_progress;
create policy "own chapter progress select" on public.user_chapter_progress
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "own chapter progress insert" on public.user_chapter_progress;
create policy "own chapter progress insert" on public.user_chapter_progress
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "own chapter progress update" on public.user_chapter_progress;
create policy "own chapter progress update" on public.user_chapter_progress
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================================
--  4. user_collectibles
--     Desbloqueo es un evento único (no se "actualiza"): sin trigger de
--     updated_at, solo unlocked_at fijado al insertar.
-- ============================================================================
create table if not exists public.user_collectibles (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  collectible_id text not null,
  unlocked_at    timestamptz not null default now(),
  unique (user_id, collectible_id)
);

create index if not exists user_collectibles_user_idx on public.user_collectibles (user_id);

alter table public.user_collectibles enable row level security;

drop policy if exists "own collectibles select" on public.user_collectibles;
create policy "own collectibles select" on public.user_collectibles
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "own collectibles insert" on public.user_collectibles;
create policy "own collectibles insert" on public.user_collectibles
  for insert to authenticated with check (auth.uid() = user_id);

-- ============================================================================
--  5. user_story_endings
--     Finales desbloqueados de Narrativa Interactiva. También evento único.
-- ============================================================================
create table if not exists public.user_story_endings (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  story_id        text not null,
  ending_node_id  text not null,
  unlocked_at     timestamptz not null default now(),
  unique (user_id, story_id, ending_node_id)
);

create index if not exists user_story_endings_user_idx on public.user_story_endings (user_id);

alter table public.user_story_endings enable row level security;

drop policy if exists "own story endings select" on public.user_story_endings;
create policy "own story endings select" on public.user_story_endings
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "own story endings insert" on public.user_story_endings;
create policy "own story endings insert" on public.user_story_endings
  for insert to authenticated with check (auth.uid() = user_id);

-- ============================================================================
--  Fin de la migración.
-- ============================================================================
