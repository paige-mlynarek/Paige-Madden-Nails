-- ============================================================
-- Status redesign + editable customer-notification templates.
--
-- New status model mirrors Paige's real workflow and branches on
-- fulfillment:
--   shipping:  new → in_progress → ready_to_ship → ready_for_label
--   pickup:    new → in_progress → completed
--   (+ cancelled at any point)
-- The old 'quoted' status goes away (the drawer quote/price card is
-- independent), and 'ready' splits into ready_to_ship / completed.
--
-- Each status maps to an on-brand customer notification whose wording
-- Paige edits from admin Settings (notification_templates table below).
-- ============================================================

-- 1. Drop the old constraint first so the migrated values are allowed
--    while we rewrite the rows.
alter table public.orders drop constraint if exists orders_status_chk;

-- 2. Migrate existing rows to the new status set.
update public.orders set status = 'in_progress' where status = 'quoted';
update public.orders set status = 'ready_to_ship'
  where status = 'ready' and fulfillment = 'shipping';
update public.orders set status = 'completed'
  where status = 'ready' and fulfillment <> 'shipping';

-- 3. Add the new constraint.
alter table public.orders add constraint orders_status_chk
  check (status in ('new','in_progress','ready_to_ship','ready_for_label','completed','cancelled'));

-- ============================================================
-- 4. Customer notification templates.
--    One row per status. Paige edits subject/heading/body from
--    Settings; the admin wraps `body` in the branded HTML shell.
-- ============================================================
create table if not exists public.notification_templates (
  status     text primary key,   -- matches orders.status values
  subject    text not null,
  heading    text not null,
  body       text not null,      -- plain message; brand HTML shell wraps it
  enabled    boolean not null default true,
  sort       int not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.notification_templates enable row level security;

-- Public/anon can read enabled templates (a future edge function may
-- render them when sending mail).
drop policy if exists "anyone can read enabled templates" on public.notification_templates;
create policy "anyone can read enabled templates" on public.notification_templates
  for select to anon using (enabled);

-- Paige (authenticated admin) reads every template.
drop policy if exists "admin can read all templates" on public.notification_templates;
create policy "admin can read all templates" on public.notification_templates
  for select to authenticated using (public.is_admin());

-- Paige can edit the copy + toggle templates on/off.
drop policy if exists "admin can update templates" on public.notification_templates;
create policy "admin can update templates" on public.notification_templates
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- Seed default on-brand copy for each status.
insert into public.notification_templates (status, subject, heading, body, enabled, sort) values
  ('new',            'We''ve got your order 💅',          'Your order is in',
    'Thank you for your order! Paige has received your details and will review your design and sizes shortly. You''ll hear from us with your quote and next steps soon.', true, 1),
  ('in_progress',    'Paige is painting your set ✨',      'Now in the studio',
    'Great news — your custom set is now in progress. Paige is hand-painting each nail with care. We''ll let you know the moment it''s finished.', true, 2),
  ('ready_to_ship',  'Your set is finished 💕',           'All done and packed',
    'Your custom set is complete and carefully packed. It''s ready to head your way — we''ll send tracking as soon as your label is created.', true, 3),
  ('ready_for_label','Your set is heading your way 📦',    'On the way to you',
    'Your order is on its way! Keep an eye on your mailbox. If a tracking number is available, you''ll find it below.', true, 4),
  ('completed',      'Your set is ready for pickup 🌸',    'Ready when you are',
    'Your custom set is finished and ready for pickup. Reach out to Paige to arrange a time that works for you. We can''t wait for you to see it!', true, 5),
  ('cancelled',      'About your order',                   'Your order was cancelled',
    'Your order has been cancelled. If this wasn''t expected or you have any questions, please reply and Paige will be happy to help.', true, 6)
on conflict (status) do nothing;
