-- ============================================================================
--  Perú Eterno — Acceso premium verificado en servidor
-- ----------------------------------------------------------------------------
--  Hoy el acceso premium vive solo en SharedPreferences: `_verifyPurchase`
--  acepta cualquier transacción y la fecha de expiración se calcula con
--  `DateTime.now()` del dispositivo. Consecuencias reales:
--
--    · Atrasar el reloj del teléfono alarga la suscripción.
--    · Cancelar la suscripción en la tienda no revoca el acceso hasta que
--      vence la fecha calculada localmente.
--    · Reinstalar la app borra `premium_has_used_trial`, así que la prueba
--      gratuita de 7 días se puede repetir infinitas veces.
--
--  Esta tabla mueve la verdad al servidor. La regla que lo hace funcionar:
--  **el cliente NO puede escribir aquí**. Solo hay policy de SELECT; los
--  INSERT/UPDATE los hace la Edge Function `verify-purchase` con
--  service_role, después de validar el recibo contra Google Play. Si el
--  cliente pudiera escribir, esto sería tan falsificable como el fichero de
--  preferencias que viene a reemplazar.
--
--  Idempotente: se puede ejecutar varias veces sin error.
-- ============================================================================

create table if not exists public.user_entitlements (
  user_id        uuid primary key references auth.users(id) on delete cascade,

  -- 'none' | 'weekly' | 'annual' | 'trial'
  plan           text not null default 'none',

  -- Fin del acceso. NULL = sin acceso. Se compara siempre con now() del
  -- servidor, nunca con el reloj del dispositivo.
  expires_at     timestamptz,

  -- La prueba gratuita se consume una sola vez. Vive aquí, no en el
  -- dispositivo, para que sobreviva a una reinstalación.
  -- OJO: solo sobrevive de verdad si el usuario vinculó su cuenta a un
  -- correo (ver AccountScreen); con una sesión anónima nueva vuelve a
  -- estar disponible. El cierre definitivo de ese hueco es configurar la
  -- prueba como oferta de Play Console, que Google asocia a la cuenta de
  -- Google del usuario. Ver RELEASE.md.
  trial_used     boolean not null default false,

  platform       text,          -- 'android' | 'ios'
  product_id     text,
  purchase_token text,          -- token de Play / transacción de StoreKit
  updated_at     timestamptz not null default now()
);

-- Un mismo recibo no puede dar acceso a dos cuentas distintas: sin esto,
-- compartir un `purchaseToken` desbloquearía premium a todo el que lo pegue.
create unique index if not exists user_entitlements_token_idx
  on public.user_entitlements (purchase_token)
  where purchase_token is not null;

drop trigger if exists trg_user_entitlements_updated on public.user_entitlements;
create trigger trg_user_entitlements_updated
  before update on public.user_entitlements
  for each row execute function public.set_updated_at();

alter table public.user_entitlements enable row level security;

-- SOLO lectura de lo propio. Deliberadamente NO hay policies de insert,
-- update ni delete: escribir es competencia exclusiva de la Edge Function.
drop policy if exists "own entitlement select" on public.user_entitlements;
create policy "own entitlement select" on public.user_entitlements
  for select to authenticated using (auth.uid() = user_id);

-- ============================================================================
--  Vista `my_entitlement`
-- ----------------------------------------------------------------------------
--  Devuelve `is_active` ya calculado con el reloj del SERVIDOR. Así la app no
--  tiene que comparar fechas con su propio reloj, que es justo lo que se
--  puede manipular.
--
--  `security_invoker = on` para que la vista respete el RLS de quien
--  consulta; sin eso, una vista se ejecuta con los permisos de su creador y
--  expondría las filas de todos.
-- ============================================================================
drop view if exists public.my_entitlement;
create view public.my_entitlement
  with (security_invoker = on)
  as
select
  user_id,
  plan,
  expires_at,
  trial_used,
  (expires_at is not null and expires_at > now()) as is_active,
  now() as server_time
from public.user_entitlements
where user_id = auth.uid();

grant select on public.my_entitlement to authenticated;

-- ============================================================================
--  Borrado de datos
-- ----------------------------------------------------------------------------
--  `user_entitlements` NO se incluye en el borrado de "Borrar mis datos": es
--  el registro de una compra, no progreso de aprendizaje. Borrarlo dejaría al
--  usuario sin el acceso que pagó y sin rastro para reclamarlo, y además
--  liberaría su `trial_used`. La fila desaparece igualmente si se elimina la
--  cuenta de auth (ON DELETE CASCADE), que es lo que hace la Edge Function
--  `delete-account`.
-- ============================================================================
