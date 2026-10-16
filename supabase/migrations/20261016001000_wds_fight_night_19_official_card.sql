-- =============================================================================
-- WDS — 10: Fight Night 19 OFFICIAL fight card (15 bouts) for ScoreHUB
--
-- Source: the official WDS Fight Night 19 bout sheet (management, 16 Oct 2026).
-- Target: event 'wds-fight-night-19' = ScoreHUB league b40c0a64-4e2b-45e0-b9c3-5e0728e47d35.
--
-- Replaces the earlier 16-bout draft card (migration 9) with the official one:
--   * 15 professional MMA bouts, 3 x 5 min, numbered as on the sheet:
--     Bout 1 Rohit Raina vs Laxman Govekar ... Bout 14 co-main, Bout 15 main event.
--   * Blue corner = left column of the sheet, red corner = right column.
--   * Fighters already in the database are reused (matched by any of the names
--     listed for them, oldest record first); nothing already saved is overwritten,
--     missing country / height / record / photo is filled in. New fighters are
--     created with the name exactly as written on the sheet.
--   * Mahdi Saremi, Sohail Khan, Siddiqui Altamash Shahanawaz and Alena Ignateva
--     take the sheet's spelling (they were first added with the website's).
--   * Fighters that existed only for the draft card and are no longer on it
--     (Yoku, Sagyn Kazbek, Arbaaz) are removed if they have no other fights.
--
-- Safety: it stops without changing anything if any Fight Night 19 bout has
-- already started, has scores, or has officials assigned.
-- Safe to re-run: it always rebuilds the same 15-bout card.
-- Run it once in Supabase -> SQL Editor.
-- =============================================================================

