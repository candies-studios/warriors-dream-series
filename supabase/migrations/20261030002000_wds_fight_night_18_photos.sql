-- =============================================================================
-- WDS — 20: fighter photos for Fight Night 18 (results page) and Shoaib Khan
-- (Fight Night 18 + 19). Shown on the website and in ScoreHUB. Safe to re-run.
-- Run it in Supabase -> SQL Editor.
-- =============================================================================
update public.fighters f
   set photo_url = v.url
  from (values
    ('shoaib khan', 'https://warriorsdreamseries.com/assets/images/fight-night-19/shoaib-khan.webp'),
    ('kimbert alintozon', 'https://warriorsdreamseries.com/assets/images/fight-night-18/kimbert-alintozon.webp'),
    ('mansur yakhyaev', 'https://warriorsdreamseries.com/assets/images/fight-night-18/mansur-yakhyaev.webp'),
    ('sharip omarov', 'https://warriorsdreamseries.com/assets/images/fight-night-18/sharip-omarov.webp'),
    ('santosh yadav', 'https://warriorsdreamseries.com/assets/images/fight-night-18/santosh-yadav.webp'),
    ('nikhil prajapati', 'https://warriorsdreamseries.com/assets/images/fight-night-18/nikhil-prajapati.webp'),
    ('handsome singh', 'https://warriorsdreamseries.com/assets/images/fight-night-18/handsome-singh.webp'),
    ('saurabh negi', 'https://warriorsdreamseries.com/assets/images/fight-night-18/saurabh-negi.webp'),
    ('mohit dagar', 'https://warriorsdreamseries.com/assets/images/fight-night-18/mohit-dagar.webp'),
    ('alex sapam', 'https://warriorsdreamseries.com/assets/images/fight-night-18/alex-sapam.webp'),
    ('shiva nayak', 'https://warriorsdreamseries.com/assets/images/fight-night-18/shiva-nayak.webp')
  ) as v(name_key, url)
 where f.name_key = v.name_key;

-- Check: all 11 rows should show a photo link
select name, photo_url from public.fighters
 where name_key in ('shoaib khan', 'kimbert alintozon', 'mansur yakhyaev', 'sharip omarov', 'santosh yadav', 'nikhil prajapati', 'handsome singh', 'saurabh negi', 'mohit dagar', 'alex sapam', 'shiva nayak')
 order by name;
