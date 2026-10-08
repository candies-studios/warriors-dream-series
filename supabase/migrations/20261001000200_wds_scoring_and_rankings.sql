-- =============================================================================
-- WDS unified data platform — 2/3: scoring RPCs, finalization, ranking engine
--
-- ScoreHUB officials never write bouts/round_scores directly; they call these
-- SECURITY DEFINER functions, which check the caller's seat/role, lock the
-- bout row, and apply the same rules as ScoreHUB's src/lib/scoring.ts.
--
-- Result lifecycle on a bout:
--   none  --(last round in / finish recorded in ScoreHUB)-->  provisional
--   provisional --(management: finalize_bout_result / finalize_event_results)--> final
--   final --(admin: reopen_bout_result)--> provisional
-- Rankings are recomputed automatically whenever the set of FINAL results
-- changes, and never look at live or provisional scoring.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Officials list for ScoreHUB's "Who is scoring?" screen (shown before sign-in).
-- -----------------------------------------------------------------------------
drop function if exists public.list_officials();
create or replace function public.list_officials()
returns table (id uuid, name text, role text, login_email text, registered boolean)
language sql stable security definer set search_path = public as $$
  select p.id, p.name, p.role, p.email, true
    from public.profiles p
   where p.active and p.role is not null
  union all
  select null, i.name, i.role, i.email, false
    from public.official_invites i
   where not exists (select 1 from public.profiles p where lower(p.email) = i.email)
   order by 2
$$;

-- -----------------------------------------------------------------------------
-- Decision engine — same rules and wording as the live ScoreHUB build
--   3-0 unanimous · 2-1 split · 2-0+draw majority · even = draw · 1-0+2 draws = majority draw
-- -----------------------------------------------------------------------------
create or replace function public.wds_decide_bout(p_bout uuid)
returns table (result_type text, winner_corner text, summary text)
language plpgsql stable security definer set search_path = public as $$
declare
  blue_cards int; red_cards int; draw_cards int; total int;
  leader text; lead_count int; trail_count int; label text;
  cards text;
begin
  select string_agg(t.blue || '–' || t.red, ', ' order by t.seat) into cards
    from (select j.seat, coalesce(sum(s.blue_score), 0) as blue, coalesce(sum(s.red_score), 0) as red
            from public.bout_judges j
            left join public.round_scores s on s.bout_id = j.bout_id and s.judge_id = j.judge_id and s.submitted
           where j.bout_id = p_bout group by j.seat) t;

  with totals as (
    select j.judge_id,
           coalesce(sum(s.blue_score), 0) as blue,
           coalesce(sum(s.red_score), 0)  as red
      from public.bout_judges j
      left join public.round_scores s
        on s.bout_id = j.bout_id and s.judge_id = j.judge_id and s.submitted
     where j.bout_id = p_bout
     group by j.judge_id
  )
  select count(*) filter (where blue > red),
         count(*) filter (where red > blue),
         count(*) filter (where blue = red),
         count(*)
    into blue_cards, red_cards, draw_cards, total
    from totals;

  leader := case when blue_cards > red_cards then 'BLUE' when red_cards > blue_cards then 'RED' end;
  lead_count  := greatest(blue_cards, red_cards);
  trail_count := least(blue_cards, red_cards);

  if leader is null then
    return query select 'DRAW'::text, null::text,
      case when draw_cards = total then 'Unanimous draw.' else 'Draw.' end;
    return;
  end if;

  if trail_count = 0 and draw_cards = 0 then
    result_type := 'DECISION_UNANIMOUS'; label := 'unanimous decision';
  elsif trail_count > 0 then
    result_type := 'DECISION_SPLIT';     label := 'split decision';
  elsif lead_count > draw_cards then
    result_type := 'DECISION_MAJORITY';  label := 'majority decision';
  else
    return query select 'MAJORITY_DRAW'::text, null::text, 'Majority draw.'::text;
    return;
  end if;

  return query select result_type, leader,
    (case leader when 'BLUE' then 'Blue' else 'Red' end) || ' corner wins by ' || label || ' (' || coalesce(cards, '') || ').';
end $$;

