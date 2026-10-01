-- =============================================================================
-- WDS unified data platform — 1/3: core schema, lifecycle rules, RLS
--
-- ONE Supabase project is the single source of truth for:
--   events  ->  bouts (fights)  ->  round_scores (ScoreHUB judges)  ->  results
--   fighters (global, shared by every event)  ->  fighter_rankings (derived)
--
--   * WDS admin dashboard (management) creates / edits events, fighters, bouts.
--   * ScoreHUB (officials) reads the same events and writes scores + results.
--   * WDS public pages + Rankings read events, the public fight card and the
--     rankings table.  Rankings are derived ONLY from results that management
--     has FINALIZED (see migration 2).
--
-- Safe to run on a project that already has older tables of the same names:
-- any table this migration owns that was NOT created by it is renamed to
-- legacy_<name> (data kept, nothing dropped).  Safe to re-run.
-- =============================================================================

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- 0. Park conflicting legacy tables (from the old admin dashboard schema and
--    the old ScoreHUB 001_init_schema.sql).  A table is "ours" when its
--    comment starts with 'wds:v1'.
-- -----------------------------------------------------------------------------
do $$
declare
  t text;
  owned text[] := array[
    'profiles','official_invites','events','fighters','fighter_contacts',
    'event_fighters','bouts','bout_judges','round_scores','fighter_rankings','bout_presence'
  ];
  conflicting text[] := array[
    -- old admin dashboard / old ScoreHUB tables that are not reused
    'judges','scorecards','rankings','officials','leagues','rounds',
    'judge_scorecards','bout_outcomes','bout_states'
  ];
  suffix text := to_char(now(), 'YYYYMMDD');
begin
  foreach t in array owned loop
    if to_regclass('public.' || t) is not null
       and coalesce(obj_description(('public.' || t)::regclass, 'pg_class'), '') not like 'wds:v1%' then
      execute format('alter table public.%I rename to %I', t, 'legacy_' || t || '_' || suffix);
      raise notice 'Renamed pre-existing table public.% to legacy_%_%', t, t, suffix;
    end if;
  end loop;
  foreach t in array conflicting loop
    if to_regclass('public.' || t) is not null then
      execute format('alter table public.%I rename to %I', t, 'legacy_' || t || '_' || suffix);
      raise notice 'Renamed old table public.% to legacy_%_%', t, t, suffix;
    end if;
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 1. Officials (people who sign in): management, judges, referees.
--    One row per Supabase Auth user.  Role is NEVER taken from the client —
--    it comes from an invite created by management (official_invites).
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null default '',
  email       text,
  role        text check (role in ('ADMIN','PROMOTER','JUDGE','REFEREE')),
  phone       text,
  active      boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
comment on table public.profiles is 'wds:v1 officials & management (one per auth user)';

create table if not exists public.official_invites (
  email       text primary key check (email = lower(email)),
  name        text not null,
  role        text not null check (role in ('ADMIN','PROMOTER','JUDGE','REFEREE')),
  phone       text,
  invited_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);
comment on table public.official_invites is 'wds:v1 pre-registered officials; role source of truth';

