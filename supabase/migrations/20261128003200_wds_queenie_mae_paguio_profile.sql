-- =============================================================================
-- WDS — 32: Queenie Mae Paguio profile (Fight Night 19, bout 9 vs Alena Ignateva)
--   Photo, country Philippines, height 160 cm, pro record 0-0-0 (pro debut).
-- Only changes her fighter profile. Safe to re-run.
-- Run it once in Supabase -> SQL Editor.
-- =============================================================================
update public.fighters
   set photo_url       = 'https://wdsmma.com/assets/images/fight-night-19/queenie-mae-paguio.webp',
       country         = 'Philippines',
       height          = '160 cm',
       declared_record = '0-0-0'
 where name_key = 'queenie mae paguio';

-- Check
select name, country, height, declared_record, photo_url
  from public.fighters where name_key = 'queenie mae paguio';
