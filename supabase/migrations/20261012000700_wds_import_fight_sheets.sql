-- =============================================================================
-- WDS — 7: fight results from the official WDS fight sheets
--
-- Source: the fight sheets supplied by WDS management (Excel / Numbers), one per
-- event: Fight Night 4, 5, 6, 7 (pro card + amateur tournament finals), 8, 9, 10,
-- 12, 13, 14 and Rising Star 1, 2, 3, 4, 5.
-- Not covered (no sheet yet): Fight Night 1, 2, 3, 11, 15 and Rising Star 6.
--
-- What it does
--   1. Rankings count MMA fights only (K1 kickboxing bouts are shown on the
--      event page but do not affect MMA rankings).
--   2. Merges spellings of the same fighter into one identity (list below).
--   3. Creates the 15 events (completed) and adds every fight with winner,
--      method, round and time as FINAL results. Fighters already in the
--      database are reused (matched by name); new ones are created with their
--      gym and hometown from the sheet.
--   4. Recomputes the rankings.
--
-- Safe to re-run: an event that already has fights is skipped.
-- Left for management (see the README):
--   * FN8 Siddharth Kothapalli vs Waheeb Wakeel — method missing on the sheet,
--     imported as PROVISIONAL (not public, not ranked) until finalized.
--   * RS2 bout 1 (Under-16 youth bout) not imported.
--   * RS2 Syed Ismail vs Viraj Dhore was a walkover — kept as a cancelled bout.
-- =============================================================================

-- 1. MMA-only rankings ---------------------------------------------------------------
do $$
declare def text;
begin
  select pg_get_functiondef('public.recompute_rankings()'::regprocedure) into def;
  if position('b.discipline = ''MMA''' in def) = 0 then
    def := replace(def, 'where b.result_status = ''final''', 'where b.result_status = ''final'' and b.discipline = ''MMA''');
    execute def;
  end if;
end $$;

-- 2. One identity per fighter ---------------------------------------------------------
do $$
declare keep uuid; dup uuid; pair text[];
begin
  foreach pair slice 1 in array array[
    ['A Shabarish', 'shabrish ayyanar'],
    ['Abhijeet Singh Saini', 'abhijit saini'],
    ['Anubhav Kashyap', 'anubhav kumar'],
    ['Ashok Bagde', 'ashok bagade'],
    ['Bhumi Kanwar', 'bhumi kunwar'],
    ['Bhuvan Rai', 'bhuvan r'],
    ['Bhuvan Rai', 'bhuwan rai'],
    ['Durga Bishwakarma', 'durga bishwakarma (george smith)'],
    ['Gaganpal Singh Dua', 'gagan pal singh dua'],
    ['Gaganpal Singh Dua', 'gaganpal singh'],
    ['Gaurav Kiran Tate', 'gaurav tate'],
    ['Handsome Singh', 'handsome haobijam'],
    ['Himanshu Madan Bisht', 'himanshu bisht'],
    ['Himanshu Madan Bisht', 'himanshu bist'],
    ['Himanshu Madan Bisht', 'himanshu madan bist'],
    ['Igor Smart', 'igor bonham isambard'],
    ['Igor Smart', 'igor bonham isambard smart'],
    ['Karandeep Singh', 'karandeep singh bajwa'],
    ['Lakhi Das', 'lakhi daas'],
    ['Mrutunjay Madhal', 'mritunjay'],
    ['Nayan Mandlik', 'nayan dinesh mandlik'],
    ['Nirjala Badaliya', 'nirjala badaila'],
    ['Nirjala Badaliya', 'nirjala badalia'],
    ['Pranav R S', 'pranav rs'],
    ['Prathamesh Kenjale', 'prathmesh kenjale'],
    ['Purushothaman M K', 'purushothaman munuswamy kumar'],
    ['Qaazim Sheikh', 'abdul qaazim sheikh'],
    ['Sagar Kashyap', 'sagar kahsyap'],
    ['Sagar Ramdas Dange', 'sagar dange'],
    ['Satyaprakash Rajbhar', 'satyaa rajbhar'],
    ['Shivaraj Basappa', 'shivaraj b'],
    ['Shrishti Dethe', 'shirish dethe'],
    ['Shrishti Dethe', 'shirishthi'],
    ['Shrishti Dethe', 'shirishthi dethe'],
    ['Siddharth Kothapalli', 'siddarth kothapalli'],
    ['Siddharth Kothapalli', 'siddharth kothappali'],
    ['Swapnil Shinde', 'swapil shinde'],
    ['Tulashidas Ningombam', 'tulashidas meetai'],
    ['Tulashidas Ningombam', 'tulashidas ningbombam'],
    ['Tulashidas Ningombam', 'tulashidas ningobam']] loop
    select id into dup  from public.fighters where name_key = lower(pair[2]) order by created_at limit 1;
    if dup is null then continue; end if;
    select id into keep from public.fighters where name_key = lower(pair[1]) order by created_at limit 1;
    if keep is null then
      update public.fighters set name = pair[1] where id = dup;
      continue;
    end if;
    update public.bouts set blue_fighter_id = keep where blue_fighter_id = dup;
    update public.bouts set red_fighter_id  = keep where red_fighter_id  = dup;
    update public.bouts set winner_id       = keep where winner_id       = dup;
    insert into public.event_fighters (event_id, fighter_id, weight_class, declared_record)
      select event_id, keep, weight_class, declared_record from public.event_fighters where fighter_id = dup
      on conflict do nothing;
    delete from public.fighters where id = dup;
  end loop;
end $$;

-- 3a. Events -----------------------------------------------------------------------------
insert into public.events (slug, title, series, status, event_date, end_date, venue, city, description)
values
  ('wds-fight-night-4', 'WDS Fight Night 4', 'championship', 'completed', '2023-03-25', '2023-03-26', 'Fit & Fight Club, Nerul', 'Navi Mumbai', null),
  ('wds-fight-night-5', 'WDS Fight Night 5', 'championship', 'completed', '2023-07-30', null, 'Fit & Fight Club, Nerul', 'Navi Mumbai', null),
  ('wds-fight-night-6', 'WDS Fight Night 6', 'championship', 'completed', '2023-10-28', null, 'Fit & Fight Club, Nerul', 'Navi Mumbai', null),
  ('wds-fight-night-7', 'WDS Fight Night 7', 'championship', 'completed', '2024-02-11', null, null, 'Navi Mumbai', null),
  ('wds-fight-night-8', 'WDS Fight Night 8', 'championship', 'completed', '2024-05-25', '2024-05-26', 'Fit & Fight Club, Nerul', 'Navi Mumbai', null),
  ('wds-fight-night-9', 'WDS Fight Night 9', 'championship', 'completed', '2024-09-01', null, 'Fit & Fight Club, Nerul', 'Navi Mumbai', null),
  ('wds-rising-star-1', 'WDS Rising Star 1', 'rising-star', 'completed', '2024-12-01', null, 'Fit & Fight Club, Nerul', 'Navi Mumbai', null),
  ('wds-fight-night-10', 'WDS Fight Night 10', 'championship', 'completed', '2025-01-19', null, 'Fit & Fight Club, Nerul', 'Navi Mumbai', null),
  ('wds-rising-star-2', 'WDS Rising Star 2', 'rising-star', 'completed', '2025-03-30', null, 'Bhanushali Wadi, Nerul', 'Navi Mumbai', null),
  ('wds-fight-night-12', 'WDS Fight Night 12', 'championship', 'completed', '2025-05-04', null, 'Fit & Fight Club, Navi Mumbai', 'Navi Mumbai', null),
  ('wds-rising-star-3', 'WDS Rising Star 3', 'rising-star', 'completed', '2025-06-22', null, 'Bhanushali Wadi, Nerul', 'Navi Mumbai', null),
  ('wds-fight-night-13', 'WDS Fight Night 13', 'championship', 'completed', '2025-07-27', null, 'Bhanushali Wadi, Nerul', 'Navi Mumbai', null),
  ('wds-rising-star-4', 'WDS Rising Star 4', 'rising-star', 'completed', '2025-09-18', '2025-09-19', 'Fit & Fight Club, Nerul', 'Navi Mumbai', null),
  ('wds-fight-night-14', 'WDS Fight Night 14', 'championship', 'completed', '2025-11-09', null, 'Fit & Fight Club, Navi Mumbai', 'Navi Mumbai', null),
  ('wds-rising-star-5', 'WDS Rising Star 5', 'rising-star', 'completed', '2025-12-21', null, 'Bhanushali Wadi, Nerul', 'Navi Mumbai', null)
