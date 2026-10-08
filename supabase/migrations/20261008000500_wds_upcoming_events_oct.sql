-- =============================================================================
-- WDS unified data platform — 5: upcoming events as published on 5 Oct 2026
--
-- * events.page_url      optional custom page for an event (e.g. the
--                        hand-built Fight Night 19 fight card). Used for
--                        "View Fight Card" links instead of pages/event.html.
-- * events.series_label  optional label shown instead of the series name
--                        (e.g. "Warriors Dream Series").
-- * Rising Star 8 and Fight Night 19 details, matching the website.
--
-- Never overwrites details management has already changed in the database:
-- RS8 is only updated while it still has no date; FN19 is only inserted.
-- Run after migrations 1–4. Safe to re-run.
-- =============================================================================

alter table public.events add column if not exists page_url     text;
alter table public.events add column if not exists series_label text;

update public.events
   set status      = 'announced',            -- becomes Scheduled automatically (date + time + venue)
       event_date  = '2026-10-24',
       end_date    = '2026-10-25',
       start_time  = '08:00',
       venue       = 'Fit & Fight Club',
       city        = 'Wagholi, Pune',
       description = 'The next generation of MMA warriors prepare for battle. Stay tuned for the ultimate showcase of rising talent.'
 where slug = 'wds-rising-star-8'
   and event_date is null
   and status in ('draft', 'announced');

insert into public.events
  (slug, title, series, series_label, status, event_date, start_time, venue, city, description, page_url)
values
  ('wds-fight-night-19', 'WDS Fight Night 19', 'championship', 'Warriors Dream Series', 'announced',
   '2026-12-12', '17:00', 'CIDCO Exhibition Ground', 'Vashi, Navi Mumbai',
   'The warriors return for another night of high-intensity MMA action. Get ready for WDS Fight Night 19.',
   'pages/wds-fight-night-19.html')
on conflict (slug) do nothing;
