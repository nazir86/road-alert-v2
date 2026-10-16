-- ROAD ALERT V2 : EMAILS
-- A executer seulement apres verification des tables reports
-- et status_history. Aucune suppression des signalements.

create table if not exists public.road_email_queue (
  event_key text primary key,
  kind text not null check (kind in ('new_report', 'status_changed')),
  report_id uuid not null references public.reports(id) on delete cascade,
  target_user uuid,
  old_status text,
  new_status text,
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);

create index if not exists road_email_queue_pending
  on public.road_email_queue(next_attempt_at)
  where sent_at is null;

alter table public.road_email_queue enable row level security;

revoke all on public.road_email_queue from anon, authenticated;

-- Notification quand un signalement est recu sur le serveur.
create or replace function public.road_queue_new_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.road_email_queue(
    event_key, kind, report_id
  )
  values (
    'created:' || new.id::text,
    'new_report',
    new.id
  )
  on conflict (event_key) do nothing;

  return new;
end;
$$;

drop trigger if exists road_notify_new_report on public.reports;

create trigger road_notify_new_report
after insert on public.reports
for each row
execute function public.road_queue_new_report();

-- Notification au citoyen quand le statut change.
create or replace function public.road_queue_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
begin
  select r.user_id into owner_id
  from public.reports r
  where r.id = new.report_id;

  insert into public.road_email_queue(
    event_key, kind, report_id, target_user,
    old_status, new_status
  )
  values (
    'status:' || new.id::text,
    'status_changed',
    new.report_id,
    owner_id,
    new.old_status,
    new.new_status
  )
  on conflict (event_key) do nothing;

  return new;
end;
$$;

drop trigger if exists road_notify_status on public.status_history;

create trigger road_notify_status
after insert on public.status_history
for each row
execute function public.road_queue_status();

-- Recuperation securisee des emails a envoyer.
create or replace function public.road_claim_email_jobs(p_limit integer default 10)
returns setof public.road_email_queue
language sql
security definer
set search_path = public
as $$
  update public.road_email_queue j
  set attempts = j.attempts + 1,
      next_attempt_at = now() + interval '5 minutes'
  where j.event_key in (
    select q.event_key
    from public.road_email_queue q
    where q.sent_at is null
      and q.attempts < 5
      and q.next_attempt_at <= now()
    order by q.created_at
    for update skip locked
    limit greatest(1, least(p_limit, 20))
  )
  returning j.*;
$$;

revoke all on function public.road_claim_email_jobs(integer)
  from public, anon, authenticated;
grant execute on function public.road_claim_email_jobs(integer)
  to service_role;

-- Protection contre les rapports hebdomadaires repetes.
create table if not exists public.road_weekly_email_runs (
  week_key text primary key,
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  sent_at timestamptz,
  last_error text
);

alter table public.road_weekly_email_runs enable row level security;
revoke all on public.road_weekly_email_runs from anon, authenticated;

create or replace function public.road_claim_weekly_email(p_week text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.road_weekly_email_runs(week_key)
  values (p_week)
  on conflict do nothing;

  update public.road_weekly_email_runs
  set attempts = attempts + 1,
      next_attempt_at = now() + interval '10 minutes'
  where week_key = p_week
    and sent_at is null
    and attempts < 5
    and next_attempt_at <= now();

  return found;
end;
$$;

revoke all on function public.road_claim_weekly_email(text)
  from public, anon, authenticated;
grant execute on function public.road_claim_weekly_email(text)
  to service_role;
