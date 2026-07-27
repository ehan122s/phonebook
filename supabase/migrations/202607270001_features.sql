-- Run after schema.sql. Adds API-oriented views, dashboard statistics, audit fields, and report metadata.
create table if not exists public.generated_reports (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  format text not null check (format in ('pdf', 'docx')),
  file_path text not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);
alter table public.activities add column if not exists latitude double precision;
alter table public.activities add column if not exists longitude double precision;

create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;
drop trigger if exists activities_set_updated_at on public.activities;
create trigger activities_set_updated_at before update on public.activities for each row execute function public.set_updated_at();

create or replace function public.dashboard_stats() returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'activities', (select count(*) from public.activities a where a.user_id = auth.uid() or public.is_admin()),
    'documents', (select count(*) from public.activity_documents d join public.activities a on a.id = d.activity_id where a.user_id = auth.uid() or public.is_admin()),
    'photos', (select count(*) from public.activity_photos p join public.activities a on a.id = p.activity_id where a.user_id = auth.uid() or public.is_admin()),
    'categories', (select count(*) from public.categories),
    'monthly', coalesce((select jsonb_agg(jsonb_build_object('month', month_no, 'total', total) order by month_no) from (
      select extract(month from activity_date)::int as month_no, count(*)::int as total from public.activities where (user_id = auth.uid() or public.is_admin()) and extract(year from activity_date) = extract(year from current_date) group by 1
    ) months), '[]'::jsonb)
  );
$$;

alter table public.generated_reports enable row level security;
create policy "profiles self insert" on public.profiles for insert with check (id = auth.uid() and role = 'penyuluh');
create policy "reports visible to activity owner" on public.generated_reports for select using (exists(select 1 from public.activities a where a.id = activity_id and (a.user_id = auth.uid() or public.is_admin())));
create policy "reports service insert" on public.generated_reports for insert with check (created_by = auth.uid());
grant execute on function public.dashboard_stats() to authenticated;

insert into storage.buckets (id, name, public) values ('generated-reports', 'generated-reports', false) on conflict (id) do nothing;
create policy "report storage select" on storage.objects for select using (bucket_id = 'generated-reports' and auth.uid() is not null);