on conflict (slug) do nothing;

-- 3b. Fights -----------------------------------------------------------------------------
do $$
declare
  r record; ev record; a uuid; c uuid; w uuid;
  skip_events text[];
begin
  select coalesce(array_agg(e.slug), '{}') into skip_events
    from public.events e
   where e.slug in ('wds-fight-night-4', 'wds-fight-night-5', 'wds-fight-night-6', 'wds-fight-night-7', 'wds-fight-night-8', 'wds-fight-night-9', 'wds-rising-star-1', 'wds-fight-night-10', 'wds-rising-star-2', 'wds-fight-night-12', 'wds-rising-star-3', 'wds-fight-night-13', 'wds-rising-star-4', 'wds-fight-night-14', 'wds-rising-star-5')
     and exists (select 1 from public.bouts b where b.event_id = e.id);
  if array_length(skip_events, 1) > 0 then
    raise notice 'Already has fights, skipped: %', skip_events;
  end if;

  for r in
    select * from (values
      ('wds-fight-night-10',1,null,'AMATEUR','MMA','Strawweight',180,'Nirjala Badaliya','Nayan Mandlik','Nirjala Badaliya','TKO',3,95,'COMPLETED','final','Imported from the WDS fight sheet.','Warrior''s Fitness Club','Mumbai, Maharashtra, India','FIT & FIGHT CLUB','Mumbai, Maharashtra, India'),
      ('wds-fight-night-10',2,null,'AMATEUR','MMA','Bantamweight',180,'Satyaprakash Rajbhar','Yuvraj Gupta','Yuvraj Gupta','SUBMISSION',1,76,'COMPLETED','final','Imported from the WDS fight sheet.','FIT & FIGHT CLUB','MUMBAI, MAHARASHTRA, INDIA',null,'Thane, Maharashtra, India'),
      ('wds-fight-night-10',3,null,'AMATEUR','MMA','Flyweight',180,'Junaid Shaikh','Aniket Patil','Aniket Patil','DECISION_SPLIT',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','S.S.MRTIAL ARTS CLUB','Nashik, MAHARASHTRA, INDIA','FIT & FIGHT CLUB','MUMBAI, MAHARASHTRA, INDIA'),
      ('wds-fight-night-10',4,null,'AMATEUR','MMA','Strawweight',180,'Vikas Gupta','Vijay Yadav','Vikas Gupta','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Pro-warrior MMA','MUMBAI, MAHARASHTRA, INDIA','FIT & FIGHT CLUB','MUMBAI, MAHARASHTRA, INDIA'),
      ('wds-fight-night-10',5,null,'AMATEUR','MMA','Bantamweight',180,'Om Waghmare','Milan Moirangthem','Milan Moirangthem','TKO',2,113,'COMPLETED','final','Imported from the WDS fight sheet.','Pitbull MMA','MUMBAI, MAHARASHTRA, INDIA','Koi RMX','Imphal, Manipur'),
      ('wds-fight-night-10',6,null,'AMATEUR','MMA','Flyweight',180,'Vikas Jaiswar','Himanshu Madan Bisht','Vikas Jaiswar','TKO',3,31,'COMPLETED','final','Imported from the WDS fight sheet.','Pro Warrior MMA','MUMBAI, MAHARASHTRA, INDIA','Team spartan','Palghar, Maharashtra, India'),
      ('wds-fight-night-10',7,null,'AMATEUR','MMA','Bantamweight',180,'Pankaj Mehra','Ashok Bagde','Ashok Bagde','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Crosstrain Fight Club','Faridabad, Haryana, India','FIT & FIGHT CLUB','MUMBAI, MAHARASHTRA, INDIA'),
      ('wds-fight-night-10',8,null,'PROFESSIONAL','MMA','Flyweight',300,'Wahedullah Sediqi','Nazareth Lalthazuala','Nazareth Lalthazuala','TKO',1,113,'COMPLETED','final','Imported from the WDS fight sheet.','Knockout Fight','Bhopal, Madhya Pradesh, India','Dojang MMA','Aizawl, Mizoram, India'),
      ('wds-fight-night-10',9,null,'PROFESSIONAL','MMA','Lightweight',300,'Shubham Pandey','Mohsin Shaikh','Mohsin Shaikh','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','NA','Nagpur, Maharashtra, India',null,null),
      ('wds-fight-night-10',10,null,'PROFESSIONAL','MMA',null,300,'Tulashidas Ningombam','Prathamesh Kenjale','Prathamesh Kenjale','RNC',2,216,'COMPLETED','final','Imported from the WDS fight sheet.','RMX','Thoubal, Manipur, India','FIT & FIGHT CLUB','MUMBAI, MAHARASHTRA, INDIA'),
      ('wds-fight-night-10',11,null,'PROFESSIONAL','MMA',null,300,'Sangram Singh','Mahboob Khan','Mahboob Khan','KO_HEAD',1,68,'COMPLETED','final','Imported from the WDS fight sheet.','Fitnesswyn Studio','Nagpur, Maharashtra, India','New Town MMA','Hyderabad, Telangana, India'),
      ('wds-fight-night-12',1,null,'AMATEUR','K1','Flyweight',180,'Pranav R S','Aakash Bharti','Pranav R S','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','RMX Mixed Martial Arts','Kozhikode, Keala, India','SS Martial Arts','Nashik, Maharashtra, India'),
      ('wds-fight-night-12',2,null,'AMATEUR','K1','Flyweight',180,'Abhishek M','Swapnil Shinde','Swapnil Shinde','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','RMX Mixed Martial Arts','Kozhikode, Keala, India','SS Martial Arts','Nashik, Maharashtra, India'),
      ('wds-fight-night-12',3,null,'AMATEUR','MMA','Welterweight',180,'Deepak Kandari','Vijay Jagtap','Vijay Jagtap','KO_HEAD',2,14,'COMPLETED','final','Imported from the WDS fight sheet.','Team Relentless','Garhwal, Srinagar, Uttrakhand, India','Cobra Thai','Satara, Maharashtra, India'),
      ('wds-fight-night-12',4,null,'AMATEUR','MMA','Welterweight',180,'L Praveen Nayak','Amit Cheeda','Amit Cheeda','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Shoorveer Academy','Hydrabad, Andhra Pradesh, India','Elite Fight city MMA','Amritsar, Punjab, India'),
      ('wds-fight-night-12',5,null,'AMATEUR','MMA','Flyweight',180,'Mahesh','Anosh','Mahesh','KO_HEAD',2,62,'COMPLETED','final','Imported from the WDS fight sheet.','Beast itt','Shimla, Himachal Pradesh, India','Elite Fight city MMA','Amritsar, Punjab, India'),
      ('wds-fight-night-12',6,null,'AMATEUR','MMA','Strawweight',180,'Sahil Shaikh','Aryan Londhe','Aryan Londhe','RNC',1,157,'COMPLETED','final','Imported from the WDS fight sheet.','Combat Fitness Centre','Mumbai, Maharashtra, India','Cobra Thai','Solapur, Maharashtra, India'),
      ('wds-fight-night-12',7,null,'AMATEUR','MMA','Flyweight',180,'Vijay Yadav','A Shabarish','A Shabarish','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight Club','Mulund, Mumbai, Maharashtra, India','Combat Kinetics','Chennai ,Tamil Nadu , India'),
      ('wds-fight-night-12',8,null,'AMATEUR','MMA','Flyweight',180,'Evansraj Jagateesan','Nikhil Prajapati','Nikhil Prajapati','RNC',2,151,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight Club','Navi Mumbai, Maharashtra, India','Martial warriors academy','Baghpat ,Uttar Pradesh , India'),
      ('wds-fight-night-12',9,null,'AMATEUR','MMA','Featherweight',180,'Ayman Shaikh','Milan Singh','Ayman Shaikh','KO_HEAD',1,52,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight Club','Navi Mumbai, Maharashtra, India','RMX Mixed Martial Arts','Imphal,Manipur , India'),
      ('wds-fight-night-12',10,null,'AMATEUR','MMA','Featherweight',180,'Shivam Dubey','Handsome Singh','Handsome Singh','KO_HEAD',1,135,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight Club','Navi Mumbai, Maharashtra, India','RMX Mixed Martial Arts','Manipur, india'),
      ('wds-fight-night-12',11,null,'AMATEUR','MMA','Bantamweight',180,'Ashok Bagde','Igor Smart','Ashok Bagde','SUBMISSION',2,15,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight Club','Navi Mumbai, Maharashtra, India','Tribal warriors','Guirim , Goa, India'),
      ('wds-fight-night-12',12,null,'PROFESSIONAL','MMA','Bantamweight',300,'Tulashidas Ningombam','Karandeep Singh','Karandeep Singh','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','RMX Mixed Martial Arts','Thoubai, Manipur, India','EFC MMA Amrtitsar Panjab','Gurdaspur, Punjab, India'),
      ('wds-fight-night-12',13,null,'PROFESSIONAL','MMA','Welterweight',300,'Purushothaman M K','Rayyan Butt','Rayyan Butt','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','Chennai MMA Training Academy','Chennai, Tamilnadu, India',null,null),
      ('wds-fight-night-12',14,null,'PROFESSIONAL','MMA','Catchweight',300,'Rajkumar R','Niranjan Phanjoubam','Niranjan Phanjoubam','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','Fit to fight focus','Coimbatore, Tamil Nadu, India','Kaizen MMA','Imphal, Manipur, india'),
      ('wds-fight-night-13',1,null,'AMATEUR','K1','Bantamweight',180,'Satyaprakash Rajbhar','Aryan Singh','Satyaprakash Rajbhar','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Thane ,maharashtra,india','Team grit','Mumbai, Maharashtra, India'),
      ('wds-fight-night-13',2,null,'AMATEUR','MMA','Strawweight',180,'Viraj Dhore','Rizwansab Mudgal','Rizwansab Mudgal','SUBMISSION',1,78,'COMPLETED','final','Imported from the WDS fight sheet.','Cobra thai gym','Pune, Maharashtra, India','Tribal warriors','Anjuna, Goa, India'),
      ('wds-fight-night-13',3,null,'AMATEUR','MMA','Strawweight',180,'Harry','Shrishti Dethe','Shrishti Dethe','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','EFC MMA AND FITNESS','Ajnala, Punjab, India','One Punch MMA','Mumbai, Maharashtra, India'),
      ('wds-fight-night-13',4,null,'AMATEUR','MMA','Bantamweight',180,'Evansraj Jagateesan','Vishal Shetty','Vishal Shetty','SUBMISSION',1,169,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Navi Mumbai, Maharashtra, India','Tribal Warriros','Mumbai, Maharashtra, India'),
      ('wds-fight-night-13',5,null,'AMATEUR','MMA','Flyweight',180,'Parth Sapkal','Shuaib Ali','Parth Sapkal','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight','Kharghar navi mumbai, Maharashtra, India','Tribal Warriros','Calangute, Goa, India'),
      ('wds-fight-night-13',6,null,'AMATEUR','MMA','Light Heavyweight',180,'Gaurav Singh','Saud Anwar','Saud Anwar','TKO',1,116,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Navi Mumbai, Maharashtra, India','Teams Relentless','Mumbai, Mahashtra, India'),
      ('wds-fight-night-13',7,null,'AMATEUR','MMA','Flyweight',180,'Sagar Ramdas Dange','Mahesh','Mahesh','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Jalna,Maharashtra, India','Beast ITT','Rampur bushahr, Himachal Pradesh, India'),
      ('wds-fight-night-13',8,null,'AMATEUR','MMA','Welterweight',180,'Amit Cheeda','Vijay Jagtap','Amit Cheeda','DECISION_SPLIT',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','EFC mma & Fitness','Gujhapeer,Ajnala, Amritsar, Punjab, India','Cobra thai gym','Satara, Maharatra, India'),
      ('wds-fight-night-13',9,null,'AMATEUR','MMA','Flyweight',180,'Swapnil Shinde','Rajat Diwedi','Rajat Diwedi','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.',null,null,'Cobra Thai','Saharanpur, Uttar Pradesh, India'),
      ('wds-fight-night-13',10,null,'AMATEUR','MMA','Strawweight',180,'Aniket Patil','Sahil Shaikh','Sahil Shaikh','TKO',2,158,'COMPLETED','final','Imported from the WDS fight sheet.','Fit & Fight Club','Navi Mumbai, Maharashtra , India','Combat Fitness Centre','Mumbra-Thane, Maharashtra , India'),
      ('wds-fight-night-13',11,null,'AMATEUR','MMA','Lightweight',180,'Shivam Dubey','Akash Rathod','Akash Rathod','SUBMISSION',1,112,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Nahi Mumbai , Maharashtra , India','Dragon combat sports academy','Valsad, Gujrat, India'),
      ('wds-fight-night-13',12,null,'AMATEUR','MMA','Bantamweight',180,'Ayman Shaikh','Vishal Magar','Vishal Magar','DECISION_SPLIT',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Pune, Maharashtra, India','Beast ITT','Jhakri,Himachal Pradesh , India'),
      ('wds-fight-night-13',13,null,'AMATEUR','MMA','Flyweight',180,'A Shabarish','Santosh Yadav','Santosh Yadav','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Dynamics 101','Chennai ,Tamil Nadu , India','ONE PUNCH MMA','Mumbai, Maharashtra, India'),
      ('wds-fight-night-13',14,null,'AMATEUR','MMA','Flyweight',180,'Vijay Yadav','Marshal Khimta','Vijay Yadav','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit & fight club','Mulund, Maharashtra, India','Beast I.T.T','Rampur,Himachal Pradesh, India'),
      ('wds-fight-night-13',15,null,'AMATEUR','MMA','Bantamweight',180,'Igor Smart','Bhim Singh','Igor Smart','SUBMISSION',1,92,'COMPLETED','final','Imported from the WDS fight sheet.','Tribal warriors','Calangute ,Goa, India','Beast I.T.T','Kullu,Himachal Pradesh, India'),
      ('wds-fight-night-13',16,null,'PROFESSIONAL','MMA','Catchweight',300,'Rayyan Butt','Gurtej Singh',null,'NO_CONTEST',null,null,'COMPLETED','final','Imported from the WDS fight sheet.','Relentless MMA','Mumbai, Maharashtra, India','Efc (Elite fight city)','Amritsar ,Punjab, India'),
      ('wds-fight-night-13',17,null,'PROFESSIONAL','MMA','Flyweight',300,'Vikas Jaiswar','Shivaraj Basappa','Shivaraj Basappa','RNC',1,108,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club / Dojang MMA','Mumbai,maharashtra, india','Combat Galaxy','Bengaluru,Karnataka, India'),
      ('wds-fight-night-13',18,null,'PROFESSIONAL','MMA','Bantamweight',300,'Ashok Bagde','Karandeep Singh','Ashok Bagde','SUBMISSION',1,54,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight Club','Navi Mumbai, Maharashtra, India','Efc (Elite fight city)','Gurdaspur, punjab, India'),
      ('wds-fight-night-14',1,null,'AMATEUR','MMA','Catchweight',180,'Krishna Gupta','Yogesh Gurjar','Yogesh Gurjar','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight Club','Navi Mumbai, Maharashtra, India','Saiyan Muay thai','Jait Pur, South Delhi, India'),
      ('wds-fight-night-14',2,null,'AMATEUR','MMA','Flyweight',180,'Bhuvan Rai','Rajneesh Hazare','Rajneesh Hazare','TKO',2,124,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight club','Dahisar, mumbai, maharashtra, india','COMBAT FITNESS CLAN','South Goa, India'),
      ('wds-fight-night-14',3,null,'AMATEUR','MMA','Strawweight',180,'Danish Khan','Sagar Thapa','Sagar Thapa','KO_HEAD',1,46,'COMPLETED','final','Imported from the WDS fight sheet.','Team Relentless','Kushinagar, Uttar Pradesh india','Combat fitness clan','Margao, Goa, India'),
      ('wds-fight-night-14',4,null,'AMATEUR','MMA','Strawweight',180,'Karan Pandit','Shrishti Dethe','Shrishti Dethe','SUBMISSION',2,66,'COMPLETED','final','Imported from the WDS fight sheet.','Tribal warrior’s goa','Panjim, Goa, India','One Punch MMA','Mumbai, maharashtra, india'),
      ('wds-fight-night-14',5,null,'AMATEUR','MMA','Bantamweight',180,'Pravin Gupta','Ashish Maurya','Ashish Maurya','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','MMA Warriors','Thane, Maharashtra, India','Fit and fight club','Azamgarh, Uttar Pradesh, India'),
      ('wds-fight-night-14',6,null,'AMATEUR','MMA','Featherweight',180,'Abhay Kahar','Handsome Singh','Abhay Kahar','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Team Relentless','Mumbai, Maharashtra, India','Team RMX','Imphal, Manipur, india'),
      ('wds-fight-night-14',7,null,'AMATEUR','MMA','Flyweight',180,'Parth Sapkal','Pranesh Phanse','Pranesh Phanse','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight Club','Navi Mumbai, Maharashtra, India','One Punch MMA','Mumbai, Maharashtra, India'),
      ('wds-fight-night-14',8,null,'AMATEUR','MMA','Flyweight',180,'Mohammad Adil','Sahil Shaikh','Mohammad Adil','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','The Deccan Tiger','Hydrabad, Telangana, India','Combat Fitness Centre','Thane, Maharashtra, india'),
      ('wds-fight-night-14',9,null,'AMATEUR','MMA','Catchweight',180,'Ayman Shaikh','Vishal Magar','Vishal Magar','SUBMISSION',1,129,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight Club','Navi Mumbai, Maharashtra, India','Beast ITT','Jhakri, Himachal Pradesh , India'),
      ('wds-fight-night-14',10,null,'AMATEUR','MMA','Flyweight',180,'Vijay Yadav','Sachin Singh','Vijay Yadav','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight Club','Mulund, Mumbai, Maharashtra, India','Collision mma','Palwal, Haryana India'),
      ('wds-fight-night-14',11,null,'AMATEUR','MMA','Catchweight',180,'Aryan Yadav','Anuj Verma','Anuj Verma','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Combat Galaxy','Bangalore , Karnataka , India','Team Relentless','Mumbai, Maharashtra, India'),
      ('wds-fight-night-14',12,null,'AMATEUR','MMA','Light Heavyweight',180,'Saud Khan','Syed Imad Uddin','Syed Imad Uddin','TKO',1,71,'COMPLETED','final','Imported from the WDS fight sheet.','Teams Relentless','Mumbai, Maharashtra, India','STAR MMA CLUB','HYDERABAD, TELANGANA, India'),
      ('wds-fight-night-14',13,null,'AMATEUR','MMA','Flyweight',180,'Santosh Yadav','Nikhil Thapa','Santosh Yadav','DECISION_SPLIT',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','ONE PUNCH MMA','Mumbai, Maharashtra, India','Combat fitness clan','Margao, Goa, India'),
      ('wds-fight-night-14',14,null,'AMATEUR','MMA','Catchweight',180,'Igor Smart','Qaazim Sheikh','Igor Smart','DECISION_SPLIT',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Tribal warriors','Calangute , Goa, India','Combat fitness center','Mumbai, Maharashtra, India'),
      ('wds-fight-night-14',15,null,'PROFESSIONAL','MMA','Flyweight',300,'Sandeep Baghel','Anubhav Kashyap','Anubhav Kashyap','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','SHUBHAM''S MMA HYDERABAD','Bhind Madhya Pradesh India','Crosstrain fight club Delhi','Faizabad Uttar Pradesh india'),
      ('wds-fight-night-14',16,null,'PROFESSIONAL','MMA','Catchweight',300,'Akash Rathod','Gurkirat Singh Gill','Gurkirat Singh Gill','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','Dragon combat sports academy','Valsad, gujrat, india','Elite Fight City MMA And Fitness (EFCMMAFITNESS)','Ajnala (Amritsar), Punjab india'),
      ('wds-fight-night-14',17,null,'PROFESSIONAL','MMA','Bantamweight',300,'Suraj Patkar','Tulashidas Ningombam','Tulashidas Ningombam','TKO',1,268,'COMPLETED','final','Imported from the WDS fight sheet.','MMA Warriors','Thane maharashtra india','Rmx','Thoubal manipur india'),
      ('wds-fight-night-14',18,null,'PROFESSIONAL','MMA','Flyweight',300,'Shivaraj Basappa','Ashish Rawat','Ashish Rawat','RNC',3,203,'COMPLETED','final','Imported from the WDS fight sheet.','Combat Galaxy','Bengaluru, karnataka india','Crosstrain fight club Noida','Nagpur Maharashtra, India'),
      ('wds-fight-night-14',19,null,'PROFESSIONAL','MMA','Bantamweight',300,'Ashok Bagde','Karan Singh','Ashok Bagde','SUBMISSION',1,157,'COMPLETED','final','Imported from the WDS fight sheet.','FIT AND FIGHT CLUB','Navi Mumbai, Maharashtra, India','Combat fitness center','Mumbai, Maharashtra, India'),
      ('wds-fight-night-4',1,null,'AMATEUR','MMA','Featherweight',180,'Sarthik Hegde','Akash Chawhan','Sarthik Hegde','RNC',2,60,'COMPLETED','final','Imported from the WDS fight sheet.','Fit & Fight Club','Navi Mumbai, Maharashtra, India','Buddhist Kung Fu','Ghazipur, Uttar Pradesh, India'),
      ('wds-fight-night-4',2,null,'AMATEUR','MMA','Bantamweight',180,'Ramjali Manoj','Chandiran Thirubala','Chandiran Thirubala','DECISION_SPLIT',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Evolution MMA','Mumbai, Maharashtra, India','Dynamic 101','Thiruvallur, Tamil Nadu, India'),
      ('wds-fight-night-4',3,null,'AMATEUR','MMA','Strawweight',180,'Dhruv Shirodkar','Vikas Gupta','Dhruv Shirodkar','DECISION_SPLIT',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Zen Fitness Studio','Mumbai, Maharashtra, India',null,'Mumbai, Maharashtra, India'),
      ('wds-fight-night-4',4,null,'AMATEUR','MMA','Flyweight',180,'Zubair Mohammed','Harsh Pandya','Harsh Pandya','SUBMISSION',2,120,'COMPLETED','final','Imported from the WDS fight sheet.','Star MMA','Hyderabad, Telangana, India','Team Relentless','Ahmedabad, Gujarat, India'),
      ('wds-fight-night-4',5,null,'AMATEUR','MMA','Lightweight',180,'Sayed Mohammed','Suyash Jadhav','Suyash Jadhav','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Star MMA','Hyderabad, Telangana, India','Fit & Fight Club','Navi Mumbai, Maharashtra, India'),
      ('wds-fight-night-4',6,null,'PROFESSIONAL','MMA','Heavyweight',300,'Ranveer','Gaganpal Singh Dua','Gaganpal Singh Dua','TKO',1,30,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Mumbai, Maharashtra, India','Ras MMA','Bengaluru, Karnataka, India'),
      ('wds-fight-night-4',7,null,'PROFESSIONAL','MMA','Middleweight',300,'Jayesh Pandey','Omkar Pawar','Omkar Pawar','KO_HEAD',1,18,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Mumbai, Maharashtra, India',null,'Mumbai, Maharashtra, India'),
      ('wds-fight-night-4',8,null,'PROFESSIONAL','MMA','Flyweight',300,'Sagar Kashyap','Mahesh Lad','Sagar Kashyap','TKO',1,96,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Saharanpur, Uttar Pradesh, India',null,'Mumbai, Maharashtra, India'),
      ('wds-fight-night-4',9,null,'PROFESSIONAL','MMA','Strawweight',300,'Bambam Thounaujam','Santosh Bag','Santosh Bag','SUBMISSION',1,132,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Imphal, Manipur, India',null,'Mumbai, Maharashtra, India'),
      ('wds-fight-night-4',10,null,'PROFESSIONAL','MMA','Welterweight',300,'Sujit Gund','Prathamesh Deshpande','Prathamesh Deshpande','TKO',1,87,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Badlapur, Maharashtra, India','Fit & Fight Club','Nagpur, Maharashtra, India'),
      ('wds-fight-night-4',11,null,'PROFESSIONAL','MMA','Flyweight',300,'Ajay Payal','Fahad Khan','Fahad Khan','TKO',3,269,'COMPLETED','final','Imported from the WDS fight sheet.','Hulk MMA','Haridwar, Uttarakhand, India','Team Relentless','Kushinagar, Uttar Pradesh, India'),
      ('wds-fight-night-4',12,null,'PROFESSIONAL','MMA','Catchweight',300,'Raj Madhesiya','Karan Chauhan','Raj Madhesiya','TKO',1,175,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Gorakhpur, Uttar Pradesh, India',null,'Pune, Maharashtra, India'),
      ('wds-fight-night-4',13,null,'PROFESSIONAL','MMA','Flyweight',300,'Arun Bist','Manthan Rane','Manthan Rane','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Amritsar, Punjab, India','Team Relentless','Mumbai, Maharashtra, India'),
      ('wds-fight-night-5',1,null,'PROFESSIONAL','MMA','Featherweight',300,'Tribhuvan Issar','Rishabh Patel',null,'MAJORITY_DRAW',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','Koi Combat Academy','Dehradun, Uttarakhand, India','Fight of Knights','Indore, Madhya Pradesh, India'),
      ('wds-fight-night-5',2,null,'PROFESSIONAL','MMA','Flyweight',300,'Raju K M','Vikas Jaiswar','Raju K M','SUBMISSION',1,35,'COMPLETED','final','Imported from the WDS fight sheet.','ICSA','Bhubaneswar, Odisha, India','Pro Warrior MMA','Mumbai, Maharashtra, India'),
      ('wds-fight-night-5',3,null,'PROFESSIONAL','MMA','Flyweight',300,'Prashant Patel','Jeko Laishram','Jeko Laishram','SUBMISSION',2,286,'COMPLETED','final','Imported from the WDS fight sheet.','ICSA','Gopalganj, Bihar, India','RMX','Thoubal, Manipur, India'),
      ('wds-fight-night-5',4,null,'PROFESSIONAL','MMA','Lightweight',300,'Nishant Karkera','Shiv Kumar',null,'NO_CONTEST',null,null,'COMPLETED','final','Imported from the WDS fight sheet.','MMA Warriors','Thane, Maharashtra, India','Crosstrain','New delhi, Delhi, India'),
      ('wds-fight-night-5',5,null,'PROFESSIONAL','MMA','Featherweight',300,'Niranjan Singh','Rehan Lulla','Rehan Lulla','DECISION_SPLIT',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','Koi Combat Academy','Jiribam, Manipur, India','Team Relentless','Mumbai, Maharashtra, India'),
      ('wds-fight-night-5',6,null,'PROFESSIONAL','MMA','Strawweight',300,'Vikas Gupta','Sagar Kashyap','Sagar Kashyap','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','Pro Warrior MMA','Mumbai, Maharashtra, India','Fitness Factory','Saharanpur, Uttar Pradesh, India'),
      ('wds-fight-night-5',7,null,'PROFESSIONAL','MMA','Heavyweight',300,'Zaid Sayyed Shaikh','Gaganpal Singh Dua','Gaganpal Singh Dua','TKO',1,94,'COMPLETED','final','Imported from the WDS fight sheet.','Team Viper','Mumbai, Maharashtra, India','Koi Combat Academy','Bengaluru, Karnataka, India'),
      ('wds-fight-night-6',1,null,'PROFESSIONAL','MMA','Bantamweight',300,'Siddharth Kothapalli','Mohan Gorle','Siddharth Kothapalli','RNC',1,80,'COMPLETED','final','Imported from the WDS fight sheet.','Team Relentless','Hyderabad, Andhra Pradesh, India','Fit crew','Vizianagaram, Andhra Pradesh, India'),
      ('wds-fight-night-6',2,null,'PROFESSIONAL','MMA','Featherweight',300,'Ketan Gharat','Savar Basarimarad','Savar Basarimarad','TKO',1,160,'COMPLETED','final','Imported from the WDS fight sheet.','Fit & Fight Club','Navi Mumbai, Maharashtra, India','Brute MMA','Thane, Maharashtra, India'),
      ('wds-fight-night-6',3,null,'PROFESSIONAL','MMA','Welterweight',300,'Kimson Tony','Prathamesh Deshpande','Prathamesh Deshpande','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','Reign MMA','Kolkata, West Bengal, India','Fit and Fight club','Navi Mumbai, Maharashtra, India'),
      ('wds-fight-night-6',4,null,'PROFESSIONAL','MMA','Flyweight',300,'Jeko Laishram','Gautam Moyong','Jeko Laishram','RNC',3,198,'COMPLETED','final','Imported from the WDS fight sheet.','RMX','Thoubal, Manipur, India','Dojang MMA','Guwahati, Assam, India'),
      ('wds-fight-night-6',5,null,'PROFESSIONAL','MMA','Featherweight',300,'Thirubalachandran D','Tribhuvan Issar','Thirubalachandran D','KO_HEAD',1,16,'COMPLETED','final','Imported from the WDS fight sheet.','Dynamic MMA 101','Chennai, Tamil Nadu, India','Koi Combat','Dehradun, Uttarakhand, India'),
      ('wds-fight-night-6',6,null,'PROFESSIONAL','MMA','Featherweight',300,'Karan Chauhan','Nishant Karkera','Nishant Karkera','TKO',1,170,'COMPLETED','final','Imported from the WDS fight sheet.','Team Relentless','Mumbai, Maharashtra, India','MMA Warriors','Thane, Maharashtra, India'),
      ('wds-fight-night-6',7,null,'PROFESSIONAL','MMA','Strawweight',300,'Prathamesh Kenjale','Kerobin Tudu','Prathamesh Kenjale','RNC',2,41,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight club','Navi Mumbai, Maharashtra, India','Veds MMAAcademy','Giridih, Jharkhand, India'),
      ('wds-fight-night-6',8,null,'PROFESSIONAL','MMA','Flyweight',300,'Sunny Khatri','Mukul Anand','Sunny Khatri','RNC',3,99,'COMPLETED','final','Imported from the WDS fight sheet.','Warriors Cove','Mumbai, Maharashtra, India','Elegant Warrior','Jwalapur, Uttarakhand, India'),
      ('wds-fight-night-6',9,null,'PROFESSIONAL','MMA','Featherweight',300,'Thirubalachandran D','Nishant Karkera','Nishant Karkera','TKO',1,120,'COMPLETED','final','Imported from the WDS fight sheet.','Dynamic MMA 101','Chennai, Tamil Nadu, India','MMA Warriors','Thane, Maharashtra, India'),
      ('wds-fight-night-7',1,null,'PROFESSIONAL','MMA','Featherweight',300,'Karan Chauhan','Gaurav Kumar Rai','Karan Chauhan','RNC',1,27,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Mumbai, Maharashtra, India',null,'Kotha, Rajasthan, India'),
      ('wds-fight-night-7',2,null,'PROFESSIONAL','MMA','Bantamweight',300,'Ganeshraj Srinivasan','Siddharth Kothapalli','Ganeshraj Srinivasan','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Kancheepuram, Tamil Nadu, India',null,'Mumbai, Maharashtra, India'),
      ('wds-fight-night-7',3,null,'PROFESSIONAL','MMA','Catchweight',300,'Wasim Arsalan Malik','Prathamesh Deshpande','Prathamesh Deshpande','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Mumbai, Maharashtra, India','Cobra Thai','Nagpur, Maharashtra, India'),
      ('wds-fight-night-7',4,null,'PROFESSIONAL','MMA','Strawweight',300,'Radha Gupta','Surbala Devi Laishram','Surbala Devi Laishram','TKO',1,17,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Indore, Madhya Pradesh, India','Koi Combat Academy','Thoubal, Manipur, India'),
      ('wds-fight-night-7',5,null,'PROFESSIONAL','MMA','Bantamweight',300,'Naina Mohammed','Chandiran Thirubala','Naina Mohammed','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','Combat Kinetics','Chennai, Tamil Nadu, India',null,'Tiruvallur, Tamil Nadu, India'),
      ('wds-fight-night-7',6,'Amateur Tournament Final','AMATEUR','MMA','Lightweight',180,'Lourembam Inaona','Rayyan Butt','Rayyan Butt','RNC',2,157,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Bishnupur, Manipur, India','Team Relentless','Mumbai, Maharashtra, India'),
      ('wds-fight-night-7',7,'Amateur Tournament Final','AMATEUR','MMA','Featherweight',180,'Ashok Bagde','Venu Vardhan','Ashok Bagde','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Cobra Thai','Thane, Maharashtra, India',null,'Mysore, Karnataka, India'),
      ('wds-fight-night-7',8,'Amateur Tournament Final','AMATEUR','MMA','Flyweight',180,'Karan Mehro','Himanshu Madan Bisht','Himanshu Madan Bisht','RNC',1,98,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Bokaro, Jharkhand, India',null,'Palghar, Maharashtra, India'),
      ('wds-fight-night-7',9,'Amateur Tournament Final','AMATEUR','MMA','Strawweight',180,'Sahil Shaikh','Vidhant Panchal','Vidhant Panchal','RNC',3,71,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Mumbai, Maharashtra, India','Team Relentless','Mumbai, Maharashtra, India'),
      ('wds-fight-night-7',10,'Amateur Tournament Final','AMATEUR','MMA','Bantamweight',180,'Milan Moirangthem','Prashant Jha','Prashant Jha','SUBMISSION',1,79,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Imphal, Manipur, India','Ultimate Fitness','Mumbai, Maharashtra, India'),
      ('wds-fight-night-8',1,null,'AMATEUR','MMA','Strawweight',180,'Nirjala Badaliya','Shad Anwari','Nirjala Badaliya','SUBMISSION',2,96,'COMPLETED','final','Imported from the WDS fight sheet.','Warriors Fitness','Mumbai, Maharashtra, India','Hunters MMA','Vadodara,Gujarat, India'),
      ('wds-fight-night-8',2,null,'AMATEUR','MMA','Middleweight',180,'Ayaan Baig','Fahim Baig','Fahim Baig','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Dassault MMA','Mumbai, Maharashtra, India','Warriors Fitness','Thane, Maharashtra, India'),
      ('wds-fight-night-8',3,null,'AMATEUR','MMA','Flyweight',180,'Swapnil Shinde','Igor Smart','Igor Smart','KO_HEAD',2,91,'COMPLETED','final','Imported from the WDS fight sheet.','S S Martial Arts','Mumbai, Maharashtra, India','Tribal Warriors','Sangolda, Goa, India'),
      ('wds-fight-night-8',4,null,'AMATEUR','MMA','Featherweight',180,'Parth Langde','Shakib Sayyed','Parth Langde','SUBMISSION',1,131,'COMPLETED','final','Imported from the WDS fight sheet.','Fight Elite','Mumbai, Maharashtra, India','Brawlers MMA','Mumbai, Maharashtra, India'),
      ('wds-fight-night-8',5,null,'AMATEUR','MMA','Lightweight',180,'Durga Bishwakarma','Hirida Thapa','Durga Bishwakarma','DECISION_MAJORITY',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Tashi''s Pro MMA','Calangute, Goa, India','Team Relentless','Mumbai, Maharashtra, India'),
      ('wds-fight-night-8',6,null,'AMATEUR','MMA','Flyweight',180,'Himanshu Madan Bisht','Naheem Abdul','Himanshu Madan Bisht','TKO',1,164,'COMPLETED','final','Imported from the WDS fight sheet.','Muscle factory','Palghar, Maharashtra, India','Leos Fitness','Madikeri, Karnataka, India'),
      ('wds-fight-night-8',7,null,'AMATEUR','MMA','Catchweight',180,'Om Waghmare','Jeeva Seniappan','Om Waghmare','RNC',3,84,'COMPLETED','final','Imported from the WDS fight sheet.','Warriors Fitness','Mumbai, Maharashtra, India','Everlast Brave','Chennai,Tamil Nadu, India'),
      ('wds-fight-night-8',8,null,'AMATEUR','MMA','Lightweight',180,'Rogith Raja','Pruthvi Gulla','Pruthvi Gulla','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Chennai MMA','Chennai,Tamil Nadu, India','Team Relentless','Mumbai, Maharashtra, India'),
      ('wds-fight-night-8',9,null,'PROFESSIONAL','MMA','Welterweight',300,'Purushothaman M K','Virendra Baghel','Purushothaman M K','SUBMISSION',1,245,'COMPLETED','final','Imported from the WDS fight sheet.','Chennai MMA','Chennai,Tamil nadu, India','Team Viper','Agra, Uttar Pradesh, India'),
      ('wds-fight-night-8',10,null,'PROFESSIONAL','MMA','Bantamweight',300,'Waheeb Wakeel','Siddharth Kothapalli','Siddharth Kothapalli','SUBMISSION',3,128,'COMPLETED','provisional','Method missing on the fight sheet ("Kothapalli") — check and finalize.','ICSA','Bengaluru ,Karnataka, India','Team Relentless','Mumbai, Maharashtra, India'),
      ('wds-fight-night-8',11,null,'PROFESSIONAL','MMA','Flyweight',300,'Lakhi Das','Veronika Partikova','Lakhi Das','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','Team Relentless','Guwahati ,Assam, India',null,'Phuket,Thailand'),
      ('wds-fight-night-8',12,null,'PROFESSIONAL','MMA','Flyweight',300,'Arun Bist','Thengal Ranjan','Thengal Ranjan','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','Apex MMA','Amritsar, Punjab, India','ACE MMA','Bengaluru ,Karnataka, India'),
      ('wds-fight-night-9',1,null,'AMATEUR','MMA','Featherweight',180,'Shaheen Commando','Vignesh T','Shaheen Commando','TKO',1,130,'COMPLETED','final','Imported from the WDS fight sheet.','FIT & FIGHT CLUB','Mumbai, Maharashtra, India','DYNAMICS 101 MMA','Tiruvallur, Tamil Nadu, India'),
      ('wds-fight-night-9',2,null,'AMATEUR','MMA','Flyweight',180,'Pratim Waghmode','Havish Reddy','Havish Reddy','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','INDEPENDENT','Yavatmal, Maharashtra, India','KAIZEN MMA','Bengaluru, Karnataka, India'),
      ('wds-fight-night-9',3,null,'AMATEUR','MMA','Lightweight',180,'Sarthik Hegde','Shivam Dubey','Sarthik Hegde','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','FIT & FIGHT CLUB','Mumbai, Maharashtra, India','FIT & FIGHT CLUB','Mumbai, Maharashtra, India'),
      ('wds-fight-night-9',4,null,'AMATEUR','MMA','Strawweight',180,'Nikhil Thapa','Dhruv Shirodkar','Nikhil Thapa','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','COMBAT FITNESS CLAN','Margaon, Goa, India','ZEN KICKBOXING','Mumbai, Maharashtra, India'),
      ('wds-fight-night-9',5,null,'AMATEUR','MMA','Bantamweight',180,'Parth Langde','Ashok Bagde','Ashok Bagde','TKO',1,180,'COMPLETED','final','Imported from the WDS fight sheet.','TEAM RELENTLESS','Mumbai, Maharashtra, India','FIT & FIGHT CLUB','Mumbai, Maharashtra, India'),
      ('wds-fight-night-9',6,null,'PROFESSIONAL','MMA','Bantamweight',300,'Thoidingjam Goroba Singh','Tulashidas Ningombam','Tulashidas Ningombam','SUBMISSION',1,169,'COMPLETED','final','Imported from the WDS fight sheet.','Aztecs Sports & Fight Studio','Imphal, Manipur, India','RMX MMA','Imphal, Manipur, India'),
      ('wds-fight-night-9',7,null,'PROFESSIONAL','MMA','Bantamweight',300,'Karandeep Singh','Siddharth Kothapalli','Siddharth Kothapalli','SUBMISSION',1,282,'COMPLETED','final','Imported from the WDS fight sheet.','SIKH WARRIOR PUNJAB','Gurdaspur, Punjab, India','TEAM RELENTLESS','Hyderabad, Andhra Pradesh, India'),
      ('wds-fight-night-9',8,null,'PROFESSIONAL','MMA','Featherweight',300,'Rishabh Patel','Lionel Mascarenhas','Lionel Mascarenhas','TKO',2,142,'COMPLETED','final','Imported from the WDS fight sheet.','FOK INDORE','Indore, Madhya Pradesh, India','AKA MANDREM BEACH','Mumbai, Maharashtra, India'),
      ('wds-fight-night-9',9,null,'PROFESSIONAL','MMA','Bantamweight',300,'Satgunhao Kipgen','Shoaib Khan','Shoaib Khan','DECISION_UNANIMOUS',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','ULTIMATE FITNESS/GCA','Imphal, Manipur, India','COMBAT FITNESS CLAN','Panjim, Goa, India'),
      ('wds-fight-night-9',10,null,'PROFESSIONAL','MMA','Flyweight',300,'Maruf Alam Shaikh','Aaquib Javid','Aaquib Javid','RNC',1,134,'COMPLETED','final','Imported from the WDS fight sheet.','BREAK METHOD MMA','Mumbai, Maharashtra, India','ACE MMA','Bengaluru, Karnataka, India'),
      ('wds-fight-night-9',11,null,'PROFESSIONAL','MMA','Lightweight',300,'Rudy Tshisuaka','Krishna Payasi','Krishna Payasi','DECISION_SPLIT',3,300,'COMPLETED','final','Imported from the WDS fight sheet.','TRIPL3 MMA','Dubai, UAE','ACE MMA','Satna, Madhya Pradesh, India'),
      ('wds-rising-star-1',1,null,'AMATEUR','MMA','Flyweight',180,'Ramit Jaiswal','Rajat Diwedi','Rajat Diwedi','DECISION_SPLIT',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fighter Combat Club','Mumbai, Maharashtra, India','Cobra-Thai MMA','Pune, Maharashtra, India'),
      ('wds-rising-star-1',2,null,'AMATEUR','MMA','Flyweight',180,'Satya Sai Kartikeya','Evansraj Jagateesan','Satya Sai Kartikeya','RNC',1,130,'COMPLETED','final','Imported from the WDS fight sheet.','Wartribe',null,'Fit & Fight Club','Navi Mumbai, Maharashtra, India'),
      ('wds-rising-star-1',3,null,'AMATEUR','MMA','Strawweight',180,'Marshal Khimta','Junaid Shaikh','Marshal Khimta','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Beast ITT','Shimla, Himachal Pradesh, India','SS Martial Arts','Nashik, Maharashtra, India'),
      ('wds-rising-star-1',4,null,'AMATEUR','MMA','Catchweight',180,'Akshay Shinde','Shivam Dubey','Akshay Shinde','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Cobra-Thai MMA','Pune, Maharashtra, India','Fit & Fight Club','Navi Mumbai, Maharashtra, India'),
      ('wds-rising-star-1',5,null,'AMATEUR','MMA','Bantamweight',180,'Venkatesh Niwas','Mrutunjay Madhal','Venkatesh Niwas','RNC',3,81,'COMPLETED','final','Imported from the WDS fight sheet.','Combat 360','Mumbai, Maharashtra, India','Fit & Fight Club','Mumbai, Maharashtra, India'),
      ('wds-rising-star-1',6,null,'AMATEUR','MMA','Flyweight',180,'Swapnil Shinde','Himanshu Madan Bisht','Himanshu Madan Bisht','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.',null,null,'Team Spartan','Bhoisar, Maharashtra, India'),
      ('wds-rising-star-1',7,null,'AMATEUR','MMA','Featherweight',180,'Parth Langde','Bhim Singh','Bhim Singh','TKO',1,30,'COMPLETED','final','Imported from the WDS fight sheet.',null,null,'Beast ITT','Kullu, Himachal Pradesh, India'),
      ('wds-rising-star-1',8,null,'AMATEUR','MMA','Catchweight',180,'Fahim Baig','Adnan Khan','Adnan Khan','TKO',2,143,'COMPLETED','final','Imported from the WDS fight sheet.','Warrior''s Fitness Center','Thane, Maharashtra, India','Warrior''s Fitness Club','Mumbai, Maharashtra, India'),
      ('wds-rising-star-1',9,null,'AMATEUR','MMA','Bantamweight',180,'Mutharasan','Ashok Bagde','Ashok Bagde','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Wartribe',null,'Fit & Fight Club','Navi Mumbai, Maharashtra, India'),
      ('wds-rising-star-2',2,null,'AMATEUR','MMA','Cruiserweight',180,'Gaurav Singh','Aman Pawar','Aman Pawar','TKO',2,130,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight club','Navi Mumbai Maharashtra, India','Revolution Fitness Club','Alibag, Maharashtra, India'),
      ('wds-rising-star-2',3,null,'AMATEUR','MMA','Featherweight',180,'Vraj Dattani','Santosh Kumar','Santosh Kumar','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fighter combat club','Mumbai, Maharastra, India','Valhalla Tactical India','Jammu, Jammu and Kashmir, India'),
      ('wds-rising-star-2',4,null,'AMATEUR','MMA','Lightweight',180,'Sudip Jamatia','Ashish Thakur','Sudip Jamatia','TKO',1,110,'COMPLETED','final','Imported from the WDS fight sheet.','TRIPURA LEGENDS','AGARTALA, TRIPURA, India','ASB academy','Mumbai, Maharastra, India'),
      ('wds-rising-star-2',5,null,'AMATEUR','MMA','Middleweight',180,'Shreyaas Patil','Praveen Nayak','Shreyaas Patil','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Navi Mumbai Maharashtra, India','Shoorveer Academy','Hyderabad,Telangana , India'),
      ('wds-rising-star-2',6,null,'AMATEUR','MMA','Flyweight',180,'Vijay Yadav','Sagar Ramdas Dange','Sagar Ramdas Dange','DECISION_MAJORITY',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit & fight club','Navi mumbai, Maharashtra, India','Fit and Fight club','Navi mumbai, Maharashtra, India'),
      ('wds-rising-star-2',7,null,'AMATEUR','MMA','Strawweight',180,'Viraj Dhore','Syed Ismail',null,null,null,null,'CANCELLED','none','Walkover — Viraj Dhore advanced (no fight took place).','Cobra thai','Pune , Maharashtra, India','Striking stars','Banglore, Karnataka, India'),
      ('wds-rising-star-2',8,null,'AMATEUR','MMA','Featherweight',180,'Shivam Dubey','Pratik Agrahari','Shivam Dubey','RNC',1,123,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Navi mumbai, Maharastra, India','Shoolin sports academy','Mumbai, Maharastra, India'),
      ('wds-rising-star-2',9,null,'AMATEUR','MMA','Bantamweight',180,'Anurag Bhambal','Sujal Lakhnotra','Anurag Bhambal','SUBMISSION',3,100,'COMPLETED','final','Imported from the WDS fight sheet.','Roy MMA academy','Bhopal Madhya Pradesh, India','Valhalla tactical india','Jammu , jammu kashmir, India'),
      ('wds-rising-star-3',1,null,'AMATEUR','MMA','Bantamweight',180,'Sujal Balasaheb Gite','Bhumi Kanwar','Bhumi Kanwar','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','GANIMIKAWA MIXED MARTIAL ARTS','Pune , Maharashtra, India','MAIDAAN MMA','Pune , Maharashtra, India'),
      ('wds-rising-star-3',2,null,'AMATEUR','MMA','Bantamweight',180,'Pranav Jadhav','Mrutunjay Madhal','Pranav Jadhav','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Notorious club','Mumbai , Maharashtra, India','Fit and fight club','Mumbai , Maharashtra, India'),
      ('wds-rising-star-3',3,null,'AMATEUR','MMA','Flyweight',180,'Sukhjeet Singh Panesar','Venkatesh Iyer','Sukhjeet Singh Panesar','DECISION_SPLIT',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Ultimate Fitness MMA','Mumbai , Maharashtra, India','P Town West',null),
      ('wds-rising-star-3',4,null,'AMATEUR','MMA','Strawweight',180,'Rizwansab Mudgal','Viraj Dhore','Rizwansab Mudgal','DQ',1,155,'COMPLETED','final','Imported from the WDS fight sheet.','Anjuna,Goa, India','Tribal Warriors','Cobra thai','Pune , Maharashtra, India'),
      ('wds-rising-star-3',5,null,'AMATEUR','MMA','Bantamweight',180,'Abhishek Nishad','Aryan Sawant','Abhishek Nishad','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Ultimate fitness MMA','Gorakhpur , Uttar Pradesh , INDIA','P Town West MMA','Pune , Maharashtra, India'),
      ('wds-rising-star-3',6,null,'AMATEUR','MMA','Strawweight',180,'Nayan Mandlik','Bhakti Jayesh Katudia','Nayan Mandlik','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight Club','Mumbai , Maharashtra, India','Ultimate fitness Mma','Mumbai , Maharashtra, India'),
      ('wds-rising-star-3',7,null,'AMATEUR','MMA','Catchweight',180,'Reeyan Siddiqui','Fahim Baig','Fahim Baig','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Combat 360','Mumbai , Maharashtra, India','Combat fitness centre','Thane , Maharashtra, India'),
      ('wds-rising-star-3',8,null,'AMATEUR','MMA','Strawweight',180,'Nikhil Thapa','Suryansh Pathak','Nikhil Thapa','TKO',1,134,'COMPLETED','final','Imported from the WDS fight sheet.','Combat fitness clan','Margaon, Goa, India','Tribal Warriors','Anjana, Goa, India'),
      ('wds-rising-star-3',9,null,'AMATEUR','MMA','Flyweight',180,'Vijay Yadav','Preshit Golait','Vijay Yadav','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and Fight Club','Mumbai , Maharashtra, India','Roy MMA Academy','Bhopal Madhya Pradesh India'),
      ('wds-rising-star-4',1,null,'AMATEUR','MMA','Flyweight',180,'Fouz Kashelkar','Arjun BK','Arjun BK','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Nsc nizampur sports club','Bhiwandi, Maharashtra, India','Fighter combat club','Mumbai, Maharashtra, India'),
      ('wds-rising-star-4',2,null,'AMATEUR','MMA','Featherweight',180,'Devansh Raval','Gaurav Kiran Tate','Gaurav Kiran Tate','KO_HEAD',1,176,'COMPLETED','final','Imported from the WDS fight sheet.','Fight club Ahmedabad','Ahmedabad, Gujarat, India','Fit and fight club','Panvel, Maharashtra, India'),
      ('wds-rising-star-4',3,null,'AMATEUR','MMA','Bantamweight',180,'Aryan Sawant','Satyaprakash Rajbhar','Satyaprakash Rajbhar','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','P-Town West MMA','Pune, Maharashtra, India','Fit and fight club','Mumbai , Maharashtra, India'),
      ('wds-rising-star-4',4,null,'AMATEUR','MMA','Featherweight',180,'Mohit Sharma','Arif Nawar','Arif Nawar','RNC',2,158,'COMPLETED','final','Imported from the WDS fight sheet.','Fighter combat club','Mumbai, Maharashtra, India','Combat fitness clan','Margoa,Goa, India'),
      ('wds-rising-star-4',5,null,'AMATEUR','MMA','Bantamweight',180,'Aryan Singh','Praveen Pawar','Aryan Singh','RNC',1,172,'COMPLETED','final','Imported from the WDS fight sheet.','Team grit','Mumbai, Maharashtra, India','GANIMIKAWA MIX MARTIAL ARTS','Pune,Maharashtra, India'),
      ('wds-rising-star-4',6,null,'AMATEUR','MMA','Strawweight',180,'Krishna Gupta','Suryansh Pathak','Krishna Gupta','SUBMISSION',1,47,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Mumbai , Maharashtra, India','Tribal Warriors','Anjuna,Goa, India'),
      ('wds-rising-star-4',7,null,'AMATEUR','MMA','Flyweight',180,'Vijay Yadav','Sagar Ramdas Dange','Sagar Ramdas Dange','RNC',2,79,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Mumbai , Maharashtra, India','Fit and fight club','Mumbai , Maharashtra, India'),
      ('wds-rising-star-4',8,null,'AMATEUR','MMA','Bantamweight',180,'Musharraf Khan','Abhijeet Singh Saini','Musharraf Khan','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Brute MMA & Fitness','Thane, Maharashtra, India','Team relentless','Mumbai , Maharashtra, India'),
      ('wds-rising-star-5',1,null,'AMATEUR','MMA','Featherweight',180,'Gaurav Kiran Tate','Khalid Khan','Khalid Khan','TKO',2,156,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Navi Mumbai, Maharashtra, India','Combat fitness centre','Mumbai, Maharashtra, India'),
      ('wds-rising-star-5',2,null,'AMATEUR','MMA','Flyweight',180,'Shuaib Ali','Evansraj Jagateesan','Evansraj Jagateesan','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.',null,'Calangute, Goa, India','Fit and fight club','Navi Mumbai, Maharashtra, India'),
      ('wds-rising-star-5',3,null,'AMATEUR','MMA','Flyweight',180,'Shoaib Shaikh','Sarvesh Chavan','Shoaib Shaikh','TKO',2,160,'COMPLETED','final','Imported from the WDS fight sheet.','Combat fitness centre','Mumbra, Maharashtra, India','Dassault MMA','Mumbai, Maharashtra, India'),
      ('wds-rising-star-5',4,null,'AMATEUR','MMA','Flyweight',180,'Awwab Khot','Rishab Naik','Awwab Khot','KO_HEAD',2,90,'COMPLETED','final','Imported from the WDS fight sheet.','Arshiyan memon martial art academy','Bhiwandi, Maharashtra, India',null,'North Goa ,Goa'),
      ('wds-rising-star-5',5,null,'AMATEUR','MMA','Catchweight',180,'Shivam Dubey','Satyam Mishra','Shivam Dubey','DECISION_SPLIT',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Navi Mumbai, Maharashtra, India','Brute mma','Thane, Maharashtra, India'),
      ('wds-rising-star-5',6,null,'AMATEUR','MMA','Bantamweight',180,'Prem Katurde','Satyaprakash Rajbhar','Satyaprakash Rajbhar','TKO',1,110,'COMPLETED','final','Imported from the WDS fight sheet.','Downtown mma','Mumbai, Maharashtra, India','FIT & FIGHT CLUB','Thane, Maharashtra, India'),
      ('wds-rising-star-5',7,null,'AMATEUR','MMA','Lightweight',180,'Pruthvi Gulla','Hemant Shokeen','Pruthvi Gulla','TKO',2,140,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Navi Mumbai, Maharashtra, India','Self','New Delhi, India'),
      ('wds-rising-star-5',8,null,'AMATEUR','MMA','Flyweight',180,'Akash Chauhan','Vijay Yadav','Vijay Yadav','CORNER_STOPPAGE',1,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fight Elite','Mumbai, Maharashtra, India','Fit & fight club','Mumbai, Maharashtra, India'),
      ('wds-rising-star-5',9,null,'AMATEUR','MMA','Bantamweight',180,'Ashish Maurya','Ishaan Ghadke','Ashish Maurya','DECISION_UNANIMOUS',3,180,'COMPLETED','final','Imported from the WDS fight sheet.','Fit and fight club','Mumbai, Maharashtra, India',null,'Thane, Maharashtra, India')
    ) as t(slug, n, label, kind, disc, division, secs, blue, red, winner, result, end_round, end_sec, bstatus, rstatus, note,
           blue_team, blue_city, red_team, red_city)
    order by slug, n
  loop
    continue when r.slug = any(skip_events);
    select id, event_date into ev from public.events where slug = r.slug;
    if ev.id is null then raise notice 'Event % not found', r.slug; continue; end if;

    select id into a from public.fighters where name_key = lower(regexp_replace(trim(r.blue), '\s+', ' ', 'g')) order by created_at limit 1;
    if a is null then
      insert into public.fighters (name, weight_class, team, hometown) values (r.blue, r.division, r.blue_team, r.blue_city) returning id into a;
    else
      update public.fighters set team = coalesce(team, r.blue_team), hometown = coalesce(hometown, r.blue_city),
                                 weight_class = coalesce(weight_class, r.division)
       where id = a and (team is null or hometown is null or weight_class is null);
    end if;
    select id into c from public.fighters where name_key = lower(regexp_replace(trim(r.red), '\s+', ' ', 'g')) order by created_at limit 1;
    if c is null then
      insert into public.fighters (name, weight_class, team, hometown) values (r.red, r.division, r.red_team, r.red_city) returning id into c;
    else
      update public.fighters set team = coalesce(team, r.red_team), hometown = coalesce(hometown, r.red_city),
                                 weight_class = coalesce(weight_class, r.division)
       where id = c and (team is null or hometown is null or weight_class is null);
    end if;
    w := case when r.winner = r.blue then a when r.winner = r.red then c end;

    insert into public.event_fighters (event_id, fighter_id, weight_class)
      values (ev.id, a, r.division), (ev.id, c, r.division)
      on conflict do nothing;

    insert into public.bouts
      (event_id, bout_number, bout_name, bout_type, discipline, weight_class, bout_date, total_rounds, round_duration,
       current_round, status, blue_fighter_id, red_fighter_id, result_type, winner_id, end_round, end_time_sec,
       result_note, result_status, completed_at)
    values
      (ev.id, r.n, coalesce(r.label, r.division), r.kind, r.disc, r.division, ev.event_date, 3, r.secs,
       coalesce(r.end_round, case when r.bstatus = 'COMPLETED' then 3 else 0 end), r.bstatus, a, c, r.result, w, r.end_round, r.end_sec,
       r.note, r.rstatus, case when r.bstatus = 'COMPLETED' then ev.event_date::timestamptz end);
  end loop;
end $$;

-- 4. Rankings ---------------------------------------------------------------------------
select public.recompute_rankings();
