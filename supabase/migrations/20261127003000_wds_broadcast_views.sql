-- =============================================================================
-- WDS — 30: Live data for the broadcast screens (27 Nov 2026)
--
-- The broadcast app (wdsmma.com/broadcast/) shows ScoreHUB live on the
-- broadcaster's laptop and in OBS/vMix. It signs in as nobody, so it can only
-- read what these two views publish:
--   * broadcast_bouts         live state of every bout on announced events:
--                             status, round, round clock start, and the result
--                             as soon as ScoreHUB records it (provisional or final)
--   * broadcast_round_scores  each judge's score for a round, once that judge
--                             has submitted it (judge seat + display name only)
-- Nothing else is exposed: no tallies, notes, emails, phones or draft events.
-- Read-only. Run once in Supabase -> SQL Editor. Safe to re-run.
-- =============================================================================

create or replace view public.broadcast_bouts with (security_barrier = true) as
select b.id,
       b.event_id,
       b.bout_number,
       b.status,
       b.current_round,
       b.total_rounds,
       b.round_duration,
       b.round_started_at,
       b.started_at,
       b.completed_at,
       case when b.status = 'COMPLETED' then b.result_type end  as result_type,
       case when b.status = 'COMPLETED' then b.winner_id end    as winner_id,
       case when b.status = 'COMPLETED' then b.end_round end    as end_round,
       case when b.status = 'COMPLETED' then b.end_time_sec end as end_time_sec,
       case when b.status = 'COMPLETED' then coalesce(b.result_status, 'provisional') end as result_status,
       now() as server_now
  from public.bouts b
  join public.events e on e.id = b.event_id
 where e.status <> 'draft';

create or replace view public.broadcast_round_scores with (security_barrier = true) as
select s.bout_id,
       s.round_number,
       j.seat,
       coalesce(nullif(trim(p.name), ''), 'Judge ' || j.seat) as judge_name,
       s.blue_score,
       s.red_score
  from public.round_scores s
  join public.bout_judges j on j.bout_id = s.bout_id and j.judge_id = s.judge_id
  join public.bouts b       on b.id = s.bout_id
  join public.events e      on e.id = b.event_id
  left join public.profiles p on p.id = s.judge_id
 where s.submitted
   and e.status <> 'draft';

grant select on public.broadcast_bouts, public.broadcast_round_scores to anon, authenticated;

-- Check: both views answer (empty is fine before an event starts)
select (select count(*) from public.broadcast_bouts) as bouts,
       (select count(*) from public.broadcast_round_scores) as round_scores;
