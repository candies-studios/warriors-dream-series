-- =============================================================================
-- WDS — 6: real results of the past events
--
-- Source: the official results pages on warriorsdreamseries.com
--   Fight Night 16  https://warriorsdreamseries.com/warriors-dream-series-16
--   Fight Night 17  https://warriorsdreamseries.com/warriors-dream-series-17/
--   Rising Star 7   https://warriorsdreamseries.com/wds-rising-star-7/
--   Fight Night 18  https://warriorsdreamseries.com/wds-fight-night-18
-- (Rising Star 6's page could not be read; its card can be added in the dashboard.)
--
-- What it does
--   1. Removes the 34 placeholder fights of the unlisted "historical import"
--      event (method unknown, opponents "Opponent1…") and that event itself.
--   2. Merges two spellings into one fighter: "Ashok Bagade" → "Ashok Bagde",
--      "Sagar Dange" → "Sagar Ramdas Dange".
--   3. Adds every fight of FN16, FN17, RS7 and FN18 to its own event, with the
--      real method, round and time, as FINAL results. Fighters already in the
--      database are reused (matched by name); missing ones are created.
--   4. Recomputes the rankings with the committee formula.
--
-- Safe to re-run: an event that already has fights is skipped.
-- One fight is imported as PROVISIONAL (not public, not ranked) because the
-- results page contradicts itself: RS7 Sameer Khan vs Vishal Shetty. Confirm the
-- winner in the dashboard (Bouts → edit if needed → Finalize).
-- =============================================================================

-- 1. Remove the placeholder history --------------------------------------------
delete from public.bouts
 where event_id in (select id from public.events where slug = 'historical-results-import');
delete from public.event_fighters
 where event_id in (select id from public.events where slug = 'historical-results-import');
delete from public.events where slug = 'historical-results-import';

-- 2. One identity per fighter ------------------------------------------------------
do $$
declare keep uuid; dup uuid; pair text[];
begin
  foreach pair slice 1 in array array[['Ashok Bagde','Ashok Bagade'], ['Sagar Ramdas Dange','Sagar Dange']] loop
    select id into keep from public.fighters where name_key = lower(pair[1]) order by created_at limit 1;
    select id into dup  from public.fighters where name_key = lower(pair[2]) order by created_at limit 1;
    if dup is null then continue; end if;
    if keep is null then
      update public.fighters set name = pair[1] where id = dup;
      continue;
    end if;
    update public.bouts set blue_fighter_id = keep where blue_fighter_id = dup;
    update public.bouts set red_fighter_id  = keep where red_fighter_id  = dup;
    update public.bouts set winner_id       = keep where winner_id       = dup;
    insert into public.event_fighters (event_id, fighter_id, weight_class, declared_record)
      select event_id, keep, weight_class, declared_record from public.event_fighters where fighter_id = dup
      on conflict do nothing;
    delete from public.fighters where id = dup;
  end loop;

  -- Placeholder opponents from the old Rankings page, now unused.
  delete from public.fighters f
   where f.name ~ '^Opponent(RS7-)?[0-9]+$'
     and not exists (select 1 from public.bouts b
                      where f.id in (b.blue_fighter_id, b.red_fighter_id));
end $$;

-- 3. Fight cards -----------------------------------------------------------------
do $$
declare
  r record;
  ev record;
  a uuid; c uuid; w uuid;
  skip_events text[] := '{}';
begin
  -- Skip events that already have fights (re-run, or entered by hand).
  select coalesce(array_agg(e.slug), '{}') into skip_events
    from public.events e
   where e.slug in ('wds-fight-night-16','wds-fight-night-17','wds-rising-star-7','wds-fight-night-18')
     and exists (select 1 from public.bouts b where b.event_id = e.id);
  if array_length(skip_events, 1) > 0 then
    raise notice 'Already has fights, skipped: %', skip_events;
  end if;

  for r in
    select * from (values
      -- event slug, #, label, type, division, rounds, round secs, blue, red, winner, result, end round, end time (sec), status
      -- ---------------- WDS Fight Night 16 (28 Mar 2026, LPU Jalandhar) ----------------
      ('wds-fight-night-16', 1,'Main Event',        'PROFESSIONAL','Bantamweight',3,300,'Andrey Chelbaev','Ashok Bagde',      'Ashok Bagde',      'RNC',               2,294,'final'),
      ('wds-fight-night-16', 2,'Co-Main Event',     'PROFESSIONAL','Lightweight', 3,300,'Rishabh Patel',  'Gurtej Singh',     'Gurtej Singh',     'CORNER_STOPPAGE',   2,300,'final'),
      ('wds-fight-night-16', 3,'Flyweight',         'PROFESSIONAL','Flyweight',   3,300,'Amit Amauriya',  'Harsh Pandya',     'Harsh Pandya',     'RNC',               2,172,'final'),
      ('wds-fight-night-16', 4,'Bantamweight',      'PROFESSIONAL','Bantamweight',3,300,'Karandeep Singh','Karan Jadhav',     'Karan Jadhav',     'SUBMISSION',        3, 66,'final'),
      ('wds-fight-night-16', 5,'Flyweight',         'PROFESSIONAL','Flyweight',   3,300,'Rehan Rizvi',    'Anubhav Kashyap',  'Anubhav Kashyap',  'TKO',               2, 88,'final'),
      ('wds-fight-night-16', 6,'Welterweight',      'AMATEUR',     'Welterweight',3,300,'M V Sarath Raj', 'Amit Cheeda',      'Amit Cheeda',      'SUBMISSION',        2,157,'final'),
      ('wds-fight-night-16', 7,'Bantamweight',      'AMATEUR',     'Bantamweight',3,300,'Qaazim Sheikh',  'Mohit Dagar',      'Mohit Dagar',      'SUBMISSION',     null,null,'final'),
      ('wds-fight-night-16', 8,'Flyweight',         'AMATEUR',     'Flyweight',   3,300,'Vijay Yadav',    'Mahesh',           'Mahesh',           'SUBMISSION',        3,152,'final'),
      ('wds-fight-night-16', 9,'Flyweight',         'AMATEUR',     'Flyweight',   3,300,'Mano Satya Sai', 'Santosh Yadav',    'Santosh Yadav',    'DECISION_UNANIMOUS',3,300,'final'),
      ('wds-fight-night-16',10,'Featherweight',     'AMATEUR',     'Featherweight',3,300,'Bhim Singh',    'Pruthvi Gulla',    'Pruthvi Gulla',    'DECISION_UNANIMOUS',3,300,'final'),
      ('wds-fight-night-16',11,'Flyweight',         'AMATEUR',     'Flyweight',   3,300,'Anosh',          'Marshal Khimta',   'Marshal Khimta',   'DECISION_UNANIMOUS',3,300,'final'),
      ('wds-fight-night-16',12,'Bantamweight',      'AMATEUR',     'Bantamweight',3,300,'Vishal Magar',   'Manav G V S',      'Manav G V S',      'DECISION_UNANIMOUS',3,300,'final'),
      ('wds-fight-night-16',13,'Featherweight',     'AMATEUR',     'Featherweight',3,300,'Aman Shaikh',   'Vikas Sehrawat',   'Vikas Sehrawat',   'DECISION_UNANIMOUS',3,300,'final'),
      ('wds-fight-night-16',14,'Bantamweight',      'AMATEUR',     'Bantamweight',3,300,'Nitish Kumar',   'Duke',             'Duke',             'TKO',               1, 50,'final'),
      -- ---------------- WDS Fight Night 17 (6 Jun 2026, Mumbai University, Kalina) ----------------
      ('wds-fight-night-17', 1,'Main Event',        'PROFESSIONAL','Welterweight',3,300,'Kimson Tony',    'Ben Holdsworth',   'Ben Holdsworth',   'DECISION_UNANIMOUS',3,300,'final'),
      ('wds-fight-night-17', 2,'Co-Main Event',     'PROFESSIONAL','Bantamweight',3,300,'Rohit Raina',    'Ashok Bagde',      'Ashok Bagde',      'SUBMISSION',        2, 87,'final'),
      ('wds-fight-night-17', 3,'Featherweight',     'PROFESSIONAL','Featherweight',3,300,'Kesavan M',     'Muhiddinov Oyatullo','Muhiddinov Oyatullo','SUBMISSION',    1,286,'final'),
      ('wds-fight-night-17', 4,'Flyweight',         'PROFESSIONAL','Flyweight',   3,300,'Thiaumuanlal Guite','A Shabarish',   'A Shabarish',      'DECISION_UNANIMOUS',3,300,'final'),
      ('wds-fight-night-17', 5,'Featherweight',     'PROFESSIONAL','Featherweight',3,300,'Rajkumar R',    'Raj Singh Baghel', 'Raj Singh Baghel', 'RNC',               1,190,'final'),
      ('wds-fight-night-17', 6,'Flyweight',         'PROFESSIONAL','Flyweight',   3,300,'Sagar Ramdas Dange','Sangramsingh Godse','Sangramsingh Godse','TKO',          2,213,'final'),
      ('wds-fight-night-17', 7,'Lightweight',       'PROFESSIONAL','Lightweight', 3,300,'Karan Chauhan',  'Varun Sanyal',     'Varun Sanyal',     'RNC',               1,264,'final'),
      ('wds-fight-night-17', 8,'Flyweight',         'AMATEUR',     'Flyweight',   3,300,'Chhimey Nurbu Bodh','Nikhil Thapa',  'Nikhil Thapa',     'DECISION_UNANIMOUS',3,300,'final'),
      ('wds-fight-night-17', 9,'Flyweight',         'AMATEUR',     'Flyweight',   3,300,'Nikhil Prajapati','Suryansh Pathak', 'Suryansh Pathak',  'SUBMISSION',        1,100,'final'),
      ('wds-fight-night-17',10,'Light Heavyweight', 'AMATEUR',     'Light Heavyweight',3,300,'Gurjeet Chahal','Syed Imad Uddin','Syed Imad Uddin', 'TKO',               1,113,'final'),
      -- ---------------- WDS Rising Star 7 (25–26 Jul 2026, Fit & Fight Club, Nerul) ----------------
      ('wds-rising-star-7',  1,'Lightweight',       'PROFESSIONAL','Lightweight', 3,240,'Shreenath Barale','Pruthvi Gulla',   'Pruthvi Gulla',    'DECISION_UNANIMOUS',3,240,'final'),
      ('wds-rising-star-7',  2,'Flyweight',         'PROFESSIONAL','Flyweight',   3,240,'Parth Sapkal',   'Shrishti Dethe',   'Shrishti Dethe',   'DECISION_UNANIMOUS',3,240,'final'),
      ('wds-rising-star-7',  3,'Flyweight',         'PROFESSIONAL','Flyweight',   3,240,'Vijay Yadav',    'Bhuvan R',         'Bhuvan R',         'RNC',               2,220,'final'),
      ('wds-rising-star-7',  4,'Bantamweight',      'PROFESSIONAL','Bantamweight',3,240,'Rajkrishna Sharma','Ashish Maurya',  'Ashish Maurya',    'CORNER_STOPPAGE',   3,156,'final'),
      ('wds-rising-star-7',  5,'Middleweight',      'PROFESSIONAL','Middleweight',3,240,'Mittul Rajput',  'Avaneesh Kailash Patil','Avaneesh Kailash Patil','DECISION_UNANIMOUS',3,240,'final'),
      ('wds-rising-star-7',  6,'Strawweight',       'PROFESSIONAL','Strawweight', 3,240,'Ritesh Kanojiya','Narayan Tejbeer Pun','Narayan Tejbeer Pun','DECISION_UNANIMOUS',3,240,'final'),
      ('wds-rising-star-7',  7,'Bantamweight',      'PROFESSIONAL','Bantamweight',3,240,'Sameer Khan',    'Vishal Shetty',    'Vishal Shetty',    'SUBMISSION',        1, 44,'provisional'),
      ('wds-rising-star-7',  8,'Featherweight Final','AMATEUR',    'Featherweight',3,180,'Rishu Tiwari',  'Biru Oli',         'Biru Oli',         'DECISION_SPLIT',    3,180,'final'),
      ('wds-rising-star-7',  9,'Bantamweight Final','AMATEUR',     'Bantamweight',3,180,'Bhupat Rajak',   'Abhijeet Singh Saini','Abhijeet Singh Saini','DECISION_UNANIMOUS',3,180,'final'),
      ('wds-rising-star-7', 10,'Flyweight Final',   'AMATEUR',     'Flyweight',   3,180,'Giftson Awungshi','Tijji Rajak',     'Tijji Rajak',      'DECISION_SPLIT',    3,180,'final'),
      -- ---------------- WDS Fight Night 18 (29 Aug 2026, CIDCO Vashi) ----------------
      ('wds-fight-night-18', 1,'Main Event',        'PROFESSIONAL','Flyweight',   3,300,'Jeko Laishram',  'Kimbert Alintozon','Jeko Laishram',    'DECISION_UNANIMOUS',3,300,'final'),
      ('wds-fight-night-18', 2,'Co-Main Event',     'PROFESSIONAL','Light Heavyweight',3,300,'Tarun M Hiremath','Gaganpal Singh Dua','Gaganpal Singh Dua','TKO',        1,222,'final'),
      ('wds-fight-night-18', 3,'Flyweight',         'PROFESSIONAL','Flyweight',   3,300,'E. Sandigon',    'Bishal Sahu',      'Bishal Sahu',      'TKO',               1,291,'final'),
      ('wds-fight-night-18', 4,'Flyweight',         'PROFESSIONAL','Flyweight',   3,300,'JR Alejandro',   'Shoaib Khan',      'Shoaib Khan',      'TKO',               1,259,'final'),
      ('wds-fight-night-18', 5,'Bantamweight',      'PROFESSIONAL','Bantamweight',3,300,'Ajay Singh Dhoni','Mansur Yakhyaev', 'Mansur Yakhyaev',  'DECISION_SPLIT',    3,300,'final'),
      ('wds-fight-night-18', 6,'Welterweight',      'PROFESSIONAL','Welterweight',3,300,'Daksh Saxena',   'Sharip Omarov',    'Sharip Omarov',    'TKO',               2,213,'final'),
      ('wds-fight-night-18', 7,'Flyweight',         'PROFESSIONAL','Flyweight',   3,300,'Santosh Yadav',  'Sangramsingh Godse','Sangramsingh Godse','KO_HEAD',         1,287,'final'),
      ('wds-fight-night-18', 8,'Flyweight',         'PROFESSIONAL','Flyweight',   3,300,'Nikhil Prajapati','Sagar Ramdas Dange','Sagar Ramdas Dange','TKO',            1,321,'final'),
      ('wds-fight-night-18', 9,'Bantamweight',      'AMATEUR',     'Bantamweight',3,300,'Sidhart Singh Dhami','Ketan Uppadhyay','Ketan Uppadhyay','TKO',               1,268,'final'),
      ('wds-fight-night-18',10,'Featherweight',     'AMATEUR',     'Featherweight',3,300,'Handsome Singh','Kapil Gupta',      'Kapil Gupta',      'RNC',               1,238,'final'),
      ('wds-fight-night-18',11,'Bantamweight',      'AMATEUR',     'Bantamweight',3,300,'Saurabh Negi',   'Mohit Dagar',      'Mohit Dagar',      'DECISION_UNANIMOUS',3,300,'final'),
      ('wds-fight-night-18',12,'Flyweight',         'AMATEUR',     'Flyweight',   3,300,'Alex Sapam',     'Shiva Nayak',      'Shiva Nayak',      'DECISION_MAJORITY', 3,300,'final')
    ) as t(slug, n, label, kind, division, rounds, secs, blue, red, winner, result, end_round, end_sec, rstatus)
    order by slug, n
  loop
    continue when r.slug = any(skip_events);
    select id, event_date into ev from public.events where slug = r.slug;
    if ev.id is null then
      raise notice 'Event % not found, skipped', r.slug;
      continue;
    end if;

    select id into a from public.fighters where name_key = lower(regexp_replace(trim(r.blue), '\s+', ' ', 'g')) order by created_at limit 1;
    if a is null then
      insert into public.fighters (name, weight_class) values (r.blue, r.division) returning id into a;
    end if;
    select id into c from public.fighters where name_key = lower(regexp_replace(trim(r.red), '\s+', ' ', 'g')) order by created_at limit 1;
    if c is null then
      insert into public.fighters (name, weight_class) values (r.red, r.division) returning id into c;
    end if;
    w := case when r.winner = r.blue then a when r.winner = r.red then c end;

    insert into public.event_fighters (event_id, fighter_id, weight_class)
      values (ev.id, a, r.division), (ev.id, c, r.division)
      on conflict do nothing;

    insert into public.bouts
      (event_id, bout_number, bout_name, bout_type, weight_class, bout_date, total_rounds, round_duration,
       current_round, status, blue_fighter_id, red_fighter_id, result_type, winner_id, end_round, end_time_sec,
       result_note, result_status, completed_at)
    values
      (ev.id, r.n, r.label, r.kind, r.division, ev.event_date, r.rounds, r.secs,
       coalesce(r.end_round, r.rounds), 'COMPLETED', a, c, r.result, w, r.end_round, r.end_sec,
       case when r.rstatus = 'provisional'
            then 'Imported from the official results page, which lists both fighters as winner — confirm before finalizing.'
            else 'Imported from the official WDS results page.' end,
       r.rstatus, coalesce(ev.event_date::timestamptz, now()));
  end loop;
end $$;

-- 4. Rankings ----------------------------------------------------------------------
select public.recompute_rankings();
