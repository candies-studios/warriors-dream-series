-- =============================================================================
-- WDS — 9: Fight Night 19 fight card (16 bouts) for ScoreHUB
--
-- Source: the Fight Night 19 page on the website
--   https://candies-studios.github.io/warriors-dream-series/pages/wds-fight-night-19.html
-- Target: event 'wds-fight-night-19' (ScoreHUB league b40c0a64-4e2b-45e0-b9c3-5e0728e47d35),
--         12 Dec 2026, CIDCO Exhibition Ground, Vashi.
--
-- What it does
--   * Adds the 16 bouts as SCHEDULED professional MMA bouts, 3 x 5 min rounds.
--     Bouts are numbered in fight order: the opener is Bout 1 and the
--     main event (Gaganpal Singh vs Mehdi Saremi) is Bout 16.
--     Blue corner = the fighter listed on the left on the website.
--   * Reuses fighters already in the database (matched by name, including the
--     spellings below) and only fills in details they are missing — nothing
--     already saved is overwritten. New fighters are created with their
--     country, height, declared pro record and photo from the website.
--   * Puts every fighter on the Fight Night 19 roster with their division and record.
--
-- Name matches used (website name -> name already in the database):
--     Gaganpal Singh      -> Gaganpal Singh Dua
--     Surbala Laishram    -> Surbala Devi Laishram
--     Sangramsingh Godase -> Sangramsingh Godse
--     Sagar Dange         -> Sagar Ramdas Dange
--     Kimson              -> Kimson Tony
--   If any of these is a different person, change the second name in that row
--   to the website name before running, and a new fighter will be created.
--
-- Safe to re-run: a bout number that already exists on this event is skipped.
-- Run it once in Supabase -> SQL Editor.
-- =============================================================================

do $$
declare
  r record; ev record; a uuid; c uuid; added int := 0; skipped int := 0;
