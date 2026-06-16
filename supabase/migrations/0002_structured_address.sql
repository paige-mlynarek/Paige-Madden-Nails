-- ============================================================
-- Replace the single free-text shipping address with structured
-- US address fields (better for shipping labels + validation).
-- orders is empty at this point, so no data migration needed.
-- ============================================================

alter table public.orders
  drop column if exists shipping_address,
  add column if not exists ship_to_name  text,           -- recipient (defaults to customer in app)
  add column if not exists address_line1 text,           -- street
  add column if not exists address_line2 text,           -- apt / suite (optional)
  add column if not exists city          text,
  add column if not exists region        text,           -- state
  add column if not exists postal_code   text,           -- ZIP
  add column if not exists country       text default 'US';
