-- =============================================================================
-- WDS — 11: Rising Star 8 fight card (9 bouts) for the website and ScoreHUB
--
-- Source: the Rising Star 8 bout sheet from management (22 Oct 2026).
-- Target: event 'wds-rising-star-8' (24–25 Oct 2026, Fit & Fight Club, Wagholi, Pune).
-- One shared database: the website and ScoreHUB both read these bouts.
--
--   * Order: bout 1 = Nikhil Thapa vs Giftson Awungshi (top of the card), then up
--     the sheet bottom-to-top to bout 9 = Nayan Mandlik vs Deekshitha R.
--   * Bouts 1–5 Semi Pro  -> PROFESSIONAL MMA, 3 x 4 min (as Rising Star 7).
--     Bouts 6–9 Finals    -> AMATEUR MMA,     3 x 3 min (as Rising Star 7 finals).
--   * Blue corner = left column of the sheet, red corner = right column.
--   * Fighters already in the database are reused (Nikhil Thapa, Giftson Awungshi,
--     Parth Sapkal, Ayman Shaikh, Sujal Balasaheb Gite, Aryan Sawant, Bhuvan Rai,
--     Nayan Mandlik). Nothing already saved is overwritten; a missing team, weight
--     class, record or photo is filled in. New fighters are created as on the sheet.
--   * 'Bhuvan R' (1026 MMA Academy) is a different fighter from 'Bhuvan Rai'
--     (Fit and Fight Club, who fought at Rising Star 6/7 and Fight Night 14).
--   * The event's "View Fight Card" button opens pages/wds-rising-star-8.html.
--
-- Safety: stops without changing anything if any Rising Star 8 bout has already
-- started, has scores, or has officials assigned. Safe to re-run.
-- Run it once in Supabase -> SQL Editor.
-- =============================================================================

do $$
declare
  r record; ev record; a uuid; c uuid; blocked int;
