-- ============================================================
-- Pin a non-mutable search_path on the admin check (linter
-- 0011_function_search_path_mutable). auth.jwt() is already
-- schema-qualified, so an empty search_path is safe.
-- ============================================================

create or replace function public.is_admin() returns boolean
language sql stable
set search_path = ''
as $$
  select coalesce((auth.jwt() ->> 'email') = 'paige@idealtraits.com', false);
$$;
