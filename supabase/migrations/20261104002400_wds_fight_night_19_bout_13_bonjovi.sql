-- =============================================================================
-- WDS — 24: Fight Night 19 bout 13 change (4 Nov 2026)
--
-- * Bout 13, Bantamweight 61.2 kg: Nongmaithem Bonjovi "Rockstar" replaces
--   Ketan Uppadhyay in the blue corner (vs Dzhavkharali Nuraliev).
--   Record 4-3-0, last fight loss, India, 5'4" (163 cm), photo.
-- Only bout 13 is changed. Stops if bout 13 has started, has scores or officials.
-- Safe to re-run. Run it once in Supabase -> SQL Editor.
-- =============================================================================
do $$
declare ev uuid; f uuid; old_blue uuid; b record;
begin
  select id into ev from public.events where slug = 'wds-fight-night-19';
  if ev is null then raise exception 'Event wds-fight-night-19 not found'; end if;

  select * into b from public.bouts where event_id = ev and bout_number = 13;
  if b.id is null then raise exception 'Fight Night 19 bout 13 not found'; end if;
  if b.status in ('LIVE','COMPLETED') or b.referee_id is not null
     or exists (select 1 from public.round_scores s where s.bout_id = b.id)
     or exists (select 1 from public.bout_judges j where j.bout_id = b.id) then
    raise exception 'Bout 13 has already started, has scores or officials — not changed.';
  end if;

  select id into f from public.fighters
   where name_key in ('nongmaithem bonjovi', 'bonjovi nongmaithem') order by created_at limit 1;
  if f is null then
    insert into public.fighters (name, nickname, country, weight_class, height, declared_record, photo_url)
    values ('Nongmaithem Bonjovi', 'Rockstar', 'India', 'Bantamweight', '163 cm', '4-3-0',
            'https://wdsmma.com/assets/images/fight-night-19/nongmaithem-bonjovi.webp')
    returning id into f;
  else
    update public.fighters
       set nickname = 'Rockstar', country = 'India', height = '163 cm', declared_record = '4-3-0',
           weight_class = coalesce(weight_class, 'Bantamweight'),
           photo_url = 'https://wdsmma.com/assets/images/fight-night-19/nongmaithem-bonjovi.webp'
     where id = f;
  end if;

  old_blue := b.blue_fighter_id;
  update public.bouts set blue_fighter_id = f where id = b.id;

  insert into public.event_fighters (event_id, fighter_id, weight_class, declared_record)
  values (ev, f, 'Bantamweight', '4-3-0') on conflict do nothing;

  delete from public.event_fighters ef
   where ef.event_id = ev and ef.fighter_id = old_blue and old_blue <> f
     and not exists (select 1 from public.bouts x where x.event_id = ev
                      and old_blue in (x.blue_fighter_id, x.red_fighter_id));
end $$;

-- Check: bout 13
select b.bout_number, b.bout_name, fb.name as blue_corner, fb.nickname, fr.name as red_corner, fb.photo_url
  from public.bouts b join public.events e on e.id = b.event_id
  left join public.fighters fb on fb.id = b.blue_fighter_id
  left join public.fighters fr on fr.id = b.red_fighter_id
 where e.slug = 'wds-fight-night-19' and b.bout_number = 13;
