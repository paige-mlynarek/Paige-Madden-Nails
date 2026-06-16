-- ============================================================
-- Payment handles for the checkout payment screen.
-- Paige edits her Venmo / Zelle / Cash App / Apple Pay handles
-- from the admin Settings page. The public site (anon key) reads
-- only methods that are enabled AND have a handle filled in, so
-- nothing shows on checkout until Paige sets it.
-- ============================================================

create table if not exists public.payment_methods (
  id         text primary key,          -- 'venmo' | 'zelle' | 'cashapp' | 'applepay'
  label      text not null,
  handle     text,                       -- @username, $cashtag, email or phone
  enabled    boolean not null default true,
  sort       int not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.payment_methods enable row level security;

-- Public visitors see only enabled methods that have a handle set.
drop policy if exists "anyone can read enabled payment methods" on public.payment_methods;
create policy "anyone can read enabled payment methods" on public.payment_methods
  for select to anon
  using (enabled and handle is not null and length(trim(handle)) > 0);

-- Paige (authenticated admin) reads every method, incl. blank/disabled.
drop policy if exists "admin can read all payment methods" on public.payment_methods;
create policy "admin can read all payment methods" on public.payment_methods
  for select to authenticated using (public.is_admin());

-- Paige can edit handles + toggle methods on/off.
drop policy if exists "admin can update payment methods" on public.payment_methods;
create policy "admin can update payment methods" on public.payment_methods
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- Seed the four fixed methods (handles blank until Paige fills them in).
insert into public.payment_methods (id, label, handle, enabled, sort) values
  ('venmo',    'Venmo',     null, true, 1),
  ('zelle',    'Zelle',     null, true, 2),
  ('cashapp',  'Cash App',  null, true, 3),
  ('applepay', 'Apple Pay', null, true, 4)
on conflict (id) do nothing;
