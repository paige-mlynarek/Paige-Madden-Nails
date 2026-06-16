-- ============================================================
-- Human-friendly sequential order number (PM-<n>).
-- Starts at a random-ish base (488) and increments by one per
-- order. Customers reference it in their Venmo/Zelle payment note
-- so Paige can match a payment to an order in the admin.
--
-- The public site uses the anon key with INSERT-only RLS and CANNOT
-- read a row back, so a plain insert can't return the generated
-- number. create_order() is SECURITY DEFINER: it inserts as the
-- table owner (bypassing RLS) and RETURNS the new id + order_no so
-- the thank-you screen can show it immediately. Only whitelisted
-- fields are accepted — status, pricing overrides and admin flags
-- are never settable by the public.
-- ============================================================

create sequence if not exists public.order_no_seq start with 488 increment by 1;

alter table public.orders
  add column if not exists order_no bigint;

-- Backfill any pre-existing rows, then make it auto-assign + unique.
update public.orders set order_no = nextval('public.order_no_seq') where order_no is null;

alter table public.orders
  alter column order_no set default nextval('public.order_no_seq');

create unique index if not exists orders_order_no_key on public.orders (order_no);

-- ---------- Public order intake ----------
create or replace function public.create_order(
  p_customer_name text,
  p_email         text,
  p_phone         text,
  p_nail_shape    text,
  p_design_tier   text,
  p_tier_price    numeric,
  p_sizes         jsonb,
  p_notes         text,
  p_fulfillment   text,
  p_ship_speed    text,
  p_ship_to_name  text,
  p_address_line1 text,
  p_address_line2 text,
  p_city          text,
  p_region        text,
  p_postal_code   text,
  p_country       text
) returns table (id uuid, order_no bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  insert into public.orders (
    customer_name, email, phone, nail_shape, design_tier, tier_price,
    sizes, notes, fulfillment, ship_speed, ship_to_name,
    address_line1, address_line2, city, region, postal_code, country
  ) values (
    nullif(trim(p_customer_name), ''),
    nullif(trim(p_email), ''),
    nullif(trim(p_phone), ''),
    nullif(p_nail_shape, ''),
    coalesce(nullif(p_design_tier, ''), 'classic'),
    p_tier_price,
    coalesce(p_sizes, '{}'::jsonb),
    nullif(trim(p_notes), ''),
    coalesce(nullif(p_fulfillment, ''), 'pickup'),
    nullif(p_ship_speed, ''),
    nullif(trim(p_ship_to_name), ''),
    nullif(trim(p_address_line1), ''),
    nullif(trim(p_address_line2), ''),
    nullif(trim(p_city), ''),
    nullif(trim(p_region), ''),
    nullif(trim(p_postal_code), ''),
    coalesce(nullif(p_country, ''), 'US')
  )
  returning orders.id, orders.order_no;
end;
$$;

revoke all on function public.create_order(
  text, text, text, text, text, numeric, jsonb, text, text, text,
  text, text, text, text, text, text, text
) from public;

grant execute on function public.create_order(
  text, text, text, text, text, numeric, jsonb, text, text, text,
  text, text, text, text, text, text, text
) to anon, authenticated;
