-- CONGRATS visitor analytics
-- Run this once in Supabase Dashboard -> SQL Editor.
-- Anonymous sign-ins must remain enabled: each browser then receives a safe,
-- persistent anonymous user id used only to count visits.

create extension if not exists pgcrypto;

create table if not exists public.site_visits (
  id uuid primary key default gen_random_uuid(),
  visitor_id uuid not null references auth.users(id) on delete cascade,
  page_path text not null default '/',
  created_at timestamptz not null default now()
);

create index if not exists site_visits_created_at_idx
  on public.site_visits (created_at desc);
create index if not exists site_visits_visitor_id_idx
  on public.site_visits (visitor_id);

alter table public.site_visits enable row level security;

drop policy if exists "visitors add their own visit" on public.site_visits;
create policy "visitors add their own visit"
  on public.site_visits for insert to authenticated
  with check (visitor_id = auth.uid());

-- Counts are only returned after the existing is_admin() role check. The raw
-- visitor list is never exposed to normal visitors.
create or replace function public.get_site_visit_metrics()
returns table (website_visits bigint, unique_visitors bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  return query
  select count(*)::bigint, count(distinct visitor_id)::bigint
  from public.site_visits;
end;
$$;

revoke all on function public.get_site_visit_metrics() from public;
grant execute on function public.get_site_visit_metrics() to authenticated;
