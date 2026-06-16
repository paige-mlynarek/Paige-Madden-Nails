-- ============================================================
-- Admin access for Paige.
-- The public site uses the anon key (INSERT-only). The admin
-- (admin.html) authenticates via email OTP; RLS below grants
-- the authenticated owner full read/manage on orders.
-- Gated to a single email so a stray signup sees nothing.
-- ============================================================

-- Notification state: an order is "unseen" until Paige opens it.
alter table public.orders
  add column if not exists admin_seen boolean not null default false;

create index if not exists orders_admin_seen_idx on public.orders (admin_seen) where admin_seen = false;

-- Who counts as the admin/owner.
create or replace function public.is_admin() returns boolean
language sql stable
as $$
  select coalesce((auth.jwt() ->> 'email') = 'paige@idealtraits.com', false);
$$;

-- ---------- Orders ----------
drop policy if exists "admin can read orders"   on public.orders;
create policy "admin can read orders"   on public.orders
  for select to authenticated using (public.is_admin());

drop policy if exists "admin can update orders" on public.orders;
create policy "admin can update orders" on public.orders
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admin can delete orders" on public.orders;
create policy "admin can delete orders" on public.orders
  for delete to authenticated using (public.is_admin());

-- ---------- Order photos ----------
drop policy if exists "admin can read order photos" on public.order_photos;
create policy "admin can read order photos" on public.order_photos
  for select to authenticated using (public.is_admin());

-- ---------- Reference data (authenticated reads everything, incl. inactive) ----------
drop policy if exists "admin can read all tiers" on public.design_tiers;
create policy "admin can read all tiers" on public.design_tiers
  for select to authenticated using (public.is_admin());

drop policy if exists "admin can read all shapes" on public.nail_shapes;
create policy "admin can read all shapes" on public.nail_shapes
  for select to authenticated using (public.is_admin());

-- ---------- Realtime: live new-order notifications ----------
do $$
begin
  begin
    alter publication supabase_realtime add table public.orders;
  exception when duplicate_object then null;
  end;
end $$;
