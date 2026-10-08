\set ON_ERROR_STOP 1
set client_min_messages = warning;
create or replace function pg_temp.ok(cond boolean, label text) returns void language plpgsql as $$
begin if cond is not true then raise exception 'FAIL: %', label; end if; raise notice 'ok  %', label; end $$;
create or replace function pg_temp.fails(stmt text, fragment text, label text) returns void language plpgsql as $$
begin begin execute stmt; exception when others then
  if position(lower(fragment) in lower(sqlerrm)) > 0 then raise notice 'ok  % (rejected)', label; return; end if;
  raise exception 'FAIL: % — wrong error: %', label, sqlerrm; end;
  raise exception 'FAIL: % — allowed', label; end $$;
grant execute on all functions in schema pg_temp to anon, authenticated;
set client_min_messages = notice;

-- Committee example: 10 bouts, 6W (KO R1, KO R2, SUB R1, TKO R3, SUB R2, SUB R3 = 4.05), 3L, 1D
insert into events(slug,title,status,event_date) values ('formula-test','Formula test','completed','2026-09-01');
insert into fighters(name, weight_class) values ('Test Fighter','Lightweight');
insert into fighters(name, weight_class) select 'Opp '||g, 'Lightweight' from generate_series(1,10) g;
do $$
declare ev uuid := (select id from events where slug='formula-test'); me uuid := (select id from fighters where name='Test Fighter');
  spec text[] := array['W:KO_HEAD:1','W:TKO:2','W:SUBMISSION:1','W:TKO:3','W:SUBMISSION:2','W:RNC:3','L:TKO:1','L:DECISION_UNANIMOUS:3','L:SUBMISSION:2','D:DRAW:3'];
  i int; p text[]; opp uuid;
begin
  for i in 1..10 loop
    p := string_to_array(spec[i], ':'); opp := (select id from fighters where name='Opp '||i);
    insert into bouts(event_id,bout_number,weight_class,status,blue_fighter_id,red_fighter_id,result_type,winner_id,end_round,result_status)
    values (ev, i, 'Lightweight', 'COMPLETED', me, opp, p[2], case p[1] when 'W' then me when 'L' then opp end, p[3]::int, 'final');
  end loop;
end $$;
select pg_temp.ok((select wins||'-'||losses||'-'||draws from fighter_rankings fr join fighters f on f.id=fr.fighter_id where f.name='Test Fighter')='6-3-1', 'record 6-3-1');
select pg_temp.ok((select method_points from fighter_rankings fr join fighters f on f.id=fr.fighter_id where f.name='Test Fighter')=4.05, 'win method weights total 4.05');
select pg_temp.ok((select score from fighter_rankings fr join fighters f on f.id=fr.fighter_id where f.name='Test Fighter')=136.6578, 'committee example score = 136.6578 (sheet: 136.6578291)');
select pg_temp.ok((select division_rank from fighter_rankings fr join fighters f on f.id=fr.fighter_id where f.name='Test Fighter')=1, 'top of Lightweight');

-- No contest is not a fight; provisional results do not count
insert into bouts(event_id,bout_number,weight_class,status,blue_fighter_id,red_fighter_id,result_type,end_round,result_status)
  select id, 11, 'Lightweight','COMPLETED',(select id from fighters where name='Test Fighter'),(select id from fighters where name='Opp 1'),'NO_CONTEST',1,'final' from events where slug='formula-test';
select pg_temp.ok((select score from fighter_rankings fr join fighters f on f.id=fr.fighter_id where f.name='Test Fighter')=136.6578, 'no contest does not change the score');
insert into bouts(event_id,bout_number,weight_class,status,blue_fighter_id,red_fighter_id,result_type,winner_id,end_round,result_status)
  select id, 12, 'Lightweight','COMPLETED',(select id from fighters where name='Test Fighter'),(select id from fighters where name='Opp 2'),'KO_HEAD',(select id from fighters where name='Test Fighter'),1,'provisional' from events where slug='formula-test';
select pg_temp.ok((select wins from fighter_rankings fr join fighters f on f.id=fr.fighter_id where f.name='Test Fighter')=6, 'provisional win not counted');
update bouts set result_status='final' where bout_number=12 and event_id=(select id from events where slug='formula-test');
select pg_temp.ok((select score from fighter_rankings fr join fighters f on f.id=fr.fighter_id where f.name='Test Fighter')
   = round((((7*100.0/11)*0.7 + 4.80*0.3) * sqrt(11::numeric))::numeric, 4), 'finalizing a KO R1 win: 7-3-1, weights 4.80, score recalculated');

-- Round 5 finish uses the round-3 weight
select pg_temp.ok(wds_win_weight('TKO',5)=0.65 and wds_win_weight('DECISION_UNANIMOUS',5)=0.55 and wds_win_weight('TKO',null)=0.65, 'round 4/5 finishes use the R3 weight; decisions any round');

-- Correcting the finishing round recalculates
update bouts set end_round=3 where bout_number=12 and event_id=(select id from events where slug='formula-test');
select pg_temp.ok((select method_points from fighter_rankings fr join fighters f on f.id=fr.fighter_id where f.name='Test Fighter')=4.70, 'changing a final result''s round recalculates (4.80 -> 4.70)');

-- Editing a weight recalculates; access control
insert into official_invites(email,name,role) values ('p@wds.in','Promo','PROMOTER'),('j@wds.in','Judge','JUDGE');
insert into auth.users(id,email) values ('00000000-0000-0000-0000-0000000000a1','p@wds.in'),('00000000-0000-0000-0000-0000000000a2','j@wds.in');
set request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a2"}'; set role authenticated;
update ranking_method_weights set weight=9 where result_type='TKO';
reset role;
select pg_temp.ok((select max(weight) from ranking_method_weights where result_type='TKO')<1, 'judge cannot change weights');
set request.jwt.claims = '{}'; set role anon;
select pg_temp.ok((select count(*) from ranking_method_weights)=25, 'public can read the weights');
select pg_temp.fails('update ranking_method_weights set weight=1', 'permission denied', 'public cannot change weights');
reset role;
set request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1"}'; set role authenticated;
update ranking_method_weights set weight=0.60, confirmed=true where result_type='DECISION_SPLIT';
reset role;
select pg_temp.ok((select updated_by is not null and confirmed from ranking_method_weights where result_type='DECISION_SPLIT'), 'promoter edits a weight (recorded who)');
update ranking_method_weights set weight=0.80 where result_type='KO_HEAD' and round_no=1;
select pg_temp.ok((select method_points from fighter_rankings fr join fighters f on f.id=fr.fighter_id where f.name='Test Fighter')=4.75, 'editing a weight recalculates rankings immediately');
select 'ALL FORMULA TESTS PASSED';
