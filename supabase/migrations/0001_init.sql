-- ============================================================
-- Paige Madden Nails — initial schema
-- Backs the custom-order form (index.html).
-- Public site uses the anon key, so RLS is locked down:
-- visitors can INSERT orders/photos but cannot read anyone's data.
-- Paige reads orders via the Supabase dashboard (service role
-- bypasses RLS) or a future authenticated admin view.
-- ============================================================

-- ---------- Reference tables (editable in the dashboard) ----------

create table if not exists public.design_tiers (
  id          text primary key,            -- 'classic' | 'custom'
  name        text not null,
  price       numeric(10,2) not null,
  description text,
  active      boolean not null default true,
  sort        int not null default 0
);

create table if not exists public.nail_shapes (
  id     text primary key,                 -- 'Short Almond', 'Oval', ...
  name   text not null,
  image  text,                             -- filename in the site, e.g. 'shape-oval.png'
  active boolean not null default true,
  sort   int not null default 0
);

-- ---------- Orders ----------

create table if not exists public.orders (
  id               uuid primary key default gen_random_uuid(),
  created_at       timestamptz not null default now(),

  -- customer
  customer_name    text not null,
  email            text,
  phone            text,

  -- design
  nail_shape       text,
  design_tier      text not null default 'classic',  -- snapshot of tier id
  tier_price       numeric(10,2),                     -- price shown at order time
  sizes            jsonb not null default '{}'::jsonb, -- {"Thumb":"3","Index":"2",...}
  notes            text,

  -- fulfillment
  fulfillment      text not null default 'pickup',    -- 'pickup' | 'shipping'
  shipping_address text,
  ship_speed       text,                              -- 'standard' | 'rush'

  -- Paige's workflow
  status           text not null default 'new',       -- new→quoted→in_progress→ready→completed/cancelled
  quoted_price     numeric(10,2),

  source           text not null default 'web',

  constraint orders_contact_present check (
    (email is not null and length(trim(email)) > 0)
    or (phone is not null and length(trim(phone)) > 0)
  ),
  constraint orders_tier_chk       check (design_tier in ('classic','custom')),
  constraint orders_fulfillment_chk check (fulfillment in ('pickup','shipping')),
  constraint orders_ship_speed_chk  check (ship_speed is null or ship_speed in ('standard','rush')),
  constraint orders_status_chk      check (status in ('new','quoted','in_progress','ready','completed','cancelled'))
);

create index if not exists orders_created_at_idx on public.orders (created_at desc);
create index if not exists orders_status_idx     on public.orders (status);

-- ---------- Order photos ----------

create table if not exists public.order_photos (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references public.orders(id) on delete cascade,
  storage_path text not null,              -- path within the 'inspiration' Storage bucket
  position     int not null default 0,
  created_at   timestamptz not null default now()
);

create index if not exists order_photos_order_id_idx on public.order_photos (order_id);

-- ============================================================
-- Row Level Security
-- ============================================================

alter table public.orders        enable row level security;
alter table public.order_photos  enable row level security;
alter table public.design_tiers  enable row level security;
alter table public.nail_shapes   enable row level security;

-- Public visitors may submit orders + photos, nothing else.
-- Light bounds on the insert checks add basic anti-garbage protection
-- (and avoid a literal `true` policy). Table CHECK constraints enforce the rest.
drop policy if exists "anon can insert orders" on public.orders;
create policy "anon can insert orders" on public.orders
  for insert to anon with check (char_length(customer_name) between 1 and 200);

drop policy if exists "anon can insert order photos" on public.order_photos;
create policy "anon can insert order photos" on public.order_photos
  for insert to anon with check (char_length(storage_path) between 1 and 500);

-- Public visitors may read active reference data (to render the form).
drop policy if exists "anyone can read active tiers" on public.design_tiers;
create policy "anyone can read active tiers" on public.design_tiers
  for select to anon using (active);

drop policy if exists "anyone can read active shapes" on public.nail_shapes;
create policy "anyone can read active shapes" on public.nail_shapes
  for select to anon using (active);

-- ============================================================
-- Seed reference data (matches current index.html)
-- ============================================================

insert into public.design_tiers (id, name, price, description, sort) values
  ('classic', 'Classic', 40, 'Solid colours, French tips, glitter or one simple accent nail.', 1),
  ('custom',  'Custom',  50, 'Hand-painted art, charms, chrome, or intricate multi-nail designs.', 2)
on conflict (id) do nothing;

insert into public.nail_shapes (id, name, image, sort) values
  ('Short Almond', 'Short Almond', 'shape-long-almond.png', 1),
  ('Long Almond',  'Long Almond',  'shape-short-almond.png', 2),
  ('Oval',         'Oval',         'shape-oval.png', 3),
  ('Square',       'Square',       'shape-square.png', 4)
on conflict (id) do nothing;
