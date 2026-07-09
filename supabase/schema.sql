-- ============================================================================
--  Perú Eterno — Esquema de contenido para Supabase (PostgreSQL)
-- ----------------------------------------------------------------------------
--  Estrategia: campos traducibles en JSONB  {"es":"…","it":"…","en":"…"}
--  (coincide 1:1 con los modelos Dart que ya usan Map<String,String>).
--  Campos no textuales (orden, colores, coordenadas, flags) como columnas
--  escalares normales.
--
--  Idempotente: se puede ejecutar varias veces sin error.
--  Orden de carga (seed) recomendado por las claves foráneas:
--    1) content_items  2) historia_stages  3) historia_articles
--    4) timeline_items 5) map_points
-- ============================================================================

-- ── Función + trigger genérico para mantener updated_at (sync incremental) ──
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
--  1. content_items
--     Contenido editorial: personajes, gastronomía, música, geografía,
--     tradiciones y eras. Unifica EditorialRepository + ContentRepository.
-- ============================================================================
create table if not exists public.content_items (
  id             text primary key,                 -- 'ceviche', 'cesar_vallejo'
  category       text not null,                    -- 'gastronomia','personaje',…
  orden          int  not null default 0,
  is_premium     boolean not null default false,
  titulo         jsonb not null default '{}'::jsonb,
  subtitulo      jsonb not null default '{}'::jsonb,
  contenido      jsonb not null default '{}'::jsonb,
  fuente         jsonb,                             -- atribución/licencia por idioma
  imagen_local   text,                              -- 'ceviche.webp'
  wikipedia_slug jsonb,                             -- {"es":"Ceviche","en":"Ceviche"}
  updated_at     timestamptz not null default now()
);

create index if not exists content_items_category_idx   on public.content_items (category);
create index if not exists content_items_orden_idx       on public.content_items (orden);
create index if not exists content_items_updated_at_idx  on public.content_items (updated_at);

drop trigger if exists trg_content_items_updated on public.content_items;
create trigger trg_content_items_updated
  before update on public.content_items
  for each row execute function public.set_updated_at();

-- ============================================================================
--  2. historia_stages
--     Etapas históricas (Perú prehispánico, Conquista, Virreinato, …).
-- ============================================================================
create table if not exists public.historia_stages (
  id           text primary key,                   -- 'peru_prehispanico'
  orden        int  not null default 0,
  accent_color text,                                -- hex ARGB: 'FFC1440E'
  periodo      jsonb not null default '{}'::jsonb,
  titulo       jsonb not null default '{}'::jsonb,
  subtitulo    jsonb not null default '{}'::jsonb,
  updated_at   timestamptz not null default now()
);

create index if not exists historia_stages_orden_idx      on public.historia_stages (orden);
create index if not exists historia_stages_updated_at_idx on public.historia_stages (updated_at);

drop trigger if exists trg_historia_stages_updated on public.historia_stages;
create trigger trg_historia_stages_updated
  before update on public.historia_stages
  for each row execute function public.set_updated_at();

-- ============================================================================
--  3. historia_articles
--     Artículos de cada etapa. 'categoria' y 'periodo' también multiidioma.
-- ============================================================================
create table if not exists public.historia_articles (
  id               text primary key,
  parent_stage_id  text references public.historia_stages(id) on delete cascade,
  orden            int  not null default 0,
  categoria        jsonb not null default '{}'::jsonb,
  titulo           jsonb not null default '{}'::jsonb,
  subtitulo        jsonb not null default '{}'::jsonb,
  contenido        jsonb not null default '{}'::jsonb,
  periodo          jsonb,
  imagen_sugerida  text,                            -- 'caral_panoramica.webp'
  updated_at       timestamptz not null default now()
);

create index if not exists historia_articles_stage_idx      on public.historia_articles (parent_stage_id);
create index if not exists historia_articles_orden_idx       on public.historia_articles (orden);
create index if not exists historia_articles_updated_at_idx  on public.historia_articles (updated_at);

drop trigger if exists trg_historia_articles_updated on public.historia_articles;
create trigger trg_historia_articles_updated
  before update on public.historia_articles
  for each row execute function public.set_updated_at();

-- ============================================================================
--  4. timeline_items
--     Línea de tiempo cronológica del Home.
-- ============================================================================
create table if not exists public.timeline_items (
  id          text primary key,
  orden       int  not null default 0,
  color       text,                                 -- hex ARGB: 'FFC8860A'
  titulo      jsonb not null default '{}'::jsonb,
  periodo     jsonb not null default '{}'::jsonb,
  image       text,
  stage_id    text references public.historia_stages(id) on delete set null,
  updated_at  timestamptz not null default now()
);

create index if not exists timeline_items_orden_idx      on public.timeline_items (orden);
create index if not exists timeline_items_updated_at_idx on public.timeline_items (updated_at);

drop trigger if exists trg_timeline_items_updated on public.timeline_items;
create trigger trg_timeline_items_updated
  before update on public.timeline_items
  for each row execute function public.set_updated_at();

-- ============================================================================
--  5. map_points
--     Pines del mapa cultural. Offset(dx,dy) → pos_x / pos_y (0..1).
-- ============================================================================
create table if not exists public.map_points (
  id                  text primary key,
  orden               int  not null default 0,
  name                jsonb not null default '{}'::jsonb,
  region              jsonb not null default '{}'::jsonb,
  period              jsonb not null default '{}'::jsonb,
  image_asset         text,
  pos_x               double precision not null default 0,  -- Offset.dx
  pos_y               double precision not null default 0,  -- Offset.dy
  accent_color        text,                                 -- hex ARGB
  historia_article_id text references public.historia_articles(id) on delete set null,
  content_item_id     text references public.content_items(id)     on delete set null,
  updated_at          timestamptz not null default now()
);

create index if not exists map_points_orden_idx      on public.map_points (orden);
create index if not exists map_points_updated_at_idx on public.map_points (updated_at);

drop trigger if exists trg_map_points_updated on public.map_points;
create trigger trg_map_points_updated
  before update on public.map_points
  for each row execute function public.set_updated_at();

-- ============================================================================
--  Row Level Security — lectura pública anónima, sin escritura desde la app.
--  (El contenido se administra desde el panel de Supabase / service_role.)
-- ============================================================================
alter table public.content_items     enable row level security;
alter table public.historia_stages   enable row level security;
alter table public.historia_articles enable row level security;
alter table public.timeline_items    enable row level security;
alter table public.map_points        enable row level security;

drop policy if exists "public read" on public.content_items;
create policy "public read" on public.content_items
  for select to anon, authenticated using (true);

drop policy if exists "public read" on public.historia_stages;
create policy "public read" on public.historia_stages
  for select to anon, authenticated using (true);

drop policy if exists "public read" on public.historia_articles;
create policy "public read" on public.historia_articles
  for select to anon, authenticated using (true);

drop policy if exists "public read" on public.timeline_items;
create policy "public read" on public.timeline_items
  for select to anon, authenticated using (true);

drop policy if exists "public read" on public.map_points;
create policy "public read" on public.map_points
  for select to anon, authenticated using (true);

-- ============================================================================
--  Fin del esquema.
-- ============================================================================
