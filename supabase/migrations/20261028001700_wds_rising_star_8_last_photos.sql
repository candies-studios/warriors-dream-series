-- =============================================================================
-- WDS — 17: last Rising Star 8 fighter photos (Vikas Banubakode, Aryan Sawant,
-- Sujal Bhatt) for the website results page and ScoreHUB. Safe to re-run.
-- Run it in Supabase -> SQL Editor.
-- =============================================================================
update public.fighters f
   set photo_url = v.url
  from (values
    ('vikas banubakode', 'https://warriorsdreamseries.com/assets/images/rising-star-8/vikas-banubakode.webp'),
    ('aryan sawant',     'https://warriorsdreamseries.com/assets/images/rising-star-8/aryan-sawant.webp'),
    ('sujal bhatt',      'https://warriorsdreamseries.com/assets/images/rising-star-8/sujal-bhatt.webp')
  ) as v(name_key, url)
 where f.name_key = v.name_key;

-- Check: all 3 rows should show a photo link
select name, photo_url from public.fighters
 where name_key in ('vikas banubakode', 'aryan sawant', 'sujal bhatt') order by name;
