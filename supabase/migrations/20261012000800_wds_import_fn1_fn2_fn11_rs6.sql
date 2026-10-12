-- =============================================================================
-- WDS — 8: Fight Night 1, 2, 11 and Rising Star 6
--
-- Source: fight records supplied by WDS management (screenshots of each card).
-- There was no Fight Night 3. Still to come: Fight Night 15.
--
--   * WDS Fight Night 1 (9 Apr 2022, Nehrul Gymkhana, Mumbai)   6 pro fights
--   * WDS Fight Night 2 (23 Jul 2022, Solaris Sports World, Pune) 6 pro fights
--   * WDS Fight Night 11 (2 Mar 2025, Nerul, Navi Mumbai)        11 fights
--   * WDS Rising Star 6 (25-26 Apr 2026, Fit & Fight Club, Nerul) 11 fights
--
-- FN11 Mrutunjay Madhal vs Pravin Gupta went the distance but the decision type is
-- missing — imported as PROVISIONAL (not public, not ranked) until finalized.
-- Safe to re-run: an event that already has fights is skipped.
-- Run after 20261012000700_wds_import_fight_sheets.sql.
-- =============================================================================

-- 2. One identity per fighter ---------------------------------------------------------
do $$
declare keep uuid; dup uuid; pair text[];
begin
  foreach pair slice 1 in array array[
    ['A Shabarish', 'shabrish ayyanar'],
    ['Aakash Bharti', 'akash bharati'],
    ['Abhijeet Singh Saini', 'abhijit saini'],
    ['Anubhav Kashyap', 'anubhav kumar'],
    ['Arun Bist', 'arun bhist'],
    ['Ashok Bagde', 'ashok bagade'],
    ['Bhumi Kanwar', 'bhumi kunwar'],
    ['Bhuvan Rai', 'bhuvan r'],
    ['Bhuvan Rai', 'bhuwan rai'],
    ['Durga Bishwakarma', 'durga bishwakarma (george smith)'],
    ['Gaganpal Singh Dua', 'gagan pal singh dua'],
    ['Gaganpal Singh Dua', 'gaganpal singh'],
    ['Gaurav Kiran Tate', 'gaurav tate'],
    ['Handsome Singh', 'handsome haobijam'],
    ['Himanshu Madan Bisht', 'himanshu bisht'],
    ['Himanshu Madan Bisht', 'himanshu bist'],
    ['Himanshu Madan Bisht', 'himanshu madan bist'],
    ['Igor Smart', 'igor bonham isambard'],
    ['Igor Smart', 'igor bonham isambard smart'],
    ['Karandeep Singh', 'karandeep singh bajwa'],
    ['Lakhi Das', 'lakhi daas'],
    ['Mrutunjay Madhal', 'mritunjay'],
    ['Mrutunjay Madhal', 'mrutunjay madale'],
    ['Narayan Tejbeer Pun', 'narayan tejbir pun'],
    ['Nayan Mandlik', 'nayan dinesh mandlik'],
    ['Nirjala Badaliya', 'nirjala badaila'],
    ['Nirjala Badaliya', 'nirjala badalia'],
    ['Pranav R S', 'pranav rs'],
    ['Prathamesh Kenjale', 'prathmesh kenjale'],
    ['Purushothaman M K', 'purushothaman munuswamy kumar'],
    ['Qaazim Sheikh', 'abdul qaazim sheikh'],
    ['Sagar Kashyap', 'sagar kahsyap'],
    ['Sagar Ramdas Dange', 'sagar dange'],
    ['Sarvesh Tukaram Chavan', 'sarvesh chavan'],
    ['Satyaprakash Rajbhar', 'satyaa rajbhar'],
    ['Shivaraj Basappa', 'shivaraj b'],
    ['Shrishti Dethe', 'shirish dethe'],
    ['Shrishti Dethe', 'shirishthi'],
    ['Shrishti Dethe', 'shirishthi dethe'],
    ['Siddharth Kothapalli', 'siddarth kothapalli'],
    ['Siddharth Kothapalli', 'siddharth kothappali'],
    ['Swapnil Shinde', 'swapil shinde'],
    ['Tulashidas Ningombam', 'tulashidas meetai'],
    ['Tulashidas Ningombam', 'tulashidas ningbombam'],
    ['Tulashidas Ningombam', 'tulashidas ningobam']] loop
    select id into dup  from public.fighters where name_key = lower(pair[2]) order by created_at limit 1;
    if dup is null then continue; end if;
    select id into keep from public.fighters where name_key = lower(pair[1]) order by created_at limit 1;
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
end $$;

