-- =============================================================================
-- WDS — 19: Fight Night 19 fighter details from the fighters' camps (29 Oct 2026)
-- Updates record, country, height and (Jake Bron, Safarov Yoqubjon) photo for the
-- website and ScoreHUB. Safe to re-run. Run it in Supabase -> SQL Editor.
-- =============================================================================
with v(names, record, country, height, photo) as (values
  (array['jake bron'],                                   '6-3-0',        'Philippines', '165 cm', 'https://warriorsdreamseries.com/assets/images/fight-night-19/jake-bron.webp'),
  (array['bishal sahu'],                                 '9-4-0',        'India',       '175 cm', null),
  (array['kimson tony','kimson'],                        '1-4-0 (1 NC)', 'India',       '175 cm', null),
  (array['sohail khan','sohail'],                        '1-0-0',        'India',       '178 cm', null),
  (array['kapil gupta','chhabi (kapil) gupta','chhabi gupta','chhabi kapil gupta'], '1-0-0', 'India', '175 cm', null),
  (array['safarov yoqubjon','yoqubjon safarov'],         '3-0-1',        'Tajikistan',  '165 cm', 'https://warriorsdreamseries.com/assets/images/fight-night-19/safarov-yoqubjon.webp'),
  (array['gaganpal singh dua','gaganpal singh'],         '5-0-0',        'India',       '185 cm', null),
  (array['shaheen commando'],                            '2-0-0',        'India',       '170 cm', null)
), upd as (
  update public.fighters f
     set declared_record = v.record,
         country         = v.country,
         height          = v.height,
         photo_url       = coalesce(v.photo, f.photo_url)
    from v
   where f.name_key = any (v.names)
  returning f.id, v.record
)
update public.event_fighters ef
   set declared_record = upd.record
  from upd, public.events e
 where e.slug = 'wds-fight-night-19' and ef.event_id = e.id and ef.fighter_id = upd.id;

-- Check: 8 rows
select name, declared_record, country, height, photo_url from public.fighters
 where name_key in ('jake bron','bishal sahu','kimson tony','sohail khan','kapil gupta',
                    'safarov yoqubjon','gaganpal singh dua','shaheen commando')
 order by name;
