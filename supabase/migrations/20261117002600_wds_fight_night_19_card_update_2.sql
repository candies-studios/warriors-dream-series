-- =============================================================================
-- WDS — 26: Fight Night 19 fight card update (management sheet, 17 Nov 2026)
--
-- The card is now 13 bouts (website + ScoreHUB):
--   13 MAIN EVENT  Gaganpal Singh Dua vs Mahdi Saremi        (Light Heavyweight 93.0 kg) — new opponent + photo
--   12 CO-MAIN     Surbala Laishram vs Arofat Toirova          (Catchweight 54 kg)
--   11             Shoaib Khan vs Ibrokhim Shoimov             (Flyweight 56.7 kg) — new opponent + photo
--   10             Bishal Sahu vs Jake Bron                    (Flyweight 56.7 kg)
--    9             Raj Singh Baghel vs Dzhavkharali Nuraliev   (Bantamweight 61.2 kg) — Raj replaces Nongmaithem Bonjovi
--    8             Ashish Rawat vs Safarov Yoqubjon            (Flyweight 56.7 kg)
--    7             Alena Ignateva vs Bebs Francisco            (Catchweight 50 kg)
--    6             Adnan Deshmukh vs Pratik Shetty             (Welterweight 77.1 kg) — name corrected from "Adnan Khan"
--    5             Sangramsingh Godase vs Siddiqui Altamash Shahanawaz (Flyweight 56.7 kg)
--    4             Kimson Tony vs Sohail Khan                  (Welterweight 77.1 kg)
--    3             Chhabi (Kapil) Gupta vs Shaheen Commando    (Featherweight 65.8 kg)
--    2             Thiaumuanlal Guite vs Sachin Singh          (Flyweight 56.7 kg)
--    1             Rohit Raina vs Ajay Sharma                  (Bantamweight 61.2 kg) — Ajay replaces Laxman Govekar
-- Removed: Edukondal vs Besii Ariijii, Sajal Choudhary vs Sagar Dange.
-- Fighter profiles and their records are kept; only this event's card changes.
--
-- Safety: stops without changing anything if any Fight Night 19 bout has
-- already started, has scores, or has officials assigned. Safe to re-run.
-- Run it once in Supabase -> SQL Editor.
-- =============================================================================

do $$
declare
  r record; ev record; a uuid; c uuid; blocked int;
  img constant text := 'https://wdsmma.com/assets/images/fight-night-19/';
