-- =============================================================================
-- WDS unified data platform — 4/4: committee ranking formula (October 2026)
--
--   Score = (Win% × 0.7 + Win Method Weight × 0.3) × √(total fights)
--
--   Win%               wins ÷ (wins + losses + draws) × 100
--   Win Method Weight  SUM of the weights of every win (table below)
--   total fights       wins + losses + draws   (no contests are not counted)
--
-- Committee example: 10 bouts, 6 wins / 3 losses / 1 draw, win weights
-- totalling 4.05  ->  (60 × 0.7 + 4.05 × 0.3) × √10 = 136.6578291
--
-- Only FINALIZED results count, exactly as before. Fighters are ranked by
-- Score (highest first) within their division. The weights live in a table
-- that management can edit from the admin dashboard; every edit recalculates
-- the rankings. Run after migrations 1–3. Safe to re-run.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Win method weights
--    round_no 1..3 = the round the fight ended in (round 4/5 finishes use the
--    round-3 weight); round_no 0 = any round (decisions).
--    confirmed = true  -> taken from the committee sheet
--    confirmed = false -> assumption for a method the sheet does not list;
--                         shown as "to confirm" in the dashboard.
-- -----------------------------------------------------------------------------
create table if not exists public.ranking_method_weights (
  result_type text    not null,
  round_no    int     not null default 0 check (round_no between 0 and 3),
  weight      numeric(6,4) not null check (weight >= 0 and weight <= 10),
  confirmed   boolean not null default false,
  note        text,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references public.profiles(id) on delete set null,
  primary key (result_type, round_no),
  constraint ranking_weights_known_type check (result_type in (
    'DECISION_UNANIMOUS','DECISION_SPLIT','DECISION_MAJORITY',
    'KO_HEAD','KO_BODY','TKO','DOCTOR_STOPPAGE','CORNER_STOPPAGE',
    'SUBMISSION','RNC','DQ'))
);
comment on table public.ranking_method_weights is 'wds:v1 committee win-method weights for the ranking score';

insert into public.ranking_method_weights (result_type, round_no, weight, confirmed, note) values
  -- Knockout / TKO / Referee stoppage (committee)
  ('KO_HEAD', 1, 0.75, true,  'Committee: KO/TKO/referee stoppage R1'),
  ('KO_HEAD', 2, 0.70, true,  'Committee: KO/TKO/referee stoppage R2'),
  ('KO_HEAD', 3, 0.65, true,  'Committee: KO/TKO/referee stoppage R3'),
  ('KO_BODY', 1, 0.75, true,  'Committee: KO/TKO/referee stoppage R1'),
  ('KO_BODY', 2, 0.70, true,  'Committee: KO/TKO/referee stoppage R2'),
  ('KO_BODY', 3, 0.65, true,  'Committee: KO/TKO/referee stoppage R3'),
  ('TKO',     1, 0.75, true,  'Committee: KO/TKO/referee stoppage R1'),
  ('TKO',     2, 0.70, true,  'Committee: KO/TKO/referee stoppage R2'),
  ('TKO',     3, 0.65, true,  'Committee: KO/TKO/referee stoppage R3'),
  -- Submission (committee); verbal submission is a submission
  ('SUBMISSION', 1, 0.70, true, 'Committee: submission R1'),
  ('SUBMISSION', 2, 0.65, true, 'Committee: submission R2'),
  ('SUBMISSION', 3, 0.60, true, 'Committee: submission R3'),
  ('RNC',        1, 0.70, true, 'Verbal submission = submission R1'),
  ('RNC',        2, 0.65, true, 'Verbal submission = submission R2'),
  ('RNC',        3, 0.60, true, 'Verbal submission = submission R3'),
  -- Unanimous decision (committee)
  ('DECISION_UNANIMOUS', 0, 0.55, true, 'Committee: unanimous decision'),
  -- Not on the committee sheet — assumptions until confirmed
  ('DOCTOR_STOPPAGE', 1, 0.75, false, 'Assumed: treated as a stoppage (KO/TKO table)'),
  ('DOCTOR_STOPPAGE', 2, 0.70, false, 'Assumed: treated as a stoppage (KO/TKO table)'),
  ('DOCTOR_STOPPAGE', 3, 0.65, false, 'Assumed: treated as a stoppage (KO/TKO table)'),
  ('CORNER_STOPPAGE', 1, 0.75, false, 'Assumed: treated as a stoppage (KO/TKO table)'),
  ('CORNER_STOPPAGE', 2, 0.70, false, 'Assumed: treated as a stoppage (KO/TKO table)'),
  ('CORNER_STOPPAGE', 3, 0.65, false, 'Assumed: treated as a stoppage (KO/TKO table)'),
  ('DECISION_SPLIT',    0, 0.55, false, 'Assumed: same as unanimous decision'),
  ('DECISION_MAJORITY', 0, 0.55, false, 'Assumed: same as unanimous decision'),
  ('DQ',                0, 0.55, false, 'Assumed: same as unanimous decision')
