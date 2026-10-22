-- =============================================================================
-- WDS — 12: fighter photos for Rising Star 8 (9 fighters) and Fight Night 19 (Ketan Uppadhyay)
-- Shows the photos on the website fight cards and in ScoreHUB. Safe to re-run.
-- Run it in Supabase -> SQL Editor.
-- =============================================================================
update public.fighters f
   set photo_url = v.url
  from (values
    ('giftson awungshi', 'https://warriorsdreamseries.com/assets/images/rising-star-8/giftson-awungshi.webp'),
    ('pratik lambade', 'https://warriorsdreamseries.com/assets/images/rising-star-8/pratik-lambade.webp'),
    ('atharva sanjay katore', 'https://warriorsdreamseries.com/assets/images/rising-star-8/atharva-katore.webp'),
    ('bhuvan rai', 'https://warriorsdreamseries.com/assets/images/rising-star-8/bhuvan-rai.webp'),
    ('deekshitha r', 'https://warriorsdreamseries.com/assets/images/rising-star-8/deekshitha-r.webp'),
    ('kushal rao', 'https://warriorsdreamseries.com/assets/images/rising-star-8/kushal-rao.webp'),
    ('nayan mandlik', 'https://warriorsdreamseries.com/assets/images/rising-star-8/nayan-mandlik.webp'),
    ('stefan dsouza', 'https://warriorsdreamseries.com/assets/images/rising-star-8/stefan-dsouza.webp'),
    ('vijay saini', 'https://warriorsdreamseries.com/assets/images/rising-star-8/vijay-saini.webp'),
    ('ketan uppadhyay', 'https://warriorsdreamseries.com/assets/images/fight-night-19/ketan-uppadhyay.webp')
  ) as v(name_key, url)
 where f.name_key = v.name_key;

-- Check: every row should show a photo link
select f.name, f.photo_url
  from public.fighters f
 where f.name_key in ('giftson awungshi', 'pratik lambade', 'atharva sanjay katore', 'bhuvan rai', 'deekshitha r', 'kushal rao', 'nayan mandlik', 'stefan dsouza', 'vijay saini', 'ketan uppadhyay')
 order by f.name;
