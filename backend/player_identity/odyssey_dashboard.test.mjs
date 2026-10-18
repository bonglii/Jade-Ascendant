import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {parseWib,inputWib,describeSeason,odysseyDashboard,SEASON_SECONDS} from './odyssey_dashboard.mjs';

test('WIB date input always means UTC+7, including date/year boundary',()=>{
 assert.equal(parseWib('2026-10-18T18:25'),Date.parse('2026-10-18T11:25:00Z')/1000);
 assert.equal(parseWib('2027-01-01T00:05'),Date.parse('2026-12-31T17:05:00Z')/1000);
 for(const value of ['2026-10-18T18:25','2027-01-01T00:05','2028-02-29T23:59'])assert.equal(inputWib(parseWib(value)),value);
 assert.equal(inputWib(parseWib('2026-10-18T18:25')+SEASON_SECONDS),'2026-11-01T18:25');
});
test('invalid calendar dates, missing dates and injected offsets are rejected',()=>{
 for(const value of ['', '2026-02-30T10:00','2026-13-01T10:00','2026-10-18T25:00','2026-10-18T18:25Z','2026-10-18T18:25+07:00'])assert.throws(()=>parseWib(value));
});
test('season statuses respect start, pause, end and grace boundaries',()=>{
 const e={starts_at:100,ends_at:100+SEASON_SECONDS,enabled:true};
 assert.equal(describeSeason(null,0),'Belum dijadwalkan');
 assert.equal(describeSeason(e,99),'Terjadwal');assert.equal(describeSeason(e,100),'Sedang berlangsung');
 assert.equal(describeSeason({...e,enabled:false},100),'Dijeda');
 assert.equal(describeSeason(e,e.ends_at),'Masa klaim hadiah');
 assert.equal(describeSeason(e,e.ends_at+259200),'Selesai');
});
test('rendered browser code parses and uses nonce-only CSP without inline handlers/styles',()=>{
 const script=odysseyDashboard.match(/<script nonce="__NONCE__">([\s\S]*?)<\/script>/)[1];
 assert.doesNotThrow(()=>new vm.Script(script));
 assert.doesNotMatch(odysseyDashboard,/\s(?:style|onclick|oninput)=/);
 assert.match(odysseyDashboard,/timeZone:'Asia\/Jakarta'/);
 assert.match(odysseyDashboard,/const fixed=!!published&&!creating/);
 assert.match(odysseyDashboard,/return \{\.\.\.published,enabled:/);
 assert.match(odysseyDashboard,/textContent=JSON.stringify/);
});