on conflict (result_type, round_no) do nothing;

-- Weight of one win. Finishes after round 3 use the round-3 weight; a missing
-- round uses round 3; a method with no weight row adds 0.
create or replace function public.wds_win_weight(p_result_type text, p_end_round int)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(
    (select weight from public.ranking_method_weights
      where result_type = p_result_type
        and round_no = least(greatest(coalesce(p_end_round, 3), 1), 3)),
    (select weight from public.ranking_method_weights
      where result_type = p_result_type and round_no = 0),
    0)
$$;

-- -----------------------------------------------------------------------------
-- 2. Rankings table: score and its parts
-- -----------------------------------------------------------------------------
alter table public.fighter_rankings add column if not exists score         numeric(12,4) not null default 0;
alter table public.fighter_rankings add column if not exists win_pct       numeric(7,3)  not null default 0;
alter table public.fighter_rankings add column if not exists method_points numeric(10,4) not null default 0;
alter table public.fighter_rankings alter column elo drop not null;
create index if not exists fighter_rankings_score_idx on public.fighter_rankings(division_key, score desc);

-- -----------------------------------------------------------------------------
-- 3. Ranking engine (committee formula). ELO is still stored for reference
--    but no longer decides the order.
-- -----------------------------------------------------------------------------
create or replace function public.recompute_rankings()
returns int language plpgsql security definer set search_path = public as $$
declare
  r record;
  ra int; rb int; sa float8; ea float8; eb float8;
  n int;
  seq int := 0;
begin
  -- first_seq = order in which a fighter first appears (blue corner before
  -- red), used to break exact score ties consistently.
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
    update _elo set elo = floor(ra + 32 * (sa - ea) + 0.5)::int       where fighter_id = r.a;
    update _elo set elo = floor(rb + 32 * ((1 - sa) - eb) + 0.5)::int where fighter_id = r.c;
  end loop;

  with fights as (
    select b.id, f.fid,
           b.winner_id, b.result_type, b.end_round,
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
           coalesce(sum(public.wds_win_weight(result_type, end_round)) filter (where winner_id = fid), 0) as method_points,
           max(fought_on)                                                                as last_on,
           (array_agg(division order by fought_on desc nulls last, starts_at desc nulls last,
                                        ev_created desc, bout_number desc)
              filter (where division is not null))[1]                                    as division
      from fights group by fid
  ),
  scored as (
    select s.fid, coalesce(s.division, 'Unclassified') as division_name,
           public.wds_division_key(s.division) as division_key,
           x.elo, coalesce(x.first_seq, 2147483647) as first_seq,
           s.wins, s.losses, s.draws, s.ncs, s.last_on, s.method_points, fx.name,
           (s.wins + s.losses + s.draws) as counted,
           case when s.wins + s.losses + s.draws = 0 then 0
                else 100.0 * s.wins / (s.wins + s.losses + s.draws) end as win_pct
      from stats s
      join public.fighters fx on fx.id = s.fid
      left join _elo x on x.fighter_id = s.fid
  ),
  with_score as (
    select *, ((win_pct::float8 * 0.7 + method_points::float8 * 0.3) * sqrt(counted::float8)) as score
      from scored
  ),
  ranked as (
    select *,
      row_number() over (partition by division_key order by score desc, wins desc, first_seq, name) as division_rank,
      row_number() over (order by score desc, wins desc, first_seq, name)                          as overall_rank
    from with_score
  )
  insert into public.fighter_rankings as fr
    (fighter_id, division_key, division_name, elo, wins, losses, draws, no_contests, fights,
     division_rank, overall_rank, last_fight_on, score, win_pct, method_points, updated_at)
  select fid, division_key, division_name, elo, wins, losses, draws, ncs, wins + losses + draws + ncs,
         division_rank, overall_rank, last_on, round(score::numeric, 4), round(win_pct::numeric, 3),
         method_points, now()
    from ranked
  on conflict (fighter_id) do update set
    division_key = excluded.division_key, division_name = excluded.division_name, elo = excluded.elo,
    wins = excluded.wins, losses = excluded.losses, draws = excluded.draws,
    no_contests = excluded.no_contests, fights = excluded.fights,
    division_rank = excluded.division_rank, overall_rank = excluded.overall_rank,
    last_fight_on = excluded.last_fight_on, score = excluded.score, win_pct = excluded.win_pct,
    method_points = excluded.method_points, updated_at = now()
  where (fr.division_key, fr.division_name, fr.elo, fr.wins, fr.losses, fr.draws, fr.no_contests,
         fr.division_rank, fr.overall_rank, fr.last_fight_on, fr.score, fr.win_pct, fr.method_points)
        is distinct from
        (excluded.division_key, excluded.division_name, excluded.elo, excluded.wins, excluded.losses,
         excluded.draws, excluded.no_contests, excluded.division_rank, excluded.overall_rank,
         excluded.last_fight_on, excluded.score, excluded.win_pct, excluded.method_points);

  delete from public.fighter_rankings fr
   where not exists (
     select 1 from public.bouts b
      where b.result_status = 'final'
        and b.blue_fighter_id is not null and b.red_fighter_id is not null
        and fr.fighter_id in (b.blue_fighter_id, b.red_fighter_id));

  select count(*) into n from public.fighter_rankings;
  return n;
