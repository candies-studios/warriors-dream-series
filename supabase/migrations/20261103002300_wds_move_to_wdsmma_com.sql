-- =============================================================================
-- WDS — 23: main domain moves from warriorsdreamseries.com to wdsmma.com
-- Points every fighter photo, event poster and event page link stored in the
-- database at the new domain, so the website and ScoreHUB keep showing them
-- after the old domain starts forwarding. Safe to re-run.
-- Run it in Supabase -> SQL Editor ONLY AFTER https://wdsmma.com opens the site.
-- =============================================================================
update public.fighters
   set photo_url = regexp_replace(photo_url, '^https?://(www\.)?warriorsdreamseries\.com/', 'https://wdsmma.com/')
 where photo_url ~ '^https?://(www\.)?warriorsdreamseries\.com/assets/';

update public.events
   set poster_url = regexp_replace(poster_url, '^https?://(www\.)?warriorsdreamseries\.com/', 'https://wdsmma.com/')
 where poster_url ~ '^https?://(www\.)?warriorsdreamseries\.com/assets/';

-- Check: should return 0 rows
select name, photo_url from public.fighters
 where photo_url ~ '^https?://(www\.)?warriorsdreamseries\.com/assets/';
