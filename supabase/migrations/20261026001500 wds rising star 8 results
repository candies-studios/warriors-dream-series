-- =============================================================================
-- WDS — 15: Rising Star 8 FINAL fight card and RESULTS (committee, 26 Oct 2026)
--
-- 11 bouts, all COMPLETED with FINAL results (shown on the website, counted in
-- rankings, visible in ScoreHUB as finished):
--   1  Main Event     Nikhil Thapa def. Giftson Awungshi
--   2  Co-Main Event  Qaazim Sheikh def. Nikhil Charan (TKO)
--   3-11 follow the committee main-card sheet top to bottom.
-- Amateur MMA + Finals -> AMATEUR 3 x 3 min; Pro MMA -> PROFESSIONAL 3 x 4 min.
-- Blue corner = left column of the sheet, red corner = right column.
--
-- Five wins came without a method (Nikhil Thapa, Bhuvan Rai "via tackle",
-- Chhewang Karma Lama, Md Sajid Khan, Parth Sapkal). They are recorded as
-- unanimous decisions with a note on the bout; correct them later in the admin
-- dashboard (Bouts -> Reopen -> edit -> Finalize) and rankings recalculate.
-- Finish rounds were not given; the ranking formula then uses the round-3 weight.
--
-- Existing fighters are reused (history kept); new ones are created. Safe to
-- re-run. Stops without changes if any Rising Star 8 bout has judges' scores or
-- officials assigned. Run it once in Supabase -> SQL Editor.
-- =============================================================================

do $$
declare
  r record; ev record; a uuid; c uuid; w uuid; blocked int;
