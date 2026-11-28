-- =============================================================================
-- WDS — 31: Fight Night 19 — two new bouts + co-main opponent details (28 Nov 2026)
--
-- The card becomes 15 bouts. The two new bouts open the night, so every
-- existing bout moves up by 2 (the main event is now bout 15):
--   15 MAIN EVENT  Gaganpal Singh Dua vs Mahdi Saremi
--   14 CO-MAIN     Surbala Laishram vs Shalinee Solanki   (name corrected from "Shalini Singh")
--   13 .. 3        unchanged order (were 11 .. 1)
--    2  NEW        Nitesh Binha vs Koshish Shrestha       (Lightweight 70.3 kg)
--    1  NEW        Abhishek vs Aryan Adhana               (Welterweight 77.1 kg)
--
-- Fighter details added: photos, pro records and heights for
-- Shalinee Solanki, Nitesh Binha, Abhishek and Aryan Adhana.
--
-- Safety: stops without changing anything if any Fight Night 19 bout has
-- started or has scores. Officials already assigned stay with their bouts.
-- Safe to re-run (it will not add the bouts twice).
-- Run it once in Supabase -> SQL Editor.
-- =============================================================================

do $$
declare
  ev record; blocked int; f uuid; nit uuid; kos uuid; abh uuid; ary uuid;
  img constant text := 'https://wdsmma.com/assets/images/fight-night-19/';
begin
  select id, event_date into ev from public.events where slug = 'wds-fight-night-19';
  if ev.id is null then raise exception 'Event wds-fight-night-19 not found'; end if;

  select count(*) into blocked from public.bouts b
   where b.event_id = ev.id
     and (b.status in ('LIVE','COMPLETED')
          or exists (select 1 from public.round_scores s where s.bout_id = b.id));
  if blocked > 0 then
    raise exception 'Fight Night 19 already has % bout(s) started or scored — nothing changed.', blocked;
  end if;

  -- 1. Co-main opponent: Shalini Singh -> Shalinee Solanki (same fighter, corrected name + details)
  select id into f from public.fighters where name_key = 'shalinee solanki' order by created_at limit 1;
  if f is null then
    select id into f from public.fighters where name_key = 'shalini singh' order by created_at limit 1;
  end if;
  if f is null then
    insert into public.fighters (name, country, weight_class) values ('Shalinee Solanki', 'India', 'Catchweight') returning id into f;
  end if;
  update public.fighters
     set name = 'Shalinee Solanki', country = 'India', declared_record = '4-2-0', height = '171 cm',
         photo_url = img || 'shalinee-solanki.webp'
   where id = f;

  -- 2. Fighters for the new bouts
  select id into nit from public.fighters where name_key = 'nitesh binha' order by created_at limit 1;
  if nit is null then insert into public.fighters (name) values ('Nitesh Binha') returning id into nit; end if;
  update public.fighters set country = 'India', weight_class = coalesce(weight_class, 'Lightweight'),
         declared_record = '1-0-0', height = '180 cm', photo_url = img || 'nitesh-binha.webp' where id = nit;

  select id into kos from public.fighters where name_key = 'koshish shrestha' order by created_at limit 1;
  if kos is null then insert into public.fighters (name, weight_class) values ('Koshish Shrestha', 'Lightweight') returning id into kos; end if;

  -- "Abhishek" is a single name, so only reuse the profile this script created (never another Abhishek)
  select id into abh from public.fighters
   where name_key = 'abhishek' and photo_url = img || 'abhishek.webp' order by created_at limit 1;
  if abh is null then insert into public.fighters (name) values ('Abhishek') returning id into abh; end if;
  update public.fighters set country = 'India', weight_class = coalesce(weight_class, 'Welterweight'),
         declared_record = '0-1-0', height = '173 cm', photo_url = img || 'abhishek.webp' where id = abh;

  select id into ary from public.fighters where name_key = 'aryan adhana' order by created_at limit 1;
  if ary is null then insert into public.fighters (name) values ('Aryan Adhana') returning id into ary; end if;
  update public.fighters set country = 'India', weight_class = coalesce(weight_class, 'Welterweight'),
         declared_record = '0-1-0', height = '170 cm', photo_url = img || 'aryan-adhana.webp' where id = ary;

  -- 3. Add the two bouts (only once)
  if not exists (select 1 from public.bouts where event_id = ev.id and nit in (blue_fighter_id, red_fighter_id)) then
    update public.bouts set bout_number = bout_number + 2 where event_id = ev.id;

    insert into public.bouts
      (event_id, bout_number, bout_name, bout_type, discipline, weight_class, bout_date,
       total_rounds, round_duration, current_round, status, blue_fighter_id, red_fighter_id)
    values
      (ev.id, 1, 'Welterweight · 77.1 kg', 'PROFESSIONAL', 'MMA', 'Welterweight', ev.event_date, 3, 300, 0, 'SCHEDULED', abh, ary),
      (ev.id, 2, 'Lightweight · 70.3 kg',  'PROFESSIONAL', 'MMA', 'Lightweight',  ev.event_date, 3, 300, 0, 'SCHEDULED', nit, kos);
  end if;

  insert into public.event_fighters (event_id, fighter_id, weight_class) values
    (ev.id, abh, 'Welterweight'), (ev.id, ary, 'Welterweight'),
    (ev.id, nit, 'Lightweight'),  (ev.id, kos, 'Lightweight')
  on conflict do nothing;

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