-- -----------------------------------------------------------------------------
-- 2. Events.  Draft -> Announced -> Scheduled -> Live -> Completed (or Cancelled)
--    Date / time / venue are optional until the event is Scheduled.
-- -----------------------------------------------------------------------------
create table if not exists public.events (
  id                 uuid primary key default gen_random_uuid(),
  public_id          text not null unique default ('EVT-' || upper(substr(md5(random()::text), 1, 8))),
  slug               text not null unique,
  title              text not null check (length(trim(title)) > 1),
  series             text not null default 'rising-star'
                       check (series in ('championship','rising-star','other')),
  status             text not null default 'draft'
                       check (status in ('draft','announced','scheduled','live','completed','cancelled')),
  event_date         date,
  end_date           date,
  start_time         time,
  timezone           text not null default 'Asia/Kolkata',
  venue              text,
  city               text,
  description        text,
  poster_url         text,
  logo_url           text,           -- ScoreHUB "League Logo"
  results_url        text,           -- external results page (historic events)
  promoter_name      text not null default 'WDS Promotions',
  amateur_mma_bouts  int  not null default 0 check (amateur_mma_bouts >= 0),
  pro_mma_bouts      int  not null default 0 check (pro_mma_bouts >= 0),
  amateur_bjj_bouts  int  not null default 0 check (amateur_bjj_bouts >= 0),
  pro_bjj_bouts      int  not null default 0 check (pro_bjj_bouts >= 0),
  amateur_k1_bouts   int  not null default 0 check (amateur_k1_bouts >= 0),
  pro_k1_bouts       int  not null default 0 check (pro_k1_bouts >= 0),
  is_listed          boolean not null default true,   -- false = hidden from public lists
  starts_at          timestamptz,                     -- maintained by trigger
  card_updated_at    timestamptz not null default now(), -- bumped on any fight change (realtime signal)
  created_by         uuid references public.profiles(id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint events_date_required_once_scheduled
    check (status in ('draft','announced','cancelled') or event_date is not null),
  constraint events_end_after_start
    check (end_date is null or event_date is null or end_date >= event_date)
);
comment on table public.events is 'wds:v1 events (ScoreHUB "leagues")';
alter table public.events add column if not exists logo_url text;
create index if not exists events_status_idx on public.events(status);
create index if not exists events_date_idx   on public.events(event_date);

-- -----------------------------------------------------------------------------
-- 3. Fighters — global identity shared by every event, so a fighter's record
--    and ranking follow them from event to event.
-- -----------------------------------------------------------------------------
create table if not exists public.fighters (
  id              uuid primary key default gen_random_uuid(),
  public_id       text not null unique default ('FTR-' || upper(substr(md5(random()::text), 1, 8))),
  name            text not null check (length(trim(name)) > 0),
  name_key        text generated always as (lower(regexp_replace(trim(name), '\s+', ' ', 'g'))) stored,
  first_name      text,
  last_name       text,
  nickname        text,
  country         text,
  born_year       int check (born_year is null or born_year between 1900 and 2100),
  weight_class    text,
  team            text,
  coach_name      text,
  photo_url       text,
  hometown        text,           -- ScoreHUB "City, State, Country"
  height          text,
  weight          text,
  social_url      text,           -- ScoreHUB "Sherdog ID # or Social Media Link"
  declared_record text,           -- record as declared by the fighter's camp, e.g. "8-2-0"
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
comment on table public.fighters is 'wds:v1 global fighter identities';
alter table public.fighters add column if not exists hometown   text;
alter table public.fighters add column if not exists height     text;
alter table public.fighters add column if not exists weight     text;
alter table public.fighters add column if not exists social_url text;
create index if not exists fighters_name_key_idx on public.fighters(name_key);

-- Private personal details: management only (never public).
create table if not exists public.fighter_contacts (
  fighter_id    uuid primary key references public.fighters(id) on delete cascade,
  contact_no    text,
  date_of_birth date,
  updated_at    timestamptz not null default now()
);
alter table public.fighter_contacts add column if not exists date_of_birth date;
comment on table public.fighter_contacts is 'wds:v1 private fighter contact details';

-- The roster of an event (ScoreHUB "league fighters").
create table if not exists public.event_fighters (
  event_id        uuid not null references public.events(id) on delete cascade,
  fighter_id      uuid not null references public.fighters(id) on delete cascade,
  weight_class    text,
  declared_record text,
  created_at      timestamptz not null default now(),
  primary key (event_id, fighter_id)
);
comment on table public.event_fighters is 'wds:v1 event roster';
create index if not exists event_fighters_fighter_idx on public.event_fighters(fighter_id);

-- -----------------------------------------------------------------------------
-- 4. Bouts (fights), judge seats, round scores.
-- -----------------------------------------------------------------------------
create table if not exists public.bouts (
  id               uuid primary key default gen_random_uuid(),
  public_id        text not null unique default ('BOU-' || upper(substr(md5(random()::text), 1, 8))),
  event_id         uuid not null references public.events(id) on delete cascade,
  bout_number      int  not null default 1 check (bout_number > 0),
  bout_name        text,
  discipline       text not null default 'MMA' check (discipline in ('MMA','BJJ','K1')),
  bout_type        text not null default 'PROFESSIONAL' check (bout_type in ('PROFESSIONAL','AMATEUR')),
  weight_class     text,           -- division used for rankings
  bout_date        date,
  ring_no          text,
  total_rounds     int  not null default 3 check (total_rounds between 1 and 12),
  round_duration   int  not null default 300 check (round_duration between 30 and 1200),
  current_round    int  not null default 0 check (current_round >= 0),
  status           text not null default 'SCHEDULED'
                     check (status in ('SCHEDULED','LIVE','COMPLETED','CANCELLED')),
  blue_fighter_id  uuid references public.fighters(id) on delete restrict,
  red_fighter_id   uuid references public.fighters(id) on delete restrict,
  referee_id       uuid references public.profiles(id) on delete set null,
  round_started_at timestamptz,    -- live round clock; null = clock stopped
  started_at       timestamptz,
  completed_at     timestamptz,
  -- result (written by ScoreHUB as PROVISIONAL, confirmed by management as FINAL)
  result_type      text check (result_type in (
                     'DECISION_UNANIMOUS','DECISION_SPLIT','DECISION_MAJORITY','DRAW','MAJORITY_DRAW',
                     'KO_HEAD','KO_BODY','TKO','SUBMISSION','RNC','DOCTOR_STOPPAGE','CORNER_STOPPAGE',
                     'DQ','NO_CONTEST')),
  winner_id        uuid references public.fighters(id) on delete restrict,
  end_round        int,
  end_time_sec     int,
  result_note      text,
  result_status    text not null default 'none' check (result_status in ('none','provisional','final')),
  finalized_at     timestamptz,
  finalized_by     uuid references public.profiles(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint bouts_distinct_corners check (blue_fighter_id is null or red_fighter_id is null or blue_fighter_id <> red_fighter_id),
  constraint bouts_winner_in_bout check (winner_id is null or winner_id in (blue_fighter_id, red_fighter_id)),
  constraint bouts_final_needs_result check (result_status = 'none' or (status = 'COMPLETED' and result_type is not null))
);
comment on table public.bouts is 'wds:v1 fights';
alter table public.bouts drop constraint if exists bouts_result_type_check;
alter table public.bouts add constraint bouts_result_type_check check (result_type in (
  'DECISION_UNANIMOUS','DECISION_SPLIT','DECISION_MAJORITY','DRAW','MAJORITY_DRAW',
  'KO_HEAD','KO_BODY','TKO','SUBMISSION','RNC','DOCTOR_STOPPAGE','CORNER_STOPPAGE','DQ','NO_CONTEST'));
create index if not exists bouts_event_idx  on public.bouts(event_id, bout_number);
create index if not exists bouts_status_idx on public.bouts(status);
create index if not exists bouts_result_idx on public.bouts(result_status);
create index if not exists bouts_blue_idx   on public.bouts(blue_fighter_id);
create index if not exists bouts_red_idx    on public.bouts(red_fighter_id);

create table if not exists public.bout_judges (
  id         uuid primary key default gen_random_uuid(),
  bout_id    uuid not null references public.bouts(id) on delete cascade,
  judge_id   uuid not null references public.profiles(id) on delete cascade,
  seat       int  not null check (seat between 1 and 5),
  created_at timestamptz not null default now(),
  unique (bout_id, seat),
  unique (bout_id, judge_id)
);
comment on table public.bout_judges is 'wds:v1 judge seats per bout';
create index if not exists bout_judges_judge_idx on public.bout_judges(judge_id);

create table if not exists public.round_scores (
  id           uuid primary key default gen_random_uuid(),
  bout_id      uuid not null references public.bouts(id) on delete cascade,
  judge_id     uuid not null references public.profiles(id) on delete cascade,
  round_number int  not null check (round_number > 0),
  tally        jsonb not null default '{}'::jsonb,
  blue_score   int  not null check (blue_score between 0 and 10),
  red_score    int  not null check (red_score between 0 and 10),
  submitted    boolean not null default true,
  submitted_at timestamptz not null default now(),
  unique (bout_id, judge_id, round_number)
);
comment on table public.round_scores is 'wds:v1 judge round cards (written only through RPCs)';
create index if not exists round_scores_bout_idx on public.round_scores(bout_id, round_number);

-- -----------------------------------------------------------------------------
-- 5. Rankings (derived; written only by recompute_rankings() in migration 2).
-- -----------------------------------------------------------------------------
create table if not exists public.fighter_rankings (
  fighter_id     uuid primary key references public.fighters(id) on delete cascade,
  division_key   text not null,
  division_name  text not null,
  elo            int  not null,
  wins           int  not null default 0,
  losses         int  not null default 0,
  draws          int  not null default 0,
  no_contests    int  not null default 0,
  fights         int  not null default 0,
  division_rank  int  not null,
  overall_rank   int  not null,
  last_fight_on  date,
  updated_at     timestamptz not null default now()
);
comment on table public.fighter_rankings is 'wds:v1 ELO rankings derived from FINAL results only';
create index if not exists fighter_rankings_div_idx on public.fighter_rankings(division_key, division_rank);

-- =============================================================================
-- Helpers
-- =============================================================================

-- "Light Heavyweight" -> "lightheavyweight" (matches the Rankings page keys)
create or replace function public.wds_division_key(p text)
returns text language sql immutable as $$
  select coalesce(nullif(lower(regexp_replace(coalesce(p, ''), '[^a-zA-Z]', '', 'g')), ''), 'unclassified')
$$;

create or replace function public.wds_slugify(p text)
returns text language sql immutable as $$
  select trim(both '-' from regexp_replace(lower(coalesce(p, '')), '[^a-z0-9]+', '-', 'g'))
$$;

-- Caller's role ('ADMIN','PROMOTER','JUDGE','REFEREE') or null.
create or replace function public.wds_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid() and active
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.wds_role() = 'ADMIN', false)
$$;

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.wds_role() in ('ADMIN','PROMOTER'), false)
$$;

create or replace function public.is_official()
returns boolean language sql stable security definer set search_path = public as $$
  select public.wds_role() is not null
$$;

-- Staff, the bout's referee, or a judge seated on the bout.
create or replace function public.is_bout_official(p_bout uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_staff()
      or exists (select 1 from public.bouts b where b.id = p_bout and b.referee_id = auth.uid())
      or exists (select 1 from public.bout_judges j where j.bout_id = p_bout and j.judge_id = auth.uid())
$$;

create or replace function public.event_is_public(p_event uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.events e where e.id = p_event and e.status <> 'draft')
$$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- =============================================================================
-- Event lifecycle
-- =============================================================================
create or replace function public.events_before_write()
returns trigger language plpgsql as $$
declare
  base text;
  candidate text;
  n int := 1;
begin
  new.title := trim(new.title);
  new.venue := nullif(trim(coalesce(new.venue, '')), '');
  new.city  := nullif(trim(coalesce(new.city, '')), '');

  -- Stable, unique, URL-safe slug (kept when the title is later edited).
  if new.slug is null or new.slug = '' then
    base := nullif(public.wds_slugify(new.title), '');
    base := coalesce(base, 'event');
    candidate := base;
    while exists (select 1 from public.events where slug = candidate and id <> new.id) loop
      n := n + 1;
      candidate := base || '-' || n;
    end loop;
    new.slug := candidate;
  end if;

  -- Absolute start time in the event's own timezone.
  new.starts_at := case
    when new.event_date is null then null
    else ((new.event_date + coalesce(new.start_time, time '00:00'))::timestamp
          at time zone coalesce(nullif(new.timezone, ''), 'Asia/Kolkata'))
  end;

  -- Announced + full logistics => Scheduled.  Scheduled losing its date => Announced.
  if new.status = 'announced'
     and new.event_date is not null and new.start_time is not null and new.venue is not null then
    new.status := 'scheduled';
  elsif new.status in ('scheduled','live','completed') and new.event_date is null then
    if tg_op = 'UPDATE' and old.status = new.status and new.status = 'scheduled' then
      new.status := 'announced';          -- date was cleared on a scheduled event
    else
      raise exception 'Add the event date before marking "%" as %', new.title, initcap(new.status)
        using errcode = '23514';
    end if;
  end if;

  new.updated_at := now();
  return new;
end $$;

drop trigger if exists events_before_write on public.events;
create trigger events_before_write
  before insert or update on public.events
  for each row execute function public.events_before_write();

-- An event with finalized results is part of the ranking history.
create or replace function public.events_protect_history()
returns trigger language plpgsql as $$
begin
  if exists (select 1 from public.bouts where event_id = old.id and result_status = 'final') then
    raise exception 'Event "%" has finalized results and cannot be deleted. Cancel it or reopen its results first.', old.title
      using errcode = 'P0001';
  end if;
  return old;
end $$;

drop trigger if exists events_protect_history on public.events;
create trigger events_protect_history
  before delete on public.events
  for each row execute function public.events_protect_history();

-- Bouts drive the event to Live / Completed, and bump card_updated_at so the
-- public website (which may only subscribe to events) refreshes the fight card.
create or replace function public.bouts_sync_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  ev uuid := coalesce(new.event_id, old.event_id);
  e  public.events;
  open_bouts int;
  any_live   boolean;
  total      int;
begin
  select * into e from public.events where id = ev for update;
  if not found then
    return null;
  end if;

  select count(*) filter (where status in ('SCHEDULED','LIVE')),
         bool_or(status = 'LIVE'),
         count(*)
    into open_bouts, any_live, total
    from public.bouts where event_id = ev;

  if coalesce(any_live, false) and e.status in ('draft','announced','scheduled') then
    update public.events
       set status = 'live',
           event_date = coalesce(event_date, (now() at time zone timezone)::date),
           card_updated_at = now()
     where id = ev;
  elsif e.status = 'live' and total > 0 and open_bouts = 0 then
    update public.events set status = 'completed', card_updated_at = now() where id = ev;
  else
    update public.events set card_updated_at = now() where id = ev;
  end if;

  -- A bout moved to another event: refresh the old one too.
  if tg_op = 'UPDATE' and old.event_id is distinct from new.event_id then
    update public.events set card_updated_at = now() where id = old.event_id;
  end if;
  return null;
end $$;

drop trigger if exists bouts_sync_event on public.bouts;
create trigger bouts_sync_event
  after insert or update or delete on public.bouts
  for each row execute function public.bouts_sync_event();

-- Keep finalization metadata honest however the row was changed.
create or replace function public.bouts_before_write()
returns trigger language plpgsql as $$
begin
  if new.status <> 'COMPLETED' then
    -- Re-opened / reset bouts carry no result.
    new.result_status := 'none';
  elsif new.result_type is not null and new.result_status = 'none' then
    new.result_status := 'provisional';
  end if;

  if new.result_status = 'final' and (tg_op = 'INSERT' or old.result_status <> 'final') then
    new.finalized_at := coalesce(new.finalized_at, now());
    new.finalized_by := coalesce(new.finalized_by, auth.uid());
  elsif new.result_status <> 'final' then
    new.finalized_at := null;
    new.finalized_by := null;
  end if;

  if new.status = 'COMPLETED' then
    new.round_started_at := null;
    new.completed_at := coalesce(new.completed_at, now());
  end if;

  new.updated_at := now();
  return new;
end $$;

drop trigger if exists bouts_before_write on public.bouts;
create trigger bouts_before_write
  before insert or update on public.bouts
  for each row execute function public.bouts_before_write();

drop trigger if exists fighters_touch on public.fighters;
create trigger fighters_touch before update on public.fighters
  for each row execute function public.touch_updated_at();

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

-- =============================================================================
-- Officials: auth user <-> profile <-> invite
-- =============================================================================

-- New auth user: create their profile. Role/active come ONLY from an invite.
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  inv public.official_invites;
begin
  select * into inv from public.official_invites where email = lower(new.email);
  insert into public.profiles (id, name, email, role, phone, active)
  values (
    new.id,
    coalesce(inv.name, new.raw_user_meta_data ->> 'name', split_part(coalesce(new.email, ''), '@', 1)),
    lower(new.email),
    inv.role,
    inv.phone,
    inv.role is not null
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- Inviting (or re-inviting) someone who already has an account applies the role.
create or replace function public.official_invites_apply()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role = 'ADMIN' and not public.is_admin() and auth.uid() is not null then
    raise exception 'Only an admin can invite another admin' using errcode = '42501';
  end if;
  update public.profiles
     set role = new.role, name = new.name, phone = coalesce(new.phone, phone), active = true
   where lower(email) = new.email;
  return new;
end $$;

drop trigger if exists official_invites_apply on public.official_invites;
create trigger official_invites_apply
  after insert or update on public.official_invites
  for each row execute function public.official_invites_apply();

-- Officials may edit their own name/phone, never their own role or status.
create or replace function public.profiles_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin()
     and (new.role is distinct from old.role or new.active is distinct from old.active) then
    raise exception 'Only an admin can change roles' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists profiles_guard on public.profiles;
create trigger profiles_guard before update on public.profiles
  for each row execute function public.profiles_guard();

-- =============================================================================
-- Public read models for the website (no provisional results, no private data)
-- =============================================================================

-- Fight card. Results appear only once FINAL; until then result_status reads 'pending'.
create or replace view public.public_bout_card
with (security_barrier = true) as
select
  b.id, b.event_id, b.bout_number, b.bout_name, b.discipline, b.bout_type,
  coalesce(nullif(b.weight_class, ''), nullif(bf.weight_class, ''), bfx.weight_class) as weight_class,
  b.total_rounds, b.status,
  b.blue_fighter_id, bfx.name as blue_name, bfx.nickname as blue_nickname, bfx.photo_url as blue_photo_url,
  b.red_fighter_id,  rfx.name as red_name,  rfx.nickname as red_nickname,  rfx.photo_url as red_photo_url,
  case when b.result_status = 'final' then b.result_type  end as result_type,
  case when b.result_status = 'final' then b.winner_id    end as winner_id,
  case when b.result_status = 'final' then b.end_round    end as end_round,
  case when b.result_status = 'final' then b.end_time_sec end as end_time_sec,
  case when b.result_status = 'final' then 'final'
       when b.status = 'COMPLETED'   then 'pending'
       else 'none' end as result_status,
  b.finalized_at
from public.bouts b
join public.events e on e.id = b.event_id and e.status <> 'draft'
left join public.fighters bfx on bfx.id = b.blue_fighter_id
left join public.fighters rfx on rfx.id = b.red_fighter_id
left join public.event_fighters bf on bf.event_id = b.event_id and bf.fighter_id = b.blue_fighter_id;

-- =============================================================================
-- Row Level Security
-- =============================================================================
alter table public.profiles         enable row level security;
alter table public.official_invites enable row level security;
alter table public.events           enable row level security;
alter table public.fighters         enable row level security;
alter table public.fighter_contacts enable row level security;
alter table public.event_fighters   enable row level security;
alter table public.bouts            enable row level security;
alter table public.bout_judges      enable row level security;
alter table public.round_scores     enable row level security;
alter table public.fighter_rankings enable row level security;

-- profiles
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select
  using (id = auth.uid() or public.is_official());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update
  using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());
drop policy if exists profiles_delete on public.profiles;
create policy profiles_delete on public.profiles for delete using (public.is_admin());

-- official_invites (management only)
drop policy if exists invites_all on public.official_invites;
create policy invites_all on public.official_invites for all
  using (public.is_staff()) with check (public.is_staff());

-- events: public sees everything except drafts; management writes; only admins delete
drop policy if exists events_select on public.events;
create policy events_select on public.events for select
  using (status <> 'draft' or public.is_official());
drop policy if exists events_insert on public.events;
create policy events_insert on public.events for insert with check (public.is_staff());
drop policy if exists events_update on public.events;
create policy events_update on public.events for update
  using (public.is_staff()) with check (public.is_staff());
drop policy if exists events_delete on public.events;
create policy events_delete on public.events for delete using (public.is_admin());

-- fighters: public profiles; management writes
drop policy if exists fighters_select on public.fighters;
create policy fighters_select on public.fighters for select using (true);
drop policy if exists fighters_insert on public.fighters;
create policy fighters_insert on public.fighters for insert with check (public.is_staff());
drop policy if exists fighters_update on public.fighters;
create policy fighters_update on public.fighters for update
  using (public.is_staff()) with check (public.is_staff());
drop policy if exists fighters_delete on public.fighters;
create policy fighters_delete on public.fighters for delete using (public.is_admin());

-- fighter_contacts: management only
drop policy if exists contacts_all on public.fighter_contacts;
create policy contacts_all on public.fighter_contacts for all
  using (public.is_staff()) with check (public.is_staff());

-- event_fighters (rosters)
drop policy if exists roster_select on public.event_fighters;
create policy roster_select on public.event_fighters for select
  using (public.is_official() or public.event_is_public(event_id));
drop policy if exists roster_write on public.event_fighters;
create policy roster_write on public.event_fighters for all
  using (public.is_staff()) with check (public.is_staff());

-- bouts: officials read the full row (live state, provisional results);
-- the public reads public_bout_card instead. Management writes directly;
-- referees/judges change bouts only through the scoring RPCs.
drop policy if exists bouts_select on public.bouts;
create policy bouts_select on public.bouts for select using (public.is_official());
drop policy if exists bouts_insert on public.bouts;
create policy bouts_insert on public.bouts for insert with check (public.is_staff());
drop policy if exists bouts_update on public.bouts;
create policy bouts_update on public.bouts for update
  using (public.is_staff()) with check (public.is_staff());
drop policy if exists bouts_delete on public.bouts;
create policy bouts_delete on public.bouts for delete
  using (public.is_staff() and result_status <> 'final');

-- bout_judges
drop policy if exists seats_select on public.bout_judges;
create policy seats_select on public.bout_judges for select using (public.is_official());
drop policy if exists seats_write on public.bout_judges;
create policy seats_write on public.bout_judges for all
  using (public.is_staff()) with check (public.is_staff());

-- round_scores: officials read; nobody writes directly (bout_submit_round only)
drop policy if exists scores_select on public.round_scores;
create policy scores_select on public.round_scores for select using (public.is_official());

-- rankings: public read; written only by recompute_rankings()
drop policy if exists rankings_select on public.fighter_rankings;
create policy rankings_select on public.fighter_rankings for select using (true);

-- =============================================================================
-- Grants (Supabase grants table privileges broadly; RLS above does the gating)
-- =============================================================================
grant usage on schema public to anon, authenticated;
grant select on public.events, public.fighters, public.event_fighters, public.fighter_rankings
  to anon, authenticated;
grant select on public.public_bout_card to anon, authenticated;
grant select, insert, update, delete on
  public.profiles, public.official_invites, public.events, public.fighters, public.fighter_contacts,
  public.event_fighters, public.bouts, public.bout_judges
  to authenticated;
grant select on public.round_scores to authenticated;
revoke insert, update, delete on public.round_scores, public.fighter_rankings from anon, authenticated;
revoke all on public.bouts, public.bout_judges, public.round_scores, public.profiles,
  public.official_invites, public.fighter_contacts from anon;

-- =============================================================================
-- Media storage (fighter photos, league logos uploaded from ScoreHUB).
-- Public read; management writes. Skipped where Supabase Storage is absent.
-- =============================================================================
do $$
begin
  if to_regclass('storage.buckets') is null then
    raise notice 'storage schema not present; skipping media bucket';
    return;
  end if;
  insert into storage.buckets (id, name, public) values ('wds-media', 'wds-media', true)
  on conflict (id) do update set public = true;
  execute 'drop policy if exists wds_media_read on storage.objects';
  execute 'create policy wds_media_read on storage.objects for select using (bucket_id = ''wds-media'')';
  execute 'drop policy if exists wds_media_write on storage.objects';
  execute 'create policy wds_media_write on storage.objects for insert to authenticated with check (bucket_id = ''wds-media'' and public.is_staff())';
  execute 'drop policy if exists wds_media_update on storage.objects';
  execute 'create policy wds_media_update on storage.objects for update to authenticated using (bucket_id = ''wds-media'' and public.is_staff())';
  execute 'drop policy if exists wds_media_delete on storage.objects';
  execute 'create policy wds_media_delete on storage.objects for delete to authenticated using (bucket_id = ''wds-media'' and public.is_staff())';
end $$;
