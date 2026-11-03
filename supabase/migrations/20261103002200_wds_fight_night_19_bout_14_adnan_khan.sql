-- =============================================================================
-- WDS — 22: Fight Night 19 bout 14 (Co-Main Event) change + photos (3 Nov 2026)
--
-- * Bout 14 Co-Main Event, Welterweight 77.1 kg: Adnan Khan replaces
--   Benjamin Thomas Holdsworth in the blue corner (vs Pratik Shetty).
--   Adnan Khan is the existing fighter record (Warrior's Fitness Club).
-- * Photos: Adnan Khan, Siddiqui Altamash Shahanawaz.
-- Only bout 14 is changed; the rest of the card is untouched.
-- Safety: stops if bout 14 has started, has scores or officials. Safe to re-run.
-- Run it once in Supabase -> SQL Editor.
-- =============================================================================
do $$
declare ev uuid; adnan uuid; old_blue uuid; b record;
begin
  select id into ev from public.events where slug = 'wds-fight-night-19';
  if ev is null then raise exception 'Event wds-fight-night-19 not found'; end if;

  select * into b from public.bouts where event_id = ev and bout_number = 14;
  if b.id is null then raise exception 'Fight Night 19 bout 14 not found'; end if;
  if b.status in ('LIVE','COMPLETED') or b.referee_id is not null
     or exists (select 1 from public.round_scores s where s.bout_id = b.id)
     or exists (select 1 from public.bout_judges j where j.bout_id = b.id) then
    raise exception 'Bout 14 has already started, has scores or officials — not changed.';
  end if;

  select id into adnan from public.fighters where name_key = 'adnan khan' order by created_at limit 1;
  if adnan is null then
    insert into public.fighters (name, country, weight_class)
    values ('Adnan Khan', 'India', 'Welterweight') returning id into adnan;
  else
    update public.fighters set country = coalesce(country, 'India') where id = adnan;
  end if;

  old_blue := b.blue_fighter_id;
  update public.bouts set blue_fighter_id = adnan where id = b.id;

  insert into public.event_fighters (event_id, fighter_id, weight_class)
  values (ev, adnan, 'Welterweight') on conflict do nothing;

  -- Take the replaced fighter off this event's roster if he has no other bout on it
  delete from public.event_fighters ef
   where ef.event_id = ev and ef.fighter_id = old_blue and old_blue <> adnan
     and not exists (select 1 from public.bouts x where x.event_id = ev
                      and old_blue in (x.blue_fighter_id, x.red_fighter_id));
end $$;

update public.fighters f
   set photo_url = v.url
  from (values
    ('adnan khan',                   'https://warriorsdreamseries.com/assets/images/fight-night-19/adnan-khan.webp'),
    ('siddiqui altamash shahanawaz', 'https://warriorsdreamseries.com/assets/images/fight-night-19/siddiqui-altamash-shahanawaz.webp')
  ) as v(name_key, url)
 where f.name_key = v.name_key;

-- Check: bout 14 and the two photos
select b.bout_number, b.bout_name, fb.name as blue_corner, fr.name as red_corner, fb.photo_url as blue_photo
  from public.bouts b join public.events e on e.id = b.event_id
  left join public.fighters fb on fb.id = b.blue_fighter_id
  left join public.fighters fr on fr.id = b.red_fighter_id
 where e.slug = 'wds-fight-night-19' and b.bout_number = 14;
select name, photo_url from public.fighters where name_key = 'siddiqui altamash shahanawaz';
