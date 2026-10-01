-- =============================================================================
-- WDS unified data platform — 3/3: seed today's website content
--
-- Moves what is currently hardcoded in the HTML into the database, so the
-- pages look exactly the same on day one but are now data-driven:
--   * the five past events on the Home / Events pages
--   * "WDS Rising Star 8" as ANNOUNCED with no date / time / venue yet
--   * the 34 fights hardcoded in pages/rankings.html, imported as FINAL
--     results under one unlisted "historical import" event, so the ELO
--     table is reproduced by the database.
--
-- Idempotent: re-running inserts nothing twice.
-- NOTE: some imported names are placeholders carried over from the current
-- page (Opponent1…6, OpponentRS7-1…4) and "Ashok Bagde" / "Ashok Bagade" are
-- two spellings. Fix them in the admin dashboard (Fighters) — rankings update
-- by themselves. When real per-event bouts for these fights are entered,
-- delete the historical import bouts (admin: Reopen, then delete) so they are
-- not counted twice.
-- =============================================================================

insert into public.events
  (slug, title, series, status, event_date, end_date, venue, poster_url, results_url, description)
values
  ('wds-fight-night-16', 'WDS Fight Night 16', 'championship', 'completed', '2026-03-28', null,
   'LPU, Jalandhar', 'assets/images/WDS-16-website-banner.jpg',
   'https://warriorsdreamseries.com/warriors-dream-series-16', null),
  ('wds-rising-star-6', 'WDS Rising Star 6', 'rising-star', 'completed', '2026-04-25', '2026-04-26',
   'Fit & Fight Club, Nerul', 'assets/images/wds-rising-star-4.jpg',
   'https://warriorsdreamseries.com/wds-rising-star-6', null),
  ('wds-fight-night-17', 'WDS Fight Night 17', 'championship', 'completed', '2026-06-06', null,
   'Sport Complex, Mumbai University, Kalina', 'assets/images/wds-fight-night-17.jpg',
   'https://warriorsdreamseries.com/warriors-dream-series-17/', null),
  ('wds-rising-star-7', 'WDS Rising Star 7', 'rising-star', 'completed', '2026-07-25', '2026-07-26',
   'Fit & Fight Club, Nerul, Navi Mumbai', 'assets/images/wds-rising-star-7.jpg',
   'https://warriorsdreamseries.com/wds-rising-star-7/', null),
  ('wds-fight-night-18', 'WDS Fight Night 18', 'championship', 'completed', '2026-08-29', null,
   'Cidco Exhibition & Convention Centre, Vashi, Navi Mumbai', 'assets/images/fight-night-18-banner.jpg',
   'https://warriorsdreamseries.com/wds-fight-night-18', null),
  ('wds-rising-star-8', 'WDS Rising Star 8', 'rising-star', 'announced', null, null,
   null, null, null,
   E'The next generation of MMA warriors prepare for battle.\nStay tuned for the ultimate showcase of rising talent.')
on conflict (slug) do nothing;

insert into public.events (slug, title, series, status, event_date, is_listed, description)
values ('historical-results-import', 'WDS historical results (import)', 'other', 'completed', '2025-12-31', false,
        'Results carried over from the original Rankings page. Unlisted; used only for rankings history.')
on conflict (slug) do nothing;

do $$
declare
  ev uuid;
  r record;
  a uuid; c uuid;
  division_names constant jsonb := '{"flyweight":"Flyweight","bantamweight":"Bantamweight","featherweight":"Featherweight","lightweight":"Lightweight","welterweight":"Welterweight","lightheavyweight":"Light Heavyweight"}';
