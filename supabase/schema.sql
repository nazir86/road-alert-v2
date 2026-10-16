-- ROAD ALERT V2 : à exécuter dans Supabase SQL Editor, sur un projet neuf.
-- Attention : ne pas exécuter sur l'ancien projet sans contrôler les migrations.
create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nom text not null default '',
  role text not null default 'citoyen'
    check (role in ('citoyen','agent','admin')),
  created_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key,
  user_id uuid not null references public.profiles(id),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  gps_accuracy real not null check (gps_accuracy >= 0),
  type text not null check (type in ('nid_de_poule','fissure','affaissement','autre')),
  severity text not null check (severity in ('faible','moyenne','grave')),
  comment text not null default '',
  photo_url text,
  status text not null default 'nouveau'
    check (status in ('nouveau','en_cours','repare')),
  created_at timestamptz not null,
  synced_at timestamptz not null default now(),
  duration_seconds integer not null default 0 check (duration_seconds >= 0)
);
create index reports_user_date on public.reports (user_id, created_at desc);
create index reports_status on public.reports(status);

create table public.status_history (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  old_status text,
  new_status text not null,
  changed_by uuid not null references public.profiles(id),
  changed_at timestamptz not null default now()
);

create or replace function public.create_profile_for_user()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  insert into public.profiles(id,nom,role) values(new.id,
    coalesce(new.raw_user_meta_data->>'nom',''), 'citoyen')
  on conflict (id) do nothing;
  return new;
end $$;
create trigger create_profile_after_signup
  after insert on auth.users for each row
  execute procedure public.create_profile_for_user();

-- Les comptes existants sont inscrits comme citoyens par défaut.
insert into public.profiles(id, nom, role)
select id, coalesce(raw_user_meta_data->>'nom',''), 'citoyen' from auth.users
on conflict (id) do nothing;

-- Vérification des rôles sans dépendre des policies de profiles (évite récursion).
create or replace function public.is_staff()
returns boolean language sql security definer stable
set search_path = public as $$
  select exists(select 1 from public.profiles
    where id = (select auth.uid()) and role in ('agent','admin'));
$$;
revoke all on function public.is_staff() from public;
grant execute on function public.is_staff() to authenticated;

alter table public.profiles enable row level security;
alter table public.reports enable row level security;
alter table public.status_history enable row level security;

create policy "profiles select own or staff" on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.is_staff());
-- Aucune modification directe des rôles par un citoyen.

create policy "reports read" on public.reports for select to authenticated using (true);
create policy "reports insert own" on public.reports for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'nouveau');
-- Un citoyen peut rejouer l'upsert pour un signalement encore nouveau.
-- Il ne peut pas remettre à zéro un signalement déjà traité.
create policy "reports update own new" on public.reports for update to authenticated
  using (user_id = (select auth.uid()) and status = 'nouveau')
  with check (user_id = (select auth.uid()) and status = 'nouveau');
create policy "reports update staff" on public.reports for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy "history read own or staff" on public.status_history for select to authenticated
  using (public.is_staff() or exists (
    select 1 from public.reports r where r.id = report_id and r.user_id = (select auth.uid())));

-- Historique inscrit par trigger côté serveur, jamais par un client Flutter.
create or replace function public.log_report_status()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  if new.status is distinct from old.status then
    if not public.is_staff() then
      raise exception 'Seul un agent peut changer le statut';
    end if;
    insert into public.status_history(report_id,old_status,new_status,changed_by)
    values (new.id, old.status, new.status, (select auth.uid()));
  end if;
  return new;
end $$;
create trigger report_status_changed before update on public.reports
  for each row execute function public.log_report_status();

insert into storage.buckets(id, name, public, file_size_limit,
  allowed_mime_types) values ('photos', 'photos', true, 5242880,
  array['image/jpeg']) on conflict (id) do nothing;

-- Chaque utilisateur écrit uniquement dans photos/<son-uuid>/<report-uuid>.jpg.
create policy "photos authenticated upload own folder" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "photos update own folder" on storage.objects
  for update to authenticated using (
    bucket_id = 'photos' and owner_id = (select auth.uid())::text)
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Rôles agent et admin : les attribuer MANUELLEMENT depuis SQL Editor / console sécurisée.
-- Exemple, jamais dans le code Flutter :
-- update public.profiles set role='agent' where id='<UUID_D_UN_AGENT>';