begin
  select id, event_date into ev from public.events where slug = 'wds-fight-night-19';
  if ev.id is null then
    raise exception 'Event wds-fight-night-19 not found';
  end if;

  for r in
    select * from (values
      (16, 'Main Event · Light Heavyweight · 93.0 kg', 'Light Heavyweight', 'Gaganpal Singh', 'Gaganpal Singh Dua', 'India', '2-1-0', '167 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/gaganpal-singh.webp', 'Mehdi Saremi', 'Mehdi Saremi', 'Iran', '3-1-0', '190 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/mehdi-saremi.webp'),
      (15, 'Co-Main Event · Welterweight · 77.1 kg', 'Welterweight', 'Ben Holdsworth', 'Ben Holdsworth', 'England', '3-1-0', '178 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/ben-holdsworth.webp', 'Pratik Shetty', 'Pratik Shetty', 'India', '1-1-0', '180 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/pratik-shetty.webp'),
      (14, 'Flyweight · 56.7 kg', 'Flyweight', 'Jeko Laishram', 'Jeko Laishram', 'India', '5-1-1', '163 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/jeko-laishram.webp', 'Dzhafar Nuraliev', 'Dzhafar Nuraliev', 'Tajikistan', '4-2-0', '170 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/dzhafar-nuraliev.webp'),
      (13, 'Flyweight · 56.7 kg', 'Flyweight', 'Bishal Sahu', 'Bishal Sahu', 'India', '0-0-0', null, 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/bishal-sahu.webp', 'Sagyn Kazbek', 'Sagyn Kazbek', null, '0-0-0', null, null),
      (12, 'Flyweight · 56.7 kg', 'Flyweight', 'Shoaib Khan', 'Shoaib Khan', 'India', '0-0-0', null, null, 'Colton Kielbasa', 'Colton Kielbasa', 'USA', '8-6-0', '163 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/colton-kielbasa.webp'),
      (11, 'Flyweight · 56.7 kg', 'Flyweight', 'Ashish Rawat', 'Ashish Rawat', 'India', '3-1-0', '170 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/ashish-rawat.webp', 'Yoku', 'Yoku', 'India', '0-0-0', null, null),
      (10, 'Catchweight · 50 kg', 'Catchweight', 'Alena Ignatyeva', 'Alena Ignatyeva', 'Russia', '2-0-0', '154 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/alena-ignatyeva.webp', 'Bebs Francisco', 'Bebs Francisco', 'Philippines', '1-0-0', '159 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/bebs-francisco.webp'),
      (9, 'Catchweight · 54 kg', 'Catchweight', 'Surbala Laishram', 'Surbala Devi Laishram', 'India', '2-0-0', '157 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/surbala-laishram.webp', 'Arofat Toirova', 'Arofat Toirova', 'Uzbekistan', '3-2-0', '166 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/arofat-toirova.webp'),
      (8, 'Bantamweight · 61.2 kg', 'Bantamweight', 'Ajay Singh Dhoni', 'Ajay Singh Dhoni', 'India', '0-0-0', null, 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/ajay-singh-dhoni.webp', 'Arbaaz', 'Arbaaz', 'India', '0-0-0', null, null),
      (7, 'Flyweight · 56.7 kg', 'Flyweight', 'Sangramsingh Godase', 'Sangramsingh Godse', 'India', '2-1-0', '167 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/sangramsingh-godase.webp', 'Altamash Siddiqui', 'Altamash Siddiqui', 'India', '2-0-0', '173 cm', null),
      (6, 'Welterweight · 77.1 kg', 'Welterweight', 'Kimson', 'Kimson Tony', 'India', '0-0-0', null, 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/kimson.webp', 'Sohail', 'Sohail', 'India', '0-0-0', null, 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/sohail.webp'),
      (5, 'Featherweight · 65.8 kg', 'Featherweight', 'Edukondal Rao', 'Edukondal Rao', 'India', '5-2-1', '173 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/edukondal-rao.webp', 'Besii Ariijii', 'Besii Ariijii', 'India', '2-0-0', '175 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/besii-ariijii.webp'),
      (4, 'Featherweight · 65.8 kg', 'Featherweight', 'Kapil Gupta', 'Kapil Gupta', 'India', '0-0-0', null, 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/kapil-gupta.webp', 'Shaheen Commando', 'Shaheen Commando', 'India', '0-0-0', null, 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/shaheen-commando.webp'),
      (3, 'Flyweight · 56.7 kg', 'Flyweight', 'Sajal Choudhary', 'Sajal Choudhary', 'India', '1-0-0', '170 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/sajal-choudhary.webp', 'Sagar Dange', 'Sagar Ramdas Dange', 'India', '1-1-0', '173 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/sagar-dange.webp'),
      (2, 'Flyweight · 56.7 kg', 'Flyweight', 'Thiaumuanlal Guite', 'Thiaumuanlal Guite', 'India', '0-1-0', '168 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/thiaumuanlal-guite.webp', 'Sachin Singh', 'Sachin Singh', 'India', '0-0-0', '170 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/sachin-singh.webp'),
      (1, 'Bantamweight · 61.2 kg', 'Bantamweight', 'Rohit Raina', 'Rohit Raina', 'India', '0-1-0', '175 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/rohit-raina.webp', 'Laxman Govekar', 'Laxman Govekar', 'India', '0-1-0', '168 cm', 'https://candies-studios.github.io/warriors-dream-series/assets/images/fight-night-19/laxman-govekar.webp')
    ) as t(n, bout_name, division,
           blue, blue_match, blue_country, blue_record, blue_height, blue_photo,
           red,  red_match,  red_country,  red_record,  red_height,  red_photo)
    order by n
  loop
    if exists (select 1 from public.bouts b where b.event_id = ev.id and b.bout_number = r.n) then
      skipped := skipped + 1;
      continue;
    end if;

    -- Blue corner
    select id into a from public.fighters
     where name_key = lower(regexp_replace(trim(r.blue_match), '\s+', ' ', 'g'))
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
     where name_key = lower(regexp_replace(trim(r.red_match), '\s+', ' ', 'g'))
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

    -- Roster
    insert into public.event_fighters (event_id, fighter_id, weight_class, declared_record)
    values (ev.id, a, r.division, r.blue_record), (ev.id, c, r.division, r.red_record)
    on conflict do nothing;

    -- Bout
    insert into public.bouts
      (event_id, bout_number, bout_name, bout_type, discipline, weight_class, bout_date,
       total_rounds, round_duration, current_round, status, blue_fighter_id, red_fighter_id)
    values
      (ev.id, r.n, r.bout_name, 'PROFESSIONAL', 'MMA', r.division, ev.event_date,
       3, 300, 0, 'SCHEDULED', a, c);
    added := added + 1;
  end loop;

  -- Keep the event's bout counter in step with the card.
  update public.events
     set pro_mma_bouts = (select count(*) from public.bouts b
                           where b.event_id = ev.id and b.discipline = 'MMA' and b.bout_type = 'PROFESSIONAL')
   where id = ev.id;

  raise notice 'Fight Night 19: % bouts added, % already there', added, skipped;
end $$;

-- Check: the card as ScoreHUB will show it
select b.bout_number, b.bout_name, fb.name as blue_corner, fr.name as red_corner, b.status
  from public.bouts b
  join public.events e on e.id = b.event_id
  left join public.fighters fb on fb.id = b.blue_fighter_id
  left join public.fighters fr on fr.id = b.red_fighter_id
 where e.slug = 'wds-fight-night-19'
 order by b.bout_number;
