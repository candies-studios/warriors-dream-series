-- =============================================================================
-- WDS — 16: Rising Star 8 fighter photos (8 fighters)
-- Shows the photos on the website results page and in ScoreHUB. Safe to re-run.
-- Abdul Qaasim Shaikh = the existing fighter record "Qaazim Sheikh".
-- Run it in Supabase -> SQL Editor.
-- =============================================================================
update public.fighters f
   set photo_url = v.url
  from (values
    ('qaazim sheikh', 'https://warriorsdreamseries.com/assets/images/rising-star-8/qaazim-sheikh.webp'),
    ('ahmed raza', 'https://warriorsdreamseries.com/assets/images/rising-star-8/ahmed-raza.webp'),
    ('chhewang karma lama', 'https://warriorsdreamseries.com/assets/images/rising-star-8/chhewang-karma-lama.webp'),
    ('lanchenba', 'https://warriorsdreamseries.com/assets/images/rising-star-8/lanchenba.webp'),
    ('md sajid khan', 'https://warriorsdreamseries.com/assets/images/rising-star-8/md-sajid-khan.webp'),
    ('nikhil charan', 'https://warriorsdreamseries.com/assets/images/rising-star-8/nikhil-charan.webp'),
    ('sadaf desai', 'https://warriorsdreamseries.com/assets/images/rising-star-8/sadaf-desai.webp'),
    ('vijay yadav', 'https://warriorsdreamseries.com/assets/images/rising-star-8/vijay-yadav.webp')
  ) as v(name_key, url)
 where f.name_key = v.name_key;

-- Check: all 8 rows should show a photo link
select name, photo_url from public.fighters
 where name_key in ('qaazim sheikh', 'ahmed raza', 'chhewang karma lama', 'lanchenba', 'md sajid khan', 'nikhil charan', 'sadaf desai', 'vijay yadav')
 order by name;
