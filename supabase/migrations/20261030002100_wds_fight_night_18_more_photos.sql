-- =============================================================================
-- WDS — 21: Fight Night 18 photos for Daksh Saxena and Sidhart Singh Dhami
-- (website results page + ScoreHUB). Safe to re-run. Run in Supabase -> SQL Editor.
-- =============================================================================
update public.fighters f
   set photo_url = v.url
  from (values
    ('daksh saxena',         'https://warriorsdreamseries.com/assets/images/fight-night-18/daksh-saxena.webp'),
    ('sidhart singh dhami',  'https://warriorsdreamseries.com/assets/images/fight-night-18/sidhart-singh-dhami.webp'),
    ('sidharth singh dhami', 'https://warriorsdreamseries.com/assets/images/fight-night-18/sidhart-singh-dhami.webp')
  ) as v(name_key, url)
 where f.name_key = v.name_key;

-- Check: both fighters should show a photo link
select name, photo_url from public.fighters
 where name_key in ('daksh saxena', 'sidhart singh dhami', 'sidharth singh dhami') order by name;