begin
  select id, event_date into ev from public.events where slug = 'wds-rising-star-8';
  if ev.id is null then
    raise exception 'Event wds-rising-star-8 not found';
  end if;

  select count(*) into blocked
    from public.bouts b
   where b.event_id = ev.id
     and (b.referee_id is not null
          or exists (select 1 from public.round_scores s where s.bout_id = b.id)
          or exists (select 1 from public.bout_judges j where j.bout_id = b.id));
  if blocked > 0 then
    raise exception 'Rising Star 8 has % bout(s) with scores or officials — not replaced.', blocked;
  end if;

  delete from public.bouts where event_id = ev.id;
  delete from public.event_fighters where event_id = ev.id;

  for r in
    select * from (values
      (1, 'Main Event · Pro MMA · Flyweight · 56.7 kg', 'Flyweight', 'PROFESSIONAL', 240, 'Nikhil Thapa', array['Nikhil Thapa'], 'Combat Fitness Clan', '14-1-0', 'Giftson Awungshi', array['Giftson Awungshi'], 'MAFA (Martial Arts & Fitness Academy)', '7-3-0', 'blue', 'DECISION_UNANIMOUS', 'Winner confirmed by the committee; win method not yet confirmed (recorded as decision).'),
      (2, 'Co-Main Event · Pro MMA · Featherweight · 65.8 kg', 'Featherweight', 'PROFESSIONAL', 240, 'Nikhil Charan', array['Nikhil Charan'], 'Crosstrain Fight Club', '11-5-0', 'Qaazim Sheikh', array['Qaazim Sheikh','Qaazim Shaikh'], 'Combat Fitness Center', '12-2-0', 'red', 'TKO', null),
      (3, 'Amateur MMA · Strawweight · 52.2 kg', 'Strawweight', 'AMATEUR', 180, 'Nayan Mandlik', array['Nayan Mandlik','Nayan Dinesh Mandlik'], 'Fit and Fight Club', '6-2-0', 'Deekshitha R', array['Deekshitha R','Deekshitha'], '1026 MMA Academy', '2-0-0', 'blue', 'DECISION_UNANIMOUS', null),
      (4, 'Amateur MMA · Flyweight · 56.7 kg', 'Flyweight', 'AMATEUR', 180, 'Ahmed Raza', array['Ahmed Raza'], 'Combat Fitness Clan', null, 'Vikas Banubakode', array['Vikas Banubakode'], null, null, 'red', 'SUBMISSION', null),
      (5, 'Amateur MMA · Bantamweight · 61.2 kg', 'Bantamweight', 'AMATEUR', 180, 'Aryan Sawant', array['Aryan Sawant'], 'P-Town West MMA', '2-2-0', 'Bhuvan Rai', array['Bhuvan Rai'], 'Fit and Fight Club', '3-1-0', 'red', 'DECISION_UNANIMOUS', 'Winner confirmed by the committee; win method not yet confirmed (recorded as decision).'),
      (6, 'Final · Flyweight · 56.7 kg', 'Flyweight', 'AMATEUR', 180, 'Vijay Yadav', array['Vijay Yadav'], 'Fit and Fight Club', null, 'Chhewang Karma Lama', array['Chhewang Karma Lama'], 'Fight Elite', null, 'red', 'DECISION_UNANIMOUS', 'Winner confirmed by the committee; win method not yet confirmed (recorded as decision).'),
      (7, 'Final · Featherweight · 65.8 kg', 'Featherweight', 'AMATEUR', 180, 'Md Sajid Khan', array['Md Sajid Khan','Mohammed Sajid Khan','Sajid Khan'], 'RMX Gym Bangalore', null, 'Lanchenba', array['Lanchenba'], 'RMX', null, 'blue', 'DECISION_UNANIMOUS', 'Winner confirmed by the committee; win method not yet confirmed (recorded as decision).'),
      (8, 'Pro MMA · Featherweight · 65.8 kg', 'Featherweight', 'PROFESSIONAL', 240, 'Sadaf Desai', array['Sadaf Desai'], 'MAFA', null, 'Ayman Shaikh', array['Ayman Shaikh'], 'Fit and Fight Club', '12-6-0', 'blue', 'TKO', null),
      (9, 'Pro MMA · Featherweight · 65.8 kg', 'Featherweight', 'PROFESSIONAL', 240, 'Sujal Bhatt', array['Sujal Bhatt'], 'Fit and Fight Club', '4-3-0', 'Stefan Dsouza', array['Stefan Dsouza','Stefan D''souza','Stefan D Souza'], 'Team Viper', '5-5-0', 'blue', 'TKO', null),
      (10, 'Pro MMA · Strawweight · 52.2 kg', 'Strawweight', 'PROFESSIONAL', 240, 'Atharva Sanjay Katore', array['Atharva Sanjay Katore','Atharva Katore'], 'Paradise Fight Club', '5-1-0', 'Pratik Lambade', array['Pratik Lambade'], 'United Sports Academy', '3-3-0', 'blue', 'TKO', null),
      (11, 'Pro MMA · Flyweight · 56.7 kg', 'Flyweight', 'PROFESSIONAL', 240, 'Parth Sapkal', array['Parth Sapkal'], 'Fit and Fight Club', '10-5-1', 'Kushal Rao', array['Kushal Rao'], '1026 MMA Academy', '3-3-0', 'blue', 'DECISION_UNANIMOUS', 'Winner confirmed by the committee; win method not yet confirmed (recorded as decision).')
    ) as t(n, bout_name, division, bout_type, round_secs,
           blue, blue_match, blue_team, blue_record,
           red,  red_match,  red_team,  red_record,
           winner_side, result, note)
    order by n
  loop
    select id into a from public.fighters
     where name_key = any (array(select lower(regexp_replace(trim(x), '\s+', ' ', 'g')) from unnest(r.blue_match) x))
     order by created_at limit 1;
    if a is null then
      insert into public.fighters (name, country, weight_class, team, declared_record)
      values (r.blue, 'India', r.division, r.blue_team, r.blue_record) returning id into a;
    else
      update public.fighters
         set country = coalesce(country, 'India'), weight_class = coalesce(weight_class, r.division),
             team = coalesce(team, r.blue_team), declared_record = coalesce(declared_record, r.blue_record)
       where id = a;
    end if;

    select id into c from public.fighters
     where name_key = any (array(select lower(regexp_replace(trim(x), '\s+', ' ', 'g')) from unnest(r.red_match) x))
     order by created_at limit 1;
    if c is null then
      insert into public.fighters (name, country, weight_class, team, declared_record)
      values (r.red, 'India', r.division, r.red_team, r.red_record) returning id into c;
    else
      update public.fighters
         set country = coalesce(country, 'India'), weight_class = coalesce(weight_class, r.division),
             team = coalesce(team, r.red_team), declared_record = coalesce(declared_record, r.red_record)
       where id = c;
    end if;

    w := case r.winner_side when 'blue' then a else c end;

    insert into public.event_fighters (event_id, fighter_id, weight_class, declared_record)
    values (ev.id, a, r.division, r.blue_record), (ev.id, c, r.division, r.red_record)
    on conflict do nothing;

    insert into public.bouts
      (event_id, bout_number, bout_name, bout_type, discipline, weight_class, bout_date,
       total_rounds, round_duration, current_round, status, blue_fighter_id, red_fighter_id,
       result_type, winner_id, end_round, end_time_sec, result_note, result_status, completed_at)
    values
      (ev.id, r.n, r.bout_name, r.bout_type, 'MMA', r.division, ev.event_date,
       3, r.round_secs, 3, 'COMPLETED', a, c,
       r.result, w, null, null, r.note, 'final', ev.event_date::timestamptz);
  end loop;

  update public.events
     set status            = 'completed',
         page_url          = coalesce(page_url, 'pages/wds-rising-star-8.html'),
         pro_mma_bouts     = (select count(*) from public.bouts b where b.event_id = ev.id and b.bout_type = 'PROFESSIONAL'),
         amateur_mma_bouts = (select count(*) from public.bouts b where b.event_id = ev.id and b.bout_type = 'AMATEUR'),
         card_updated_at   = now()
   where id = ev.id;
end $$;

select public.recompute_rankings();

-- Check: the results as the website and ScoreHUB will show them
select b.bout_number, b.bout_name, fb.name as blue_corner, fr.name as red_corner,
       fw.name as winner, b.result_type, b.result_status, b.result_note
  from public.bouts b
  join public.events e on e.id = b.event_id
  left join public.fighters fb on fb.id = b.blue_fighter_id
  left join public.fighters fr on fr.id = b.red_fighter_id
  left join public.fighters fw on fw.id = b.winner_id
 where e.slug = 'wds-rising-star-8'
 order by b.bout_number;