begin
  select id, event_date into ev from public.events where slug = 'wds-fight-night-19';
  if ev.id is null then
    raise exception 'Event wds-fight-night-19 not found';
  end if;

  select count(*) into blocked
    from public.bouts b
   where b.event_id = ev.id
     and (b.status in ('LIVE','COMPLETED')
          or b.referee_id is not null
          or exists (select 1 from public.round_scores s where s.bout_id = b.id)
          or exists (select 1 from public.bout_judges j where j.bout_id = b.id));
  if blocked > 0 then
    raise exception 'Fight Night 19 already has % bout(s) started, scored or with officials assigned — card not replaced.', blocked;
  end if;

  -- Name correction: Adnan Khan -> Adnan Deshmukh (same fighter, photo kept)
  update public.fighters set name = 'Adnan Deshmukh', weight_class = 'Welterweight'
   where name_key = 'adnan khan'
     and not exists (select 1 from public.fighters o where o.name_key = 'adnan deshmukh');

  -- New photos
  update public.fighters set photo_url = img || 'mehdi-saremi.webp' where name_key in ('mahdi saremi', 'mehdi saremi');

  -- Clear the card and roster, then insert the new card
  delete from public.bouts where event_id = ev.id;
  delete from public.event_fighters where event_id = ev.id;

  for r in
    select * from (values
      (1,  'Bantamweight · 61.2 kg',                   'Bantamweight',      'Rohit Raina',          array['Rohit Raina'],                                       'India',
                                                                            'Ajay Sharma',          array['Ajay Sharma'],                                       'India',      null::text, null::text, null::text),
      (2,  'Flyweight · 56.7 kg',                      'Flyweight',         'Thiaumuanlal Guite',   array['Thiaumuanlal Guite'],                                'India',
                                                                            'Sachin Singh',         array['Sachin Singh'],                                      'India',      null, null, null),
      (3,  'Featherweight · 65.8 kg',                  'Featherweight',     'Chhabi (Kapil) Gupta', array['Kapil Gupta','Chhabi (Kapil) Gupta','Chhabi Kapil Gupta','Chhabi Gupta'], 'India',
                                                                            'Shaheen Commando',     array['Shaheen Commando'],                                  'India',      null, null, null),
      (4,  'Welterweight · 77.1 kg',                   'Welterweight',      'Kimson Tony',          array['Kimson Tony','Kimson'],                              'India',
                                                                            'Sohail Khan',          array['Sohail Khan','Sohail'],                              'India',      null, null, null),
      (5,  'Flyweight · 56.7 kg',                      'Flyweight',         'Sangramsingh Godase',  array['Sangramsingh Godse','Sangramsingh Godase'],          'India',
                                                                            'Siddiqui Altamash Shahanawaz', array['Siddiqui Altamash Shahanawaz','Altamash Siddiqui'], 'India', null, null, null),
      (6,  'Welterweight · 77.1 kg',                   'Welterweight',      'Adnan Deshmukh',       array['Adnan Deshmukh','Adnan Khan'],                       'India',
                                                                            'Pratik Shetty',        array['Pratik Shetty'],                                     'India',      null, null, null),
      (7,  'Catchweight · 50 kg',                      'Catchweight',       'Alena Ignateva',       array['Alena Ignateva','Alena Ignatyeva'],                  'Russia',
                                                                            'Bebs Francisco',       array['Bebs Francisco'],                                    'Philippines', null, null, null),
      (8,  'Flyweight · 56.7 kg',                      'Flyweight',         'Ashish Rawat',         array['Ashish Rawat'],                                      'India',
                                                                            'Safarov Yoqubjon',     array['Safarov Yoqubjon','Yoqubjon Safarov'],               'Uzbekistan', null, null, null),
      (9,  'Bantamweight · 61.2 kg',                   'Bantamweight',      'Raj Singh Baghel',     array['Raj Singh Baghel'],                                  'India',
                                                                            'Dzhavkharali Nuraliev', array['Dzhavkharali Nuraliev','Dzhafar Nuraliev'],        'Tajikistan', null, null, null),
      (10, 'Flyweight · 56.7 kg',                      'Flyweight',         'Bishal Sahu',          array['Bishal Sahu'],                                       'India',
                                                                            'Jake Bron',            array['Jake Bron'],                                         'Philippines', null, null, null),
      (11, 'Flyweight · 56.7 kg',                      'Flyweight',         'Shoaib Khan',          array['Shoaib Khan'],                                       'India',
                                                                            'Ibrokhim Shoimov',     array['Ibrokhim Shoimov'],                                  'Uzbekistan', '4-2-0', '167 cm', 'ibrokhim-shoimov.webp'),
      (12, 'Co-Main Event · Catchweight · 54 kg',      'Catchweight',       'Surbala Laishram',     array['Surbala Devi Laishram','Surbala Laishram'],          'India',
                                                                            'Arofat Toirova',       array['Arofat Toirova'],                                    'Tajikistan', null, null, null),
      (13, 'Main Event · Light Heavyweight · 93.0 kg', 'Light Heavyweight', 'Gaganpal Singh Dua',   array['Gaganpal Singh Dua','Gaganpal Singh'],               'India',
                                                                            'Mahdi Saremi',         array['Mahdi Saremi','Mehdi Saremi'],                       'Iran',       '3-1-0', '190 cm', 'mehdi-saremi.webp')
    ) as t(n, bout_name, division, blue, blue_match, blue_country, red, red_match, red_country, red_record, red_height, red_photo)
    order by n
  loop
    -- Blue corner
    select id into a from public.fighters
     where name_key = any (array(select lower(regexp_replace(trim(x), '\s+', ' ', 'g')) from unnest(r.blue_match) x))
     order by created_at limit 1;
    if a is null then
      insert into public.fighters (name, country, weight_class)
      values (r.blue, r.blue_country, r.division) returning id into a;
    else
      update public.fighters
         set country = coalesce(country, r.blue_country), weight_class = coalesce(weight_class, r.division)
       where id = a;
    end if;

    -- Red corner
    select id into c from public.fighters
     where name_key = any (array(select lower(regexp_replace(trim(x), '\s+', ' ', 'g')) from unnest(r.red_match) x))
     order by created_at limit 1;
    if c is null then
      insert into public.fighters (name, country, weight_class, height, declared_record, photo_url)
      values (r.red, r.red_country, r.division, r.red_height, r.red_record,
              case when r.red_photo is not null then img || r.red_photo end)
      returning id into c;
    else
      update public.fighters
         set country         = coalesce(country, r.red_country),
             weight_class    = coalesce(weight_class, r.division),
             height          = coalesce(height, r.red_height),
             declared_record = coalesce(declared_record, r.red_record),
             photo_url       = coalesce(photo_url, case when r.red_photo is not null then img || r.red_photo end)
       where id = c;
    end if;

    insert into public.event_fighters (event_id, fighter_id, weight_class)
    values (ev.id, a, r.division) on conflict do nothing;
    insert into public.event_fighters (event_id, fighter_id, weight_class)
    values (ev.id, c, r.division) on conflict do nothing;

    insert into public.bouts
      (event_id, bout_number, bout_name, bout_type, discipline, weight_class, bout_date,
       total_rounds, round_duration, current_round, status, blue_fighter_id, red_fighter_id)
    values
      (ev.id, r.n, r.bout_name, 'PROFESSIONAL', 'MMA', r.division, ev.event_date,
       3, 300, 0, 'SCHEDULED', a, c);
  end loop;

  update public.events
     set pro_mma_bouts = (select count(*) from public.bouts b
                           where b.event_id = ev.id and b.discipline = 'MMA' and b.bout_type = 'PROFESSIONAL')
   where id = ev.id;

  raise notice 'Fight Night 19 card: % bouts', (select count(*) from public.bouts where event_id = ev.id);
end $$;

-- Check: the card as ScoreHUB and the website will show it (main event first)
select b.bout_number, b.bout_name, fb.name as blue_corner, coalesce(fr.name, 'TBA') as red_corner, b.status
  from public.bouts b
  join public.events e on e.id = b.event_id
  left join public.fighters fb on fb.id = b.blue_fighter_id
  left join public.fighters fr on fr.id = b.red_fighter_id
 where e.slug = 'wds-fight-night-19'
 order by b.bout_number desc;