begin
  select id, event_date into ev from public.events where slug = 'wds-rising-star-8';
  if ev.id is null then
    raise exception 'Event wds-rising-star-8 not found';
  end if;

  select count(*) into blocked
    from public.bouts b
   where b.event_id = ev.id
     and (b.status in ('LIVE','COMPLETED')
          or b.referee_id is not null
          or exists (select 1 from public.round_scores s where s.bout_id = b.id)
          or exists (select 1 from public.bout_judges j where j.bout_id = b.id));
  if blocked > 0 then
    raise exception 'Rising Star 8 already has % bout(s) started, scored or with officials assigned — card not replaced.', blocked;
  end if;

  delete from public.bouts where event_id = ev.id;
  delete from public.event_fighters where event_id = ev.id;

  for r in
    select * from (values
      (1, 'Semi Pro · Flyweight · 56.7 kg', 'Flyweight', 'PROFESSIONAL', 240, 'Nikhil Thapa', array['Nikhil Thapa'], 'Combat Fitness Clan', '14-1-0', null, 'Giftson Awungshi', array['Giftson Awungshi'], 'MAFA (Martial Arts & Fitness)', '7-3-0', null),
      (2, 'Semi Pro · Flyweight · 56.7 kg', 'Flyweight', 'PROFESSIONAL', 240, 'Parth Sapkal', array['Parth Sapkal'], 'Fit and Fight Club', '10-5-1', null, 'Kushal Rao', array['Kushal Rao'], '1026 MMA Academy', '3-3-0', null),
      (3, 'Semi Pro · Strawweight · 52.2 kg', 'Strawweight', 'PROFESSIONAL', 240, 'Atharva Sanjay Katore', array['Atharva Sanjay Katore','Atharva Katore'], 'Paradise Fight Club', '5-1-0', null, 'Pratik Lambade', array['Pratik Lambade'], 'United Sports Academy', '3-3-0', 'https://warriorsdreamseries.com/assets/images/rising-star-8/pratik-lambade.webp'),
      (4, 'Semi Pro · Featherweight · 65.8 kg', 'Featherweight', 'PROFESSIONAL', 240, 'Sujal Bhatt', array['Sujal Bhatt'], 'Fit and Fight Club', '4-3-0', null, 'Stefan Dsouza', array['Stefan Dsouza','Stefan D''souza','Stefan D Souza'], 'Team Viper', '5-5-0', null),
      (5, 'Semi Pro · Bantamweight · 61.2 kg', 'Bantamweight', 'PROFESSIONAL', 240, 'Ayman Shaikh', array['Ayman Shaikh'], 'Fit and Fight Club', '12-6-0', null, 'Sujal Balasaheb Gite', array['Sujal Balasaheb Gite','Sujal Gite'], 'Aridozukata MMA', '5-3-0', null),
      (6, 'Final · Featherweight · 65.8 kg', 'Featherweight', 'AMATEUR', 180, 'Vijay Saini', array['Vijay Saini'], 'Roksh Academy', '7-2-0', null, 'Pratik Maroti Dinde', array['Pratik Maroti Dinde','Pratik Dinde'], 'P Town West MMA', '4-2-0', null),
      (7, 'Final · Bantamweight · 61.2 kg', 'Bantamweight', 'AMATEUR', 180, 'Aryan Sawant', array['Aryan Sawant'], 'P-Town West MMA', '2-2-0', null, 'Bhuvan Rai', array['Bhuvan Rai'], 'Fit and Fight Club', '3-1-0', null),
      (8, 'Final · Flyweight · 56.7 kg', 'Flyweight', 'AMATEUR', 180, 'Vedant Vyawhare', array['Vedant Vyawhare'], 'P-Town', '1-0-0', null, 'Bhuvan R', array['Bhuvan R'], '1026 MMA Academy', '4-2-0', null),
      (9, 'Final · Strawweight · 52.2 kg', 'Strawweight', 'AMATEUR', 180, 'Nayan Mandlik', array['Nayan Mandlik','Nayan Dinesh Mandlik'], 'Fit and Fight Club', '6-2-0', null, 'Deekshitha R', array['Deekshitha R','Deekshitha'], '1026 MMA Academy', '2-0-0', null)
    ) as t(n, bout_name, division, bout_type, round_secs,
           blue, blue_match, blue_team, blue_record, blue_photo,
           red,  red_match,  red_team,  red_record,  red_photo)
    order by n
  loop
    -- Blue corner
    select id into a from public.fighters
     where name_key = any (array(select lower(regexp_replace(trim(x), '\s+', ' ', 'g')) from unnest(r.blue_match) x))
     order by created_at limit 1;
    if a is null then
      insert into public.fighters (name, country, weight_class, team, declared_record, photo_url)
      values (r.blue, 'India', r.division, r.blue_team, r.blue_record, r.blue_photo)
      returning id into a;
    else
      update public.fighters
         set country         = coalesce(country, 'India'),
             weight_class    = coalesce(weight_class, r.division),
             team            = coalesce(team, r.blue_team),
             declared_record = coalesce(declared_record, r.blue_record),
             photo_url       = coalesce(photo_url, r.blue_photo)
       where id = a;
    end if;

    -- Red corner
    select id into c from public.fighters
     where name_key = any (array(select lower(regexp_replace(trim(x), '\s+', ' ', 'g')) from unnest(r.red_match) x))
     order by created_at limit 1;
    if c is null then
      insert into public.fighters (name, country, weight_class, team, declared_record, photo_url)
      values (r.red, 'India', r.division, r.red_team, r.red_record, r.red_photo)
      returning id into c;
    else
      update public.fighters
         set country         = coalesce(country, 'India'),
             weight_class    = coalesce(weight_class, r.division),
             team            = coalesce(team, r.red_team),
             declared_record = coalesce(declared_record, r.red_record),
             photo_url       = coalesce(photo_url, r.red_photo)
       where id = c;
    end if;

    insert into public.event_fighters (event_id, fighter_id, weight_class, declared_record)
    values (ev.id, a, r.division, r.blue_record), (ev.id, c, r.division, r.red_record)
    on conflict do nothing;

    insert into public.bouts
      (event_id, bout_number, bout_name, bout_type, discipline, weight_class, bout_date,
       total_rounds, round_duration, current_round, status, blue_fighter_id, red_fighter_id)
    values
      (ev.id, r.n, r.bout_name, r.bout_type, 'MMA', r.division, ev.event_date,
       3, r.round_secs, 0, 'SCHEDULED', a, c);
  end loop;

  update public.events
     set page_url          = coalesce(page_url, 'pages/wds-rising-star-8.html'),
         pro_mma_bouts     = (select count(*) from public.bouts b where b.event_id = ev.id and b.discipline = 'MMA' and b.bout_type = 'PROFESSIONAL'),
         amateur_mma_bouts = (select count(*) from public.bouts b where b.event_id = ev.id and b.discipline = 'MMA' and b.bout_type = 'AMATEUR')
   where id = ev.id;

  raise notice 'Rising Star 8 card: % bouts', (select count(*) from public.bouts where event_id = ev.id);
end $$;

-- Check: the card as ScoreHUB and the website will show it
select b.bout_number, b.bout_name, b.bout_type, b.total_rounds || ' x ' || (b.round_duration / 60) || ' min' as rounds,
       fb.name as blue_corner, fr.name as red_corner, b.status
  from public.bouts b
  join public.events e on e.id = b.event_id
  left join public.fighters fb on fb.id = b.blue_fighter_id
  left join public.fighters fr on fr.id = b.red_fighter_id
 where e.slug = 'wds-rising-star-8'
 order by b.bout_number;