-- -----------------------------------------------------------------------------
-- Live control
-- -----------------------------------------------------------------------------
create or replace function public.bout_start(p_bout uuid)
returns public.bouts language plpgsql security definer set search_path = public as $$
declare b public.bouts;
begin
  if not public.is_bout_official(p_bout) then
    raise exception 'You are not an official on this bout' using errcode = '42501';
  end if;
  select * into b from public.bouts where id = p_bout for update;
  if not found then raise exception 'Bout not found' using errcode = 'P0002'; end if;
  if b.status in ('COMPLETED','CANCELLED') then
    raise exception 'This bout is already complete' using errcode = 'P0001';
  end if;
  update public.bouts
     set status = 'LIVE',
         current_round = greatest(current_round, 1),
         started_at = coalesce(started_at, now())
   where id = p_bout
  returning * into b;
  return b;
end $$;

-- Round clock shared by every tablet. Starting a clock that is already running
-- keeps its original start, so several tablets pressing "Start" agree.
create or replace function public.bout_set_clock(p_bout uuid, p_running boolean)
returns public.bouts language plpgsql security definer set search_path = public as $$
declare b public.bouts;
begin
  b := public.bout_start(p_bout);   -- also validates the caller and the bout
  update public.bouts
     set round_started_at = case when p_running then coalesce(round_started_at, now()) else null end
   where id = p_bout
  returning * into b;
  return b;
end $$;