do $$
declare
  r record; ev record; a uuid; c uuid; blocked int;
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

  -- Official spellings for fighters first added from the website draft
  -- (only renamed when they have no fights outside Fight Night 19)
  update public.fighters f
     set name = v.official
    from (values ('mehdi saremi', 'Mahdi Saremi'),
                 ('sohail', 'Sohail Khan'),
                 ('altamash siddiqui', 'Siddiqui Altamash Shahanawaz'),
                 ('alena ignatyeva', 'Alena Ignateva')) as v(old_key, official)
   where f.name_key = v.old_key
     and not exists (select 1 from public.fighters o where o.name_key = lower(v.official))
     and not exists (select 1 from public.bouts b
                      where b.event_id <> ev.id
                        and f.id in (b.blue_fighter_id, b.red_fighter_id, b.winner_id));

  -- Clear the draft card and roster
  delete from public.bouts where event_id = ev.id;
  delete from public.event_fighters where event_id = ev.id;

  for r in
    select * from (values
      (1, 'Bantamweight · 61.2 kg', 'Bantamweight', 'Rohit Raina', array['Rohit Raina'], 'India', '0-1-0', '175 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/rohit-raina.webp', 'Laxman Govekar', array['Laxman Govekar'], 'India', '0-1-0', '168 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/laxman-govekar.webp'),
      (2, 'Flyweight · 56.7 kg', 'Flyweight', 'Thiaumuanlal Guite', array['Thiaumuanlal Guite'], 'India', '0-1-0', '168 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/thiaumuanlal-guite.webp', 'Sachin Singh', array['Sachin Singh'], 'India', '0-0-0', '170 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/sachin-singh.webp'),
      (3, 'Flyweight · 56.7 kg', 'Flyweight', 'Sajal Choudhary', array['Sajal Choudhary'], 'India', '1-0-0', '170 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/sajal-choudhary.webp', 'Sagar Dange', array['Sagar Ramdas Dange','Sagar Dange'], 'India', '1-1-0', '173 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/sagar-dange.webp'),
      (4, 'Featherweight · 65.8 kg', 'Featherweight', 'Chhabi (Kapil) Gupta', array['Kapil Gupta','Chhabi (Kapil) Gupta','Chhabi Kapil Gupta','Chhabi Gupta'], 'India', '0-0-0', null, 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/kapil-gupta.webp', 'Shaheen Commando', array['Shaheen Commando'], 'India', '0-0-0', null, 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/shaheen-commando.webp'),
      (5, 'Featherweight · 65.8 kg', 'Featherweight', 'Edukondal', array['Edukondal Rao','Edukondal'], 'India', '5-2-1', '173 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/edukondal-rao.webp', 'Besii Ariijii', array['Besii Ariijii'], 'India', '2-0-0', '175 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/besii-ariijii.webp'),
      (6, 'Welterweight · 77.1 kg', 'Welterweight', 'Kimson Tony', array['Kimson Tony','Kimson'], 'India', '0-0-0', null, 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/kimson.webp', 'Sohail Khan', array['Sohail Khan','Sohail'], 'India', '0-0-0', null, 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/sohail.webp'),
      (7, 'Flyweight · 56.7 kg', 'Flyweight', 'Sangramsingh Godase', array['Sangramsingh Godse','Sangramsingh Godase'], 'India', '2-1-0', '167 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/sangramsingh-godase.webp', 'Siddiqui Altamash Shahanawaz', array['Siddiqui Altamash Shahanawaz','Altamash Shahanawaz Siddiqui','Altamash Siddiqui'], 'India', '2-0-0', '173 cm', null),
      (8, 'Catchweight · 54 kg', 'Catchweight', 'Surbala Laishram', array['Surbala Devi Laishram','Surbala Laishram'], 'India', '2-0-0', '157 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/surbala-laishram.webp', 'Arofat Toirova', array['Arofat Toirova'], 'Uzbekistan', '3-2-0', '166 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/arofat-toirova.webp'),
      (9, 'Catchweight · 50 kg', 'Catchweight', 'Alena Ignateva', array['Alena Ignateva','Alena Ignatyeva'], 'Russia', '2-0-0', '154 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/alena-ignatyeva.webp', 'Bebs Francisco', array['Bebs Francisco'], 'Philippines', '1-0-0', '159 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/bebs-francisco.webp'),
      (10, 'Flyweight · 56.7 kg', 'Flyweight', 'Ashish Rawat', array['Ashish Rawat'], 'India', '3-1-0', '170 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/ashish-rawat.webp', 'Safarov Yoqubjon', array['Safarov Yoqubjon','Yoqubjon Safarov'], null, null, null, null),
      (11, 'Flyweight · 56.7 kg', 'Flyweight', 'Shoaib Khan', array['Shoaib Khan'], 'India', '0-0-0', null, null, 'Colton Kielbasa', array['Colton Kielbasa'], 'USA', '8-6-0', '163 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/colton-kielbasa.webp'),
      (12, 'Flyweight · 56.7 kg', 'Flyweight', 'Bishal Sahu', array['Bishal Sahu'], 'India', '0-0-0', null, 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/bishal-sahu.webp', 'Jake Bron', array['Jake Bron'], null, null, null, null),
      (13, 'Bantamweight · 61.2 kg', 'Bantamweight', 'Ketan Uppadhyay', array['Ketan Uppadhyay','Ketan Upadhyay','Ketan Upadhyaya'], null, null, null, null, 'Dzhafar Nuraliev', array['Dzhafar Nuraliev'], 'Tajikistan', '4-2-0', '170 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/dzhafar-nuraliev.webp'),
      (14, 'Co-Main Event · Welterweight · 77.1 kg', 'Welterweight', 'Benjamin Thomas Holdsworth', array['Ben Holdsworth','Benjamin Thomas Holdsworth','Benjamin Holdsworth'], 'England', '3-1-0', '178 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/ben-holdsworth.webp', 'Pratik Shetty', array['Pratik Shetty'], 'India', '1-1-0', '180 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/pratik-shetty.webp'),
      (15, 'Main Event · Light Heavyweight · 93.0 kg', 'Light Heavyweight', 'Gaganpal Singh Dua', array['Gaganpal Singh Dua','Gaganpal Singh'], 'India', '2-1-0', '167 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/gaganpal-singh.webp', 'Mahdi Saremi', array['Mehdi Saremi','Mahdi Saremi'], 'Iran', '3-1-0', '190 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/mehdi-saremi.webp')
    ) as t(n, bout_name, division,
           blue, blue_match, blue_country, blue_record, blue_height, blue_photo,
           red,  red_match,  red_country,  red_record,  red_height,  red_photo)
    order by n
  loop
    -- Blue corner
    select id into a from public.fighters
     where name_key = any (array(select lower(regexp_replace(trim(x), '\s+', ' ', 'g')) from unnest(r.blue_match) x))
     order by created_at limit 1;
    if a is null then
      insert into public.fighters (name, country, weight_class, height, declared_record, photo_url)
      values (r.blue, r.blue_country, r.division, r.blue_height, r.blue_record, r.blue_photo)
      returning id into a;
    else
      update public.fighters
         set country         = coalesce(country, r.blue_country),
             weight_class    = coalesce(weight_class, r.division),
             height          = coalesce(height, r.blue_height),
             declared_record = coalesce(declared_record, r.blue_record),
             photo_url       = coalesce(photo_url, r.blue_photo)
       where id = a;
    end if;

    -- Red corner
    select id into c from public.fighters
     where name_key = any (array(select lower(regexp_replace(trim(x), '\s+', ' ', 'g')) from unnest(r.red_match) x))
     order by created_at limit 1;
    if c is null then
      insert into public.fighters (name, country, weight_class, height, declared_record, photo_url)
      values (r.red, r.red_country, r.division, r.red_height, r.red_record, r.red_photo)
      returning id into c;
    else
      update public.fighters
         set country         = coalesce(country, r.red_country),
             weight_class    = coalesce(weight_class, r.division),
             height          = coalesce(height, r.red_height),
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
      (ev.id, r.n, r.bout_name, 'PROFESSIONAL', 'MMA', r.division, ev.event_date,
       3, 300, 0, 'SCHEDULED', a, c);
  end loop;

  -- Remove draft-only fighters that are no longer on any card
  delete from public.fighters f
   where f.name_key in ('yoku', 'sagyn kazbek', 'arbaaz')
     and not exists (select 1 from public.bouts b
                      where f.id in (b.blue_fighter_id, b.red_fighter_id, b.winner_id))
     and not exists (select 1 from public.event_fighters ef where ef.fighter_id = f.id);

  update public.events
     set pro_mma_bouts = (select count(*) from public.bouts b
                           where b.event_id = ev.id and b.discipline = 'MMA' and b.bout_type = 'PROFESSIONAL')
   where id = ev.id;

  raise notice 'Fight Night 19 official card: % bouts', (select count(*) from public.bouts where event_id = ev.id);
end $$;

-- Check: the card as ScoreHUB will show it
select b.bout_number, b.bout_name, fb.name as blue_corner, fr.name as red_corner, b.status
  from public.bouts b
  join public.events e on e.id = b.event_id
  left join public.fighters fb on fb.id = b.blue_fighter_id
  left join public.fighters fr on fr.id = b.red_fighter_id
 where e.slug = 'wds-fight-night-19'
 order by b.bout_number;
