-- WDS website — read-only export of the PUBLIC data (the same data any visitor's
-- browser already reads). It changes nothing in the database.
select json_build_object(
  'exported_at', now(),
  'events',      (select coalesce(json_agg(e order by e.event_date desc nulls first), '[]') from public.events e where e.status <> 'draft'),
  'bout_card',   (select coalesce(json_agg(c order by c.event_id, c.bout_number), '[]') from public.public_bout_card c),
  'bout_points', (select coalesce(json_agg(p), '[]') from public.public_bout_points p),
  'last_fights', (select coalesce(json_agg(l), '[]') from public.public_last_fights l),
  'rankings',    (select coalesce(json_agg(r), '[]') from public.public_rankings r),
  'fighters',    (select coalesce(json_agg(f), '[]') from public.fighters f
                   where exists (select 1 from public.public_bout_card c where f.id in (c.blue_fighter_id, c.red_fighter_id)))
) as wds_export;