begin
  select id into ev from public.events where slug = 'historical-results-import';
  if exists (select 1 from public.bouts where event_id = ev) then
    raise notice 'Historical results already imported';
    return;
  end if;

  for r in
    select * from (values
      (1,'Jeko Laishram','Opponent1','Jeko Laishram','flyweight'),
      (2,'Gaganpal Singh Dua','Opponent2','Gaganpal Singh Dua','bantamweight'),
      (3,'Bishal Sahu','Opponent3','Bishal Sahu','flyweight'),
      (4,'Shoaib Khan','Opponent4','Shoaib Khan','lightweight'),
      (5,'Mansur Yakhyaev','Opponent5','Mansur Yakhyaev','welterweight'),
      (6,'Sharip Omarov','Opponent6','Sharip Omarov','bantamweight'),
      (7,'Shreenath Barale','OpponentRS7-1','Shreenath Barale','lightweight'),
      (8,'Shrishti Dethe','OpponentRS7-2','Shrishti Dethe','featherweight'),
      (9,'Bhuvan R','OpponentRS7-3','Bhuvan R','flyweight'),
      (10,'Ashish Maurya','OpponentRS7-4','Ashish Maurya','welterweight'),
      (11,'Ben Holdsworth','Kimson Tony','Ben Holdsworth','welterweight'),
      (12,'Ashok Bagde','Rohit Raina','Ashok Bagde','bantamweight'),
      (13,'Muhiddinov Oyatullo','Kesavan M','Muhiddinov Oyatullo','featherweight'),
      (14,'A Shabarish','Thiaumuanlal Guite','A Shabarish','flyweight'),
      (15,'Raj Singh Baghel','Rajkumar R','Raj Singh Baghel','featherweight'),
      (16,'Sangramsingh Godse','Sagar Dange','Sangramsingh Godse','flyweight'),
      (17,'Varun Sanyal','Karan Chauhan','Varun Sanyal','lightweight'),
      (18,'Nikhil Thapa','Chhimey Nurbu Bodh','Nikhil Thapa','flyweight'),
      (19,'Suryansh Pathak','Nikhil Prajapati','Suryansh Pathak','flyweight'),
      (20,'Syed Imad Uddin','Gurjeet Chahal','Syed Imad Uddin','lightheavyweight'),
      (21,'Andrey Chelbaev','Ashok Bagade','Ashok Bagade','bantamweight'),
      (22,'Rishabh Patel','Gurtej Singh','Gurtej Singh','lightweight'),
      (23,'Amit Amauriya','Harsh Pandya','Harsh Pandya','flyweight'),
      (24,'Karandeep Singh','Karan Jadhav','Karan Jadhav','bantamweight'),
      (25,'Rehan Rizvi','Anubhav Kashyap','Anubhav Kashyap','flyweight'),
      (26,'Amit Cheeda','M V Sarath Raj','Amit Cheeda','welterweight'),
      (27,'Mohit Dagar','Qaazim Sheikh','Mohit Dagar','bantamweight'),
      (28,'Mahesh','Vijay Yadav','Mahesh','flyweight'),
      (29,'Santosh Yadav','Mano Satya Sai','Santosh Yadav','flyweight'),
      (30,'Pruthvi Gulla','Bhim Singh','Pruthvi Gulla','featherweight'),
      (31,'Vikas Sehrawat','Aman Shaikh','Vikas Sehrawat','featherweight'),
      (32,'Marshal Khimta','Anosh','Marshal Khimta','flyweight'),
      (33,'Manav G V S','Vishal Magar','Manav G V S','bantamweight'),
      (34,'Duke','Nitish Kumar','Duke','bantamweight')
    ) as t(n, f1, f2, winner, division)
    order by n
  loop
    select id into a from public.fighters where name_key = lower(r.f1) limit 1;
    if a is null then
      insert into public.fighters (name, weight_class) values (r.f1, division_names ->> r.division) returning id into a;
    end if;
    select id into c from public.fighters where name_key = lower(r.f2) limit 1;
    if c is null then
      insert into public.fighters (name, weight_class) values (r.f2, division_names ->> r.division) returning id into c;
    end if;
    insert into public.event_fighters (event_id, fighter_id, weight_class)
      values (ev, a, division_names ->> r.division), (ev, c, division_names ->> r.division)
      on conflict do nothing;

    insert into public.bouts
      (event_id, bout_number, bout_name, weight_class, bout_date, status, blue_fighter_id, red_fighter_id,
       result_type, winner_id, result_note, result_status, completed_at)
    values
      (ev, r.n, division_names ->> r.division, division_names ->> r.division, '2025-12-31', 'COMPLETED', a, c,
       'DECISION_UNANIMOUS', case when r.winner = r.f1 then a else c end,
       'Imported from the original Rankings page (method not recorded).', 'final', '2025-12-31');
  end loop;
end $$;

-- Make sure the rankings table reflects the import even if triggers were
-- disabled while seeding.
select public.recompute_rankings();
