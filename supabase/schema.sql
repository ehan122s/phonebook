create type public.user_role as enum ('admin', 'penyuluh');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  nip text unique,
  role public.user_role not null default 'penyuluh',
  signature_path text,
  created_at timestamptz not null default now()
);
create function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)), 'penyuluh');
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
create table public.categories (id uuid primary key default gen_random_uuid(), name text not null unique, description text, created_at timestamptz not null default now());
create table public.report_templates (id uuid primary key default gen_random_uuid(), name text not null, logo_path text, header_html text, body_html text, is_active boolean not null default true, created_at timestamptz not null default now());
create table public.activities (
  id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references public.profiles(id) on delete restrict,
  category_id uuid references public.categories(id) on delete set null, title text not null, activity_date date not null, location text,
  village text not null, district text not null, regency text not null, farmer_group text, participant_count integer not null default 0 check(participant_count >= 0),
  material text, objective text, result text, obstacle text, follow_up text, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.activity_documents (id uuid primary key default gen_random_uuid(), activity_id uuid not null references public.activities(id) on delete cascade, file_name text not null, file_path text not null unique, mime_type text not null, file_size bigint not null, created_at timestamptz not null default now());
create table public.activity_photos (id uuid primary key default gen_random_uuid(), activity_id uuid not null references public.activities(id) on delete cascade, file_name text not null, file_path text not null unique, mime_type text not null, file_size bigint not null, caption text, created_at timestamptz not null default now());
create index activities_archive_idx on public.activities (activity_date desc, category_id, title);
create index activities_search_idx on public.activities using gin (to_tsvector('indonesian', title || ' ' || village || ' ' || district || ' ' || regency));

alter table public.profiles enable row level security; alter table public.categories enable row level security; alter table public.report_templates enable row level security; alter table public.activities enable row level security; alter table public.activity_documents enable row level security; alter table public.activity_photos enable row level security;
create function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$ select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin') $$;
create policy "profiles own or admin" on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "profiles admin write" on public.profiles for all using (public.is_admin()) with check (public.is_admin());
create policy "activities visible" on public.activities for select using (user_id = auth.uid() or public.is_admin());
create policy "activities owner insert" on public.activities for insert with check (user_id = auth.uid());
create policy "activities owner update" on public.activities for update using (user_id = auth.uid() or public.is_admin());
create policy "activities owner delete" on public.activities for delete using (user_id = auth.uid() or public.is_admin());
create policy "categories readable" on public.categories for select using (true);
create policy "categories admin write" on public.categories for all using (public.is_admin()) with check (public.is_admin());
create policy "templates readable" on public.report_templates for select using (true);
create policy "templates admin write" on public.report_templates for all using (public.is_admin()) with check (public.is_admin());
create policy "documents visible" on public.activity_documents for select using (exists(select 1 from public.activities a where a.id = activity_id and (a.user_id = auth.uid() or public.is_admin())));
create policy "documents owner write" on public.activity_documents for all using (exists(select 1 from public.activities a where a.id = activity_id and (a.user_id = auth.uid() or public.is_admin()))) with check (exists(select 1 from public.activities a where a.id = activity_id and a.user_id = auth.uid()));
create policy "photos visible" on public.activity_photos for select using (exists(select 1 from public.activities a where a.id = activity_id and (a.user_id = auth.uid() or public.is_admin())));
create policy "photos owner write" on public.activity_photos for all using (exists(select 1 from public.activities a where a.id = activity_id and (a.user_id = auth.uid() or public.is_admin()))) with check (exists(select 1 from public.activities a where a.id = activity_id and a.user_id = auth.uid()));
insert into storage.buckets (id, name, public) values ('activity-documents', 'activity-documents', false), ('activity-photos', 'activity-photos', false);
create policy "activity storage select" on storage.objects for select using (
  bucket_id in ('activity-documents', 'activity-photos') and
  exists(select 1 from public.activities a where a.id::text = (storage.foldername(name))[1] and (a.user_id = auth.uid() or public.is_admin()))
);
create policy "activity storage upload" on storage.objects for insert with check (
  bucket_id in ('activity-documents', 'activity-photos') and
  exists(select 1 from public.activities a where a.id::text = (storage.foldername(name))[1] and a.user_id = auth.uid())
);
create policy "activity storage delete" on storage.objects for delete using (
  bucket_id in ('activity-documents', 'activity-photos') and
  exists(select 1 from public.activities a where a.id::text = (storage.foldername(name))[1] and (a.user_id = auth.uid() or public.is_admin()))
);
