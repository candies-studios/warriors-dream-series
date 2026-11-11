-- =============================================================================
-- WDS — 25: Fight Night 19 new co-main event (11 Nov 2026)
--
-- * Surbala Laishram vs Arofat Toirova (Catchweight 54 kg) becomes the
--   Co-Main Event: bout 8 -> bout 14, name "Co-Main Event · Catchweight · 54 kg".
-- * Adnan Khan vs Pratik Shetty (Welterweight 77.1 kg) moves to 3rd place:
--   bout 14 -> bout 13, name "Welterweight · 77.1 kg" (no Co-Main label).
-- * Bouts 9-13 each move down one number (9->8 ... 13->12) so the order of
--   the rest of the card stays the same. Bout 15 (Main Event) is untouched.
-- Safety: stops if any of these bouts has started, has scores or officials.
-- Safe to re-run (does nothing once the swap is done).
-- Run it once in Supabase -> SQL Editor.
-- =============================================================================
do $$
declare ev uuid; surbala uuid; adnan uuid; done_already boolean;
begin
  select id into ev from public.events where slug = 'wds-fight-night-19';
  if ev is null then raise exception 'Event wds-fight-night-19 not found'; end if;

  -- Already done? (Surbala's bout is no. 14)
  select exists (
    select 1 from public.bouts b
      join public.fighters f on f.id in (b.blue_fighter_id, b.red_fighter_id)
     where b.event_id = ev and b.bout_number = 14 and f.name_key like '%surbala%laishram%'
  ) into done_already;
  if done_already then raise notice 'Already done - nothing changed.'; return; end if;

  select b.id into surbala from public.bouts b
    join public.fighters f on f.id in (b.blue_fighter_id, b.red_fighter_id)
   where b.event_id = ev and b.bout_number = 8 and f.name_key like '%surbala%laishram%' limit 1;
  if surbala is null then raise exception 'Surbala Laishram bout (no. 8) not found on Fight Night 19'; end if;

  select b.id into adnan from public.bouts b
    join public.fighters f on f.id in (b.blue_fighter_id, b.red_fighter_id)
   where b.event_id = ev and b.bout_number = 14 and f.name_key = 'adnan khan' limit 1;
  if adnan is null then raise exception 'Adnan Khan bout (no. 14) not found on Fight Night 19'; end if;

  if exists (select 1 from public.bouts b
              where b.event_id = ev and b.bout_number between 8 and 14
                and (b.status in ('LIVE','COMPLETED') or b.referee_id is not null
                     or exists (select 1 from public.round_scores s where s.bout_id = b.id)
                     or exists (select 1 from public.bout_judges j where j.bout_id = b.id))) then
    raise exception 'A bout between 8 and 14 has started, has scores or officials — nothing changed.';
  end if;

  -- Move bouts 9-13 down one place (8 is free once Surbala moves up)
  update public.bouts set bout_number = bout_number + 1000
   where event_id = ev and bout_number between 9 and 13;
  update public.bouts set bout_number = bout_number - 1001
   where event_id = ev and bout_number between 1009 and 1013;

  update public.bouts set bout_number = 14, bout_name = 'Co-Main Event · Catchweight · 54 kg'
   where id = surbala;
  update public.bouts set bout_number = 13, bout_name = 'Welterweight · 77.1 kg'
   where id = adnan;
end $$;

-- Check: the whole Fight Night 19 card in order
select b.bout_number, b.bout_name, fb.name as blue_corner, coalesce(fr.name, 'TBA') as red_corner, b.status
  from public.bouts b join public.events e on e.id = b.event_id
  left join public.fighters fb on fb.id = b.blue_fighter_id
  left join public.fighters fr on fr.id = b.red_fighter_id
 where e.slug = 'wds-fight-night-19'
 order by b.bout_number desc;