-- 1. Events -----------------------------------------------------------------------------
insert into public.events (slug, title, series, status, event_date, end_date, venue, city, description)
values
  ('wds-fight-night-1', 'WDS Fight Night 1', 'championship', 'completed', '2022-04-09', null, 'Nehrul Gymkhana', 'Mumbai', null),
  ('wds-fight-night-2', 'WDS Fight Night 2', 'championship', 'completed', '2022-07-23', null, 'Solaris Sports World', 'Pune', null),
  ('wds-fight-night-11', 'WDS Fight Night 11', 'championship', 'completed', '2025-03-02', null, 'Nerul', 'Navi Mumbai', null),
  ('wds-rising-star-6', 'WDS Rising Star 6', 'rising-star', 'completed', '2026-04-25', '2026-04-26', 'Fit & Fight Club, Nerul', 'Navi Mumbai', null)
on conflict (slug) do nothing;

-- 2b. Fights -----------------------------------------------------------------------------
do $$
declare
  r record; ev record; a uuid; c uuid; w uuid;
  skip_events text[];
begin
  select coalesce(array_agg(e.slug), '{}') into skip_events
    from public.events e
   where e.slug in ('wds-fight-night-1', 'wds-fight-night-2', 'wds-fight-night-11', 'wds-rising-star-6')
     and exists (select 1 from public.bouts b where b.event_id = e.id);
  if array_length(skip_events, 1) > 0 then
    raise notice 'Already has fights, skipped: %', skip_events;
  end if;

  for r in
    select * from (values
      ('wds-fight-night-1',1,null,'PROFESSIONAL','MMA','Flyweight',300,'Arbaj Shaikh','Arun Bist','Arbaj Shaikh','KO_HEAD',1,243,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: KO (head kick).',null,null,null,null),
      ('wds-fight-night-1',2,null,'PROFESSIONAL','MMA','Bantamweight',300,'Raj Madhesiya','Gopal Badaila','Raj Madhesiya','SUBMISSION',1,86,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Submission (triangle choke).',null,null,null,null),
      ('wds-fight-night-1',3,null,'PROFESSIONAL','MMA','Flyweight',300,'Deepak Bhardwaj','Santosh Bag','Deepak Bhardwaj','DECISION_SPLIT',3,300,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Split decision.',null,null,null,null),
      ('wds-fight-night-1',4,null,'PROFESSIONAL','MMA','Bantamweight',300,'Manjeet Dayal','Vikash Choudhary','Manjeet Dayal','TKO',2,137,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: TKO (punches).',null,null,null,null),
      ('wds-fight-night-1',5,null,'PROFESSIONAL','MMA','Middleweight',300,'Shankar Bhiswas','Omkar Pawar','Shankar Bhiswas','KO_HEAD',1,21,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: KO (punch).',null,null,null,null),
      ('wds-fight-night-1',6,'Main Event','PROFESSIONAL','MMA','Welterweight',300,'Farhan Siddique','Vaibhav Mistry','Farhan Siddique','RNC',1,165,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Submission (rear-naked choke).',null,null,null,null),
      ('wds-fight-night-2',1,null,'PROFESSIONAL','MMA','Lightweight',300,'Sujit Gund','Mazhar Khan','Sujit Gund','TKO',2,214,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: TKO (elbows and punches).',null,null,null,null),
      ('wds-fight-night-2',2,null,'PROFESSIONAL','MMA','Bantamweight',300,'Raj Madhesiya','Anubhav Kashyap','Raj Madhesiya','SUBMISSION',3,86,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Technical submission (arm-triangle choke).',null,null,null,null),
      ('wds-fight-night-2',3,null,'PROFESSIONAL','MMA','Flyweight',300,'Arun Bist','Mohammed Dawood Khan','Arun Bist','SUBMISSION',1,224,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Technical submission (guillotine choke).',null,null,null,null),
      ('wds-fight-night-2',4,null,'PROFESSIONAL','MMA','Flyweight',300,'Sumit Kumar','Arjun Kumar','Sumit Kumar','SUBMISSION',1,95,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Submission (guillotine choke).',null,null,null,null),
      ('wds-fight-night-2',5,null,'PROFESSIONAL','MMA','Featherweight',300,'Paalee Sathishwer','Rahul Sonkamble','Paalee Sathishwer','TKO',1,180,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: TKO (punches).',null,null,null,null),
      ('wds-fight-night-2',6,'Main Event','PROFESSIONAL','MMA','Featherweight',300,'Edukondal Rao','Ravi Saw','Edukondal Rao','SUBMISSION',2,99,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Submission (triangle choke).',null,null,null,null),
      ('wds-fight-night-11',1,null,'AMATEUR','MMA','Flyweight',180,'Nikhil Prajapati','Aniket Patil','Nikhil Prajapati','RNC',1,94,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Submission (rear-naked choke).',null,null,null,null),
      ('wds-fight-night-11',2,null,'AMATEUR','MMA','Flyweight',180,'Rajat Diwedi','Sibankur Chakraborty','Rajat Diwedi','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Unanimous decision.',null,null,null,null),
      ('wds-fight-night-11',3,null,'AMATEUR','MMA','Strawweight',180,'Vikas Gupta','Shaurya Raut','Vikas Gupta','SUBMISSION',1,71,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Submission (armbar).',null,null,null,null),
      ('wds-fight-night-11',4,null,'AMATEUR','MMA','Strawweight',180,'Vidhant Panchal','Marshal Khimta','Vidhant Panchal','SUBMISSION',1,146,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Submission (armbar).',null,null,null,null),
      ('wds-fight-night-11',5,null,'AMATEUR','MMA','Bantamweight',180,'Mrutunjay Madhal','Pravin Gupta','Mrutunjay Madhal','DECISION_UNANIMOUS',3,180,'COMPLETED','provisional','Went the distance (R3 3:00) but the decision type is missing — check and finalize.',null,null,null,null),
      ('wds-fight-night-11',6,null,'AMATEUR','MMA','Strawweight',180,'Vijay Yadav','Aakash Bharti','Vijay Yadav','TKO',2,99,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: TKO.',null,null,null,null),
      ('wds-fight-night-11',7,null,'AMATEUR','MMA','Bantamweight',180,'Igor Smart','Yuvraj Gupta','Igor Smart','TKO',1,24,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: TKO.',null,null,null,null),
      ('wds-fight-night-11',8,null,'AMATEUR','MMA','Featherweight',180,'Shaheen Commando','Devanshu Shukla','Shaheen Commando','TKO',1,116,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: TKO.',null,null,null,null),
      ('wds-fight-night-11',9,null,'AMATEUR','MMA','Bantamweight',180,'Ashok Bagde','Kumud Thakur','Ashok Bagde','RNC',2,62,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Submission (rear-naked choke).',null,null,null,null),
      ('wds-fight-night-11',10,null,'AMATEUR','MMA','Featherweight',180,'Bhim Singh','Sarthik Hegde','Bhim Singh','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Unanimous decision.',null,null,null,null),
      ('wds-fight-night-11',11,'Main Event','AMATEUR','MMA','Flyweight',180,'Harsh Pandya','Dhruv Shirodkar','Harsh Pandya','SUBMISSION',1,117,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Submission.',null,null,null,null),
      ('wds-rising-star-6',1,null,'AMATEUR','MMA','Bantamweight',180,'Aditya Pandey','Arhan Khan','Aditya Pandey','TKO',1,95,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: TKO.',null,null,null,null),
      ('wds-rising-star-6',2,null,'AMATEUR','MMA','Strawweight',180,'Nayan Mandlik','Pushpa','Nayan Mandlik','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Unanimous decision.',null,null,null,null),
      ('wds-rising-star-6',3,null,'AMATEUR','MMA','Catchweight',180,'Praneeth Madasu','Uday','Praneeth Madasu','DECISION_SPLIT',3,180,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Split decision (163 lb catchweight).',null,null,null,null),
      ('wds-rising-star-6',4,null,'AMATEUR','MMA','Lightweight',180,'Prajyot','Surajit Roy','Prajyot','TKO',1,63,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: TKO.',null,null,null,null),
      ('wds-rising-star-6',5,null,'AMATEUR','MMA','Flyweight',180,'Sarvesh Tukaram Chavan','Mohammaed Riyasath Ali','Sarvesh Tukaram Chavan','SUBMISSION',1,112,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Submission (triangle choke).',null,null,null,null),
      ('wds-rising-star-6',6,null,'AMATEUR','MMA','Catchweight',180,'Gurjeet Chahal','Bernardo Dramos Jr.','Gurjeet Chahal','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Unanimous decision (225 lb catchweight).',null,null,null,null),
      ('wds-rising-star-6',7,null,'AMATEUR','MMA','Bantamweight',180,'Ankit Bairwa','G Nitesh Rao','Ankit Bairwa','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Unanimous decision.',null,null,null,null),
      ('wds-rising-star-6',8,null,'AMATEUR','MMA','Strawweight',180,'Narayan Tejbeer Pun','Hamsa Momin','Narayan Tejbeer Pun','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Unanimous decision.',null,null,null,null),
      ('wds-rising-star-6',9,null,'AMATEUR','MMA','Flyweight',180,'Bhuvan Rai','Anurag Ate','Bhuvan Rai','TKO',1,61,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: TKO (submission to strikes).',null,null,null,null),
      ('wds-rising-star-6',10,null,'AMATEUR','MMA','Flyweight',180,'Vikas Gupta','Parth Sapkal','Vikas Gupta','SUBMISSION',2,154,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Submission (triangle choke).',null,null,null,null),
      ('wds-rising-star-6',11,'Main Event','AMATEUR','MMA','Bantamweight',180,'Sagar Ramdas Dange','Evansraj Jagateesan','Sagar Ramdas Dange','RNC',2,154,'COMPLETED','final','Imported from the official fight record supplied by WDS management. Method: Submission (rear-naked choke).',null,null,null,null)
    ) as t(slug, n, label, kind, disc, division, secs, blue, red, winner, result, end_round, end_sec, bstatus, rstatus, note,
           blue_team, blue_city, red_team, red_city)
    order by slug, n
  loop
    continue when r.slug = any(skip_events);
    select id, event_date into ev from public.events where slug = r.slug;
    if ev.id is null then raise notice 'Event % not found', r.slug; continue; end if;

    select id into a from public.fighters where name_key = lower(regexp_replace(trim(r.blue), '\s+', ' ', 'g')) order by created_at limit 1;
    if a is null then
      insert into public.fighters (name, weight_class, team, hometown) values (r.blue, r.division, r.blue_team, r.blue_city) returning id into a;
    else
      update public.fighters set team = coalesce(team, r.blue_team), hometown = coalesce(hometown, r.blue_city),
                                 weight_class = coalesce(weight_class, r.division)
       where id = a and (team is null or hometown is null or weight_class is null);
    end if;
    select id into c from public.fighters where name_key = lower(regexp_replace(trim(r.red), '\s+', ' ', 'g')) order by created_at limit 1;
    if c is null then
      insert into public.fighters (name, weight_class, team, hometown) values (r.red, r.division, r.red_team, r.red_city) returning id into c;
    else
      update public.fighters set team = coalesce(team, r.red_team), hometown = coalesce(hometown, r.red_city),
                                 weight_class = coalesce(weight_class, r.division)
       where id = c and (team is null or hometown is null or weight_class is null);
    end if;
    w := case when r.winner = r.blue then a when r.winner = r.red then c end;

    insert into public.event_fighters (event_id, fighter_id, weight_class)
      values (ev.id, a, r.division), (ev.id, c, r.division)
      on conflict do nothing;

    insert into public.bouts
      (event_id, bout_number, bout_name, bout_type, discipline, weight_class, bout_date, total_rounds, round_duration,
       current_round, status, blue_fighter_id, red_fighter_id, result_type, winner_id, end_round, end_time_sec,
       result_note, result_status, completed_at)
    values
      (ev.id, r.n, coalesce(r.label, r.division), r.kind, r.disc, r.division, ev.event_date, 3, r.secs,
       coalesce(r.end_round, case when r.bstatus = 'COMPLETED' then 3 else 0 end), r.bstatus, a, c, r.result, w, r.end_round, r.end_sec,
       r.note, r.rstatus, case when r.bstatus = 'COMPLETED' then ev.event_date::timestamptz end);
  end loop;
end $$;

-- 3. Rankings ---------------------------------------------------------------------------
select public.recompute_rankings();