-- A seated judge turns in their card for the open round.
create or replace function public.bout_submit_round(
  p_bout uuid, p_round int, p_tally jsonb, p_blue int, p_red int
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  b public.bouts;
  seats int;
  done int;
  d record;
begin
  if not exists (select 1 from public.bout_judges where bout_id = p_bout and judge_id = auth.uid()) then
    raise exception 'Only judges seated on this bout can submit a scorecard' using errcode = '42501';
  end if;

  select * into b from public.bouts where id = p_bout for update;
  if not found then raise exception 'Bout not found' using errcode = 'P0002'; end if;
  if b.status in ('COMPLETED','CANCELLED') then
    raise exception 'This bout is already complete' using errcode = 'P0001';
  end if;
  if p_round is null or p_round < 1 or p_round > b.total_rounds then
    raise exception 'Round % does not exist in this bout', p_round using errcode = '22023';
  end if;
  if p_round <> greatest(b.current_round, 1) then
    raise exception 'Round % is not open for scoring (current round is %)', p_round, greatest(b.current_round, 1)
      using errcode = 'P0001';
  end if;
  if p_blue is null or p_red is null or p_blue not between 5 and 10 or p_red not between 5 and 10 then
    raise exception 'Round scores must be between 5 and 10' using errcode = '22023';
  end if;
  if exists (select 1 from public.round_scores
              where bout_id = p_bout and judge_id = auth.uid() and round_number = p_round and submitted) then
    raise exception 'You have already submitted this round' using errcode = '23505';
  end if;

  insert into public.round_scores (bout_id, judge_id, round_number, tally, blue_score, red_score, submitted, submitted_at)
  values (p_bout, auth.uid(), p_round, coalesce(p_tally, '{}'::jsonb), p_blue, p_red, true, now())
  on conflict (bout_id, judge_id, round_number) do update
    set tally = excluded.tally, blue_score = excluded.blue_score, red_score = excluded.red_score,
        submitted = true, submitted_at = now();

  if b.status = 'SCHEDULED' then
    update public.bouts set status = 'LIVE', current_round = greatest(current_round, 1),
                            started_at = coalesce(started_at, now())
     where id = p_bout;
  end if;

  select count(*) into seats from public.bout_judges where bout_id = p_bout;
  select count(distinct s.judge_id) into done
    from public.round_scores s
    join public.bout_judges j on j.bout_id = s.bout_id and j.judge_id = s.judge_id
   where s.bout_id = p_bout and s.round_number = p_round and s.submitted;

  if done < seats then
    return jsonb_build_object('roundComplete', false, 'outcome', null);
  end if;

  -- Every seated judge is in: lock the round.
  if p_round >= b.total_rounds then
    select * into d from public.wds_decide_bout(p_bout);
    update public.bouts
       set status = 'COMPLETED',
           result_type = d.result_type,
           winner_id = case d.winner_corner when 'BLUE' then blue_fighter_id when 'RED' then red_fighter_id end,
           end_round = total_rounds,
           end_time_sec = null,
           result_note = d.summary,
           result_status = 'provisional',
           current_round = total_rounds,
           round_started_at = null,
           completed_at = now()
     where id = p_bout;
    return jsonb_build_object('roundComplete', true, 'outcome', jsonb_build_object('summary', d.summary));
  end if;

  update public.bouts
     set current_round = p_round + 1, round_started_at = null
   where id = p_bout;
  return jsonb_build_object('roundComplete', true, 'outcome', null);
end $$;

-- Early finish recorded at the cage (KO, submission, DQ, no contest…).
create or replace function public.bout_finish(
  p_bout uuid, p_result_type text, p_winner_corner text,
  p_end_round int default null, p_end_time_sec int default null, p_note text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  b public.bouts;
  labels constant jsonb := '{"KO_HEAD":"KO (head)","KO_BODY":"KO (body)","TKO":"TKO","SUBMISSION":"Submission","RNC":"Verbal submission","DOCTOR_STOPPAGE":"Doctor stoppage","CORNER_STOPPAGE":"Corner stoppage","DQ":"Disqualification","NO_CONTEST":"No contest"}';
  corner text := upper(nullif(p_winner_corner, ''));
  rnd int;
  clock text;
  summary text;
begin
  if not public.is_bout_official(p_bout) then
    raise exception 'You are not an official on this bout' using errcode = '42501';
  end if;
  if not labels ? p_result_type then
    raise exception 'Unknown finish type %', p_result_type using errcode = '22023';
  end if;
  if p_result_type <> 'NO_CONTEST' and coalesce(corner, '') not in ('BLUE','RED') then
    raise exception 'Choose the winning corner' using errcode = '22023';
  end if;

  select * into b from public.bouts where id = p_bout for update;
  if not found then raise exception 'Bout not found' using errcode = 'P0002'; end if;
  if b.status in ('COMPLETED','CANCELLED') then
    raise exception 'This bout is already complete' using errcode = 'P0001';
  end if;

  rnd := least(greatest(coalesce(p_end_round, b.current_round, 1), 1), b.total_rounds);
  clock := case when p_end_time_sec is null then ''
                else ' at ' || lpad((p_end_time_sec / 60)::text, 2, '0') || ':' || lpad((p_end_time_sec % 60)::text, 2, '0') end;
  summary := case when p_result_type = 'NO_CONTEST'
                  then 'No contest in round ' || rnd || clock || '.'
                  else (case corner when 'BLUE' then 'Blue' else 'Red' end) || ' corner wins by '
                       || (labels ->> p_result_type) || ' in round ' || rnd || clock || '.' end;

  update public.bouts
     set status = 'COMPLETED',
         result_type = p_result_type,
         winner_id = case corner when 'BLUE' then blue_fighter_id when 'RED' then red_fighter_id end,
         end_round = rnd,
         end_time_sec = p_end_time_sec,
         result_note = coalesce(nullif(trim(p_note), ''), summary),
         result_status = 'provisional',
         started_at = coalesce(started_at, now()),
         round_started_at = null,
         completed_at = now()
   where id = p_bout;

  return jsonb_build_object('summary', summary);
end $$;

-- -----------------------------------------------------------------------------
-- Who is at the cage. Realtime Presence is the fast path; this heartbeat keeps
-- the "waiting for judges" gate working when a venue network blocks or drops
-- websockets. The seat comes from bout_judges, never from the tablet.
-- -----------------------------------------------------------------------------
create table if not exists public.bout_presence (
  bout_id  uuid not null references public.bouts(id) on delete cascade,
  user_id  uuid not null references public.profiles(id) on delete cascade,
  role     text,
  seat     int,
  viewer   boolean not null default false,
  seen_at  timestamptz not null default now(),
  primary key (bout_id, user_id, viewer)
);
comment on table public.bout_presence is 'wds:v1 live heartbeat of officials on a bout';
alter table public.bout_presence enable row level security;
drop policy if exists presence_select on public.bout_presence;
create policy presence_select on public.bout_presence for select using (public.is_official());
revoke all on public.bout_presence from anon;
revoke insert, update, delete on public.bout_presence from authenticated;
grant select on public.bout_presence to authenticated;

create or replace function public.bout_heartbeat(p_bout uuid, p_viewer boolean default false)
returns table (user_id uuid, name text, role text, seat int)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_official() then
    raise exception 'Sign in as an official to join this bout' using errcode = '42501';
  end if;
  insert into public.bout_presence as bp (bout_id, user_id, role, seat, viewer, seen_at)
  values (p_bout, auth.uid(), public.wds_role(),
          case when p_viewer then null
               else (select j.seat from public.bout_judges j where j.bout_id = p_bout and j.judge_id = auth.uid()) end,
          coalesce(p_viewer, false), now())
  on conflict (bout_id, user_id, viewer) do update
    set seen_at = now(), role = excluded.role, seat = excluded.seat;
  delete from public.bout_presence where seen_at < now() - interval '10 minutes';
  return query
    select bp.user_id, p.name, bp.role, bp.seat
      from public.bout_presence bp join public.profiles p on p.id = bp.user_id
     where bp.bout_id = p_bout and not bp.viewer and bp.seen_at > now() - interval '15 seconds';
end $$;

-- -----------------------------------------------------------------------------
-- Management: confirm, reopen, reset
-- -----------------------------------------------------------------------------
create or replace function public.finalize_bout_result(p_bout uuid)
returns public.bouts language plpgsql security definer set search_path = public as $$
declare b public.bouts;
begin
  if not public.is_staff() then
    raise exception 'Only management can finalize results' using errcode = '42501';
  end if;
  select * into b from public.bouts where id = p_bout for update;
  if not found then raise exception 'Bout not found' using errcode = 'P0002'; end if;
  if b.status <> 'COMPLETED' or b.result_type is null then
    raise exception 'Bout % has no result to finalize yet', b.bout_number using errcode = 'P0001';
  end if;
  update public.bouts set result_status = 'final', finalized_at = now(), finalized_by = auth.uid()
   where id = p_bout returning * into b;
  return b;
end $$;

create or replace function public.finalize_event_results(p_event uuid)
returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not public.is_staff() then
    raise exception 'Only management can finalize results' using errcode = '42501';
  end if;
  update public.bouts
     set result_status = 'final', finalized_at = now(), finalized_by = auth.uid()
   where event_id = p_event and status = 'COMPLETED' and result_type is not null
     and result_status = 'provisional';
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function public.reopen_bout_result(p_bout uuid)
returns public.bouts language plpgsql security definer set search_path = public as $$
declare b public.bouts;
begin
  if not public.is_admin() then
    raise exception 'Only an admin can reopen a finalized result' using errcode = '42501';
  end if;
  update public.bouts set result_status = 'provisional'
   where id = p_bout and result_status = 'final' returning * into b;
  if not found then raise exception 'Bout has no finalized result' using errcode = 'P0001'; end if;
  return b;
end $$;

-- Wipe a bout's scoring so it can be run again (e.g. a rehearsal). Admin only.
create or replace function public.reset_bout(p_bout uuid)
returns public.bouts language plpgsql security definer set search_path = public as $$
declare b public.bouts;
begin
  if not public.is_admin() then
    raise exception 'Only an admin can reset a bout' using errcode = '42501';
  end if;
  if exists (select 1 from public.bouts where id = p_bout and result_status = 'final') then
    raise exception 'Reopen the finalized result before resetting this bout' using errcode = 'P0001';
  end if;
  delete from public.round_scores where bout_id = p_bout;
  update public.bouts
     set status = 'SCHEDULED', current_round = 0, round_started_at = null, started_at = null,
         completed_at = null, result_type = null, winner_id = null, end_round = null,
         end_time_sec = null, result_note = null, result_status = 'none'
   where id = p_bout returning * into b;
  return b;
end $$;

-- -----------------------------------------------------------------------------
-- Ranking engine — same ELO as the Rankings page (K = 32, start 1500,
-- ratings rounded after every fight), computed from FINAL results only, in
-- chronological order. A full recompute keeps corrections exact.
-- -----------------------------------------------------------------------------
-- Skipped when migration 4 (committee formula) has already replaced it.
do $wrap$
begin
  if to_regclass('public.ranking_method_weights') is not null then
    raise notice 'recompute_rankings: committee formula already installed (migration 4) - kept';
    return;
  end if;
  execute $fn$
create or replace function public.recompute_rankings()
returns int language plpgsql security definer set search_path = public as $$
declare
  r record;
  ra int; rb int; sa float8; ea float8; eb float8;
  n int;
  seq int := 0;
begin
  -- first_seq = order of first appearance (blue corner before red) — the
  -- Rankings page's tie-break between equal ratings.
  create temp table if not exists _elo (fighter_id uuid primary key, elo int not null, first_seq int not null) on commit drop;
  truncate _elo;

  for r in
    select b.blue_fighter_id as a, b.red_fighter_id as c, b.winner_id
      from public.bouts b
      join public.events e on e.id = b.event_id
     where b.result_status = 'final'
       and b.result_type <> 'NO_CONTEST'
       and b.blue_fighter_id is not null and b.red_fighter_id is not null
     order by coalesce(e.event_date, b.bout_date, b.completed_at::date) nulls last,
              e.starts_at nulls last, e.created_at, b.bout_number, b.completed_at nulls last, b.id
  loop
    insert into _elo values (r.a, 1500, seq + 1), (r.c, 1500, seq + 2) on conflict do nothing;
    seq := seq + 2;
    select elo into ra from _elo where fighter_id = r.a;
    select elo into rb from _elo where fighter_id = r.c;
    sa := case when r.winner_id = r.a then 1 when r.winner_id = r.c then 0 else 0.5 end;
    ea := 1 / (1 + power(10::float8, (rb - ra)::float8 / 400));
    eb := 1 / (1 + power(10::float8, (ra - rb)::float8 / 400));
    -- floor(x + 0.5) == JavaScript Math.round for positive ratings
    update _elo set elo = floor(ra + 32 * (sa - ea) + 0.5)::int       where fighter_id = r.a;
    update _elo set elo = floor(rb + 32 * ((1 - sa) - eb) + 0.5)::int where fighter_id = r.c;
  end loop;

  with fights as (
    select b.id, f.fid,
           case when f.fid = b.blue_fighter_id then b.red_fighter_id else b.blue_fighter_id end as opp,
           b.winner_id, b.result_type,
           coalesce(e.event_date, b.bout_date, b.completed_at::date) as fought_on,
           e.starts_at, e.created_at as ev_created, b.bout_number,
           coalesce(nullif(b.weight_class, ''), nullif(ef.weight_class, ''), nullif(fx.weight_class, '')) as division
      from public.bouts b
      join public.events e on e.id = b.event_id
      cross join lateral (values (b.blue_fighter_id), (b.red_fighter_id)) as f(fid)
      join public.fighters fx on fx.id = f.fid
      left join public.event_fighters ef on ef.event_id = b.event_id and ef.fighter_id = f.fid
     where b.result_status = 'final'
       and b.blue_fighter_id is not null and b.red_fighter_id is not null
  ),
  stats as (
    select fid,
           count(*) filter (where winner_id = fid)                                       as wins,
           count(*) filter (where winner_id is not null and winner_id <> fid)            as losses,
           count(*) filter (where winner_id is null and result_type <> 'NO_CONTEST')     as draws,
           count(*) filter (where result_type = 'NO_CONTEST')                            as ncs,
           max(fought_on)                                                                as last_on,
           (array_agg(division order by fought_on desc nulls last, starts_at desc nulls last,
                                        ev_created desc, bout_number desc)
              filter (where division is not null))[1]                                    as division
      from fights group by fid
  ),
  scored as (
    select s.fid, coalesce(s.division, 'Unclassified') as division_name,
           public.wds_division_key(s.division) as division_key,
           coalesce(x.elo, 1500) as elo, coalesce(x.first_seq, 2147483647) as first_seq, s.wins, s.losses, s.draws, s.ncs, s.last_on, fx.name
      from stats s
      join public.fighters fx on fx.id = s.fid
      left join _elo x on x.fighter_id = s.fid
  ),
  ranked as (
    select *,
      row_number() over (partition by division_key order by elo desc, first_seq, name) as division_rank,
      row_number() over (order by elo desc, first_seq, name)                          as overall_rank
    from scored
  )
  insert into public.fighter_rankings as fr
    (fighter_id, division_key, division_name, elo, wins, losses, draws, no_contests, fights,
     division_rank, overall_rank, last_fight_on, updated_at)
  select fid, division_key, division_name, elo, wins, losses, draws, ncs, wins + losses + draws + ncs,
         division_rank, overall_rank, last_on, now()
    from ranked
  on conflict (fighter_id) do update set
    division_key = excluded.division_key, division_name = excluded.division_name, elo = excluded.elo,
    wins = excluded.wins, losses = excluded.losses, draws = excluded.draws,
    no_contests = excluded.no_contests, fights = excluded.fights,
    division_rank = excluded.division_rank, overall_rank = excluded.overall_rank,
    last_fight_on = excluded.last_fight_on, updated_at = now()
  where (fr.division_key, fr.division_name, fr.elo, fr.wins, fr.losses, fr.draws, fr.no_contests,
         fr.division_rank, fr.overall_rank, fr.last_fight_on)
        is distinct from
        (excluded.division_key, excluded.division_name, excluded.elo, excluded.wins, excluded.losses,
         excluded.draws, excluded.no_contests, excluded.division_rank, excluded.overall_rank,
         excluded.last_fight_on);

  delete from public.fighter_rankings fr
   where not exists (
     select 1 from public.bouts b
      where b.result_status = 'final'
        and b.blue_fighter_id is not null and b.red_fighter_id is not null
        and fr.fighter_id in (b.blue_fighter_id, b.red_fighter_id));

  select count(*) into n from public.fighter_rankings;
  return n;
end $$
  $fn$;
end $wrap$;

-- Management "Recalculate" button (rankings also update automatically).
create or replace function public.admin_recompute_rankings()
returns int language plpgsql security definer set search_path = public as $$
begin
  if not public.is_staff() then
    raise exception 'Only management can recalculate rankings' using errcode = '42501';
  end if;
  return public.recompute_rankings();
end $$;

-- -----------------------------------------------------------------------------
-- Automatic recompute: rows flag the transaction, one recompute per statement.
-- -----------------------------------------------------------------------------
create or replace function public.rankings_mark_dirty()
returns trigger language plpgsql as $$
begin
  perform set_config('wds.rankings_dirty', '1', true);
  return null;
end $$;

create or replace function public.rankings_flush()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if current_setting('wds.rankings_dirty', true) = '1' then
    perform set_config('wds.rankings_dirty', '0', true);
    perform public.recompute_rankings();
  end if;
  return null;
end $$;

-- bouts: any change that touches a FINAL result (becoming final, leaving final,
-- or editing a final row's fighters / winner / method / division / order).
drop trigger if exists bouts_rankings_dirty_ins on public.bouts;
create trigger bouts_rankings_dirty_ins after insert on public.bouts
  for each row when (new.result_status = 'final') execute function public.rankings_mark_dirty();
drop trigger if exists bouts_rankings_dirty_upd on public.bouts;
create trigger bouts_rankings_dirty_upd after update on public.bouts
  for each row when (
    (old.result_status = 'final' or new.result_status = 'final') and (
      old.result_status is distinct from new.result_status
      or old.winner_id is distinct from new.winner_id
      or old.result_type is distinct from new.result_type
      or old.blue_fighter_id is distinct from new.blue_fighter_id
      or old.red_fighter_id is distinct from new.red_fighter_id
      or old.weight_class is distinct from new.weight_class
      or old.bout_number is distinct from new.bout_number
      or old.event_id is distinct from new.event_id))
  execute function public.rankings_mark_dirty();
drop trigger if exists bouts_rankings_dirty_del on public.bouts;
create trigger bouts_rankings_dirty_del after delete on public.bouts
  for each row when (old.result_status = 'final') execute function public.rankings_mark_dirty();
drop trigger if exists bouts_rankings_flush on public.bouts;
create trigger bouts_rankings_flush after insert or update or delete on public.bouts
  for each statement execute function public.rankings_flush();

-- events: date changes reorder history.
drop trigger if exists events_rankings_dirty on public.events;
create trigger events_rankings_dirty after update on public.events
  for each row when (old.event_date is distinct from new.event_date or old.starts_at is distinct from new.starts_at)
  execute function public.rankings_mark_dirty();
drop trigger if exists events_rankings_flush on public.events;
create trigger events_rankings_flush after update on public.events
  for each statement execute function public.rankings_flush();

-- fighters / rosters: division fallbacks.
drop trigger if exists fighters_rankings_dirty on public.fighters;
create trigger fighters_rankings_dirty after update on public.fighters
  for each row when (old.weight_class is distinct from new.weight_class or old.name is distinct from new.name)
  execute function public.rankings_mark_dirty();
drop trigger if exists fighters_rankings_flush on public.fighters;
create trigger fighters_rankings_flush after update on public.fighters
  for each statement execute function public.rankings_flush();
drop trigger if exists roster_rankings_dirty on public.event_fighters;
create trigger roster_rankings_dirty after insert or update or delete on public.event_fighters
  for each row execute function public.rankings_mark_dirty();
drop trigger if exists roster_rankings_flush on public.event_fighters;
create trigger roster_rankings_flush after insert or update or delete on public.event_fighters
  for each statement execute function public.rankings_flush();

-- Public rankings read model.
do $wrap$
begin
  if to_regclass('public.ranking_method_weights') is not null then return; end if;
  execute $v$
create or replace view public.public_rankings as
select fr.fighter_id, f.name, f.nickname, f.photo_url, f.country,
       fr.division_key, fr.division_name, fr.elo, fr.wins, fr.losses, fr.draws, fr.no_contests,
       fr.fights, fr.division_rank, fr.overall_rank, fr.last_fight_on, fr.updated_at
  from public.fighter_rankings fr
  join public.fighters f on f.id = fr.fighter_id
  $v$;
end $wrap$;
grant select on public.public_rankings to anon, authenticated;

-- -----------------------------------------------------------------------------
-- Function privileges: callable by signed-in users (each checks the role
-- itself); internal ones not callable from the API at all.
-- -----------------------------------------------------------------------------
revoke execute on function public.recompute_rankings()            from public, anon, authenticated;
revoke execute on function public.wds_decide_bout(uuid)           from public, anon, authenticated;
revoke execute on function public.rankings_flush()                from public, anon, authenticated;
revoke execute on function public.bout_start(uuid)                from public, anon;
revoke execute on function public.bout_set_clock(uuid, boolean)   from public, anon;
revoke execute on function public.bout_submit_round(uuid, int, jsonb, int, int) from public, anon;
revoke execute on function public.bout_finish(uuid, text, text, int, int, text) from public, anon;
revoke execute on function public.finalize_bout_result(uuid)      from public, anon;
revoke execute on function public.finalize_event_results(uuid)    from public, anon;
revoke execute on function public.reopen_bout_result(uuid)        from public, anon;
revoke execute on function public.reset_bout(uuid)                from public, anon;
revoke execute on function public.admin_recompute_rankings()      from public, anon;
revoke execute on function public.bout_heartbeat(uuid, boolean)   from public, anon;
grant execute on function public.list_officials() to anon, authenticated;
grant execute on function
  public.bout_start(uuid), public.bout_set_clock(uuid, boolean),
  public.bout_submit_round(uuid, int, jsonb, int, int),
  public.bout_finish(uuid, text, text, int, int, text),
  public.finalize_bout_result(uuid), public.finalize_event_results(uuid),
  public.reopen_bout_result(uuid), public.reset_bout(uuid), public.admin_recompute_rankings(),
  public.bout_heartbeat(uuid, boolean)
  to authenticated;

-- -----------------------------------------------------------------------------
-- Realtime: every site subscribes to changes instead of copying data.
-- -----------------------------------------------------------------------------
do $$
declare t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  foreach t in array array['events','bouts','round_scores','bout_judges','event_fighters','fighter_rankings'] loop
    if not exists (select 1 from pg_publication_tables
                    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- One-time bootstrap: make the first management account an admin.
--   Run in the SQL editor:  select public.bootstrap_admin('you@example.com', 'Your Name');
-- (Not callable from the API.)
-- -----------------------------------------------------------------------------
create or replace function public.bootstrap_admin(p_email text, p_name text default null)
returns text language plpgsql security definer set search_path = public as $$
begin
  insert into public.official_invites (email, name, role)
  values (lower(p_email), coalesce(p_name, split_part(p_email, '@', 1)), 'ADMIN')
  on conflict (email) do update set role = 'ADMIN', name = coalesce(p_name, official_invites.name);
  return case when exists (select 1 from public.profiles where lower(email) = lower(p_email))
              then 'Admin role applied to existing account ' || lower(p_email)
              else 'Invite stored: ' || lower(p_email) || ' becomes ADMIN on first sign-up' end;
end $$;
revoke execute on function public.bootstrap_admin(text, text) from public, anon, authenticated;