end $$;
revoke execute on function public.recompute_rankings() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. Recalculate automatically when anything the formula uses changes
-- -----------------------------------------------------------------------------
-- The finishing round now matters too.
drop trigger if exists bouts_rankings_dirty_upd on public.bouts;
create trigger bouts_rankings_dirty_upd after update on public.bouts
  for each row when (
    (old.result_status = 'final' or new.result_status = 'final') and (
      old.result_status is distinct from new.result_status
      or old.winner_id is distinct from new.winner_id
      or old.result_type is distinct from new.result_type
      or old.end_round is distinct from new.end_round
      or old.blue_fighter_id is distinct from new.blue_fighter_id
      or old.red_fighter_id is distinct from new.red_fighter_id
      or old.weight_class is distinct from new.weight_class
      or old.bout_number is distinct from new.bout_number
      or old.event_id is distinct from new.event_id))
  execute function public.rankings_mark_dirty();

create or replace function public.ranking_weights_touch()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  return new;
end $$;
drop trigger if exists ranking_weights_touch on public.ranking_method_weights;
create trigger ranking_weights_touch before insert or update on public.ranking_method_weights
  for each row execute function public.ranking_weights_touch();
drop trigger if exists ranking_weights_dirty on public.ranking_method_weights;
create trigger ranking_weights_dirty after insert or update or delete on public.ranking_method_weights
  for each row execute function public.rankings_mark_dirty();
drop trigger if exists ranking_weights_flush on public.ranking_method_weights;
create trigger ranking_weights_flush after insert or update or delete on public.ranking_method_weights
  for each statement execute function public.rankings_flush();

-- -----------------------------------------------------------------------------
-- 5. Access: the weights are public (transparency); management edits them.
-- -----------------------------------------------------------------------------
alter table public.ranking_method_weights enable row level security;
drop policy if exists weights_select on public.ranking_method_weights;
create policy weights_select on public.ranking_method_weights for select using (true);
drop policy if exists weights_write on public.ranking_method_weights;
create policy weights_write on public.ranking_method_weights for all
  using (public.is_staff()) with check (public.is_staff());
grant select on public.ranking_method_weights to anon, authenticated;
grant insert, update, delete on public.ranking_method_weights to authenticated;
revoke insert, update, delete on public.ranking_method_weights from anon;

-- Public read model now carries the score and its parts (new columns at the end).
create or replace view public.public_rankings as
select fr.fighter_id, f.name, f.nickname, f.photo_url, f.country,
       fr.division_key, fr.division_name, fr.elo, fr.wins, fr.losses, fr.draws, fr.no_contests,
       fr.fights, fr.division_rank, fr.overall_rank, fr.last_fight_on, fr.updated_at,
       fr.score, fr.win_pct, fr.method_points
  from public.fighter_rankings fr
  join public.fighters f on f.id = fr.fighter_id;
grant select on public.public_rankings to anon, authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ranking_method_weights') then
    alter publication supabase_realtime add table public.ranking_method_weights;
  end if;
end $$;

select public.recompute_rankings();
