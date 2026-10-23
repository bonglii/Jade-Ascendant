import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import vm from 'node:vm';
import {parseWib,inputWib,formatWib,nextWeeklyReset,adminTimeJS} from './admin_time.mjs';
import main from './dashboard.mjs';
import trials from './heavenly_trials_dashboard.mjs';
import {odysseyDashboard} from './odyssey_dashboard.mjs';
import {metricsDashboard} from './companion.mjs';

test('all schedules mean WIB across browser zones, year boundaries and valid leap day',()=>{
 const input=['2027-01-01T00:05','2028-02-29T23:59','2026-10-26T04:00'];
 const expected=input.map(parseWib);
 for(const tz of ['UTC','Asia/Jakarta','America/Los_Angeles','Europe/Berlin','Pacific/Auckland']){
  const code=`import {parseWib,inputWib,formatWib} from ${JSON.stringify(new URL('./admin_time.mjs',import.meta.url).href)};const a=${JSON.stringify(input)};console.log(JSON.stringify([a.map(parseWib),a.map(x=>inputWib(parseWib(x))),formatWib(parseWib(a[0]))]));`;
  const run=spawnSync(process.execPath,['--input-type=module','-e',code],{encoding:'utf8',env:{...process.env,TZ:tz}});
  assert.equal(run.status,0,run.stderr);const [seconds,roundtrip,label]=JSON.parse(run.stdout);assert.deepEqual(seconds,expected);assert.deepEqual(roundtrip,input);assert.match(label,/00\.05 WIB$/);
 }
});
test('invalid dates and injected offsets cannot become an admin schedule',()=>{
 for(const value of ['',null,123,'2026-02-29T12:00','2026-04-31T12:00','2026-13-01T12:00','2026-10-23T24:00','2026-10-23T12:00Z','2026-10-23T12:00+08:00'])assert.throws(()=>parseWib(value));
 for(const value of [-1,NaN,Infinity,1.5])assert.throws(()=>inputWib(value));
 assert.equal(formatWib(undefined),'—');
});
test('weekly helper chooses a future Monday04 WIB without double timezone conversion',()=>{
 for(const input of ['2026-10-25T23:59','2026-10-26T03:59','2026-10-26T04:00','2026-12-31T23:59']){
  const now=parseWib(input),slot=nextWeeklyReset(now);assert.ok(slot>=now+60);assert.ok(slot-now<=604860);assert.equal(inputWib(slot).slice(11),'04:00');assert.equal(new Date((slot+25200)*1000).getUTCDay(),1);
 }
});
test('browser utility runs the same functions and every dashboard script parses',()=>{
 const context=vm.createContext({Date,Intl,Object,Number,Error});vm.runInContext(adminTimeJS,context);
 assert.equal(vm.runInContext("StudioTime.parseWib('2027-01-01T00:05')",context),parseWib('2027-01-01T00:05'));
 for(const html of [main,trials,odysseyDashboard,metricsDashboard]){
  for(const match of html.matchAll(/<script nonce="__NONCE__">([\s\S]*?)<\/script>/g))assert.doesNotThrow(()=>new vm.Script(match[1]));
  assert.doesNotMatch(html,/backdrop-filter|@import\s|fonts\.googleapis|<script[^>]+src=/);
 }
});

test('one versioned CSS response is cacheable and contains presentation only',async()=>{
 const {createMailHandler}=await import('./mail.mjs');const {studioStyle,STUDIO_STYLE_PATH}=await import('./admin_studio_style.mjs');
 const handle=createMailHandler();const response=await handle(new Request('https://fixture.invalid'+STUDIO_STYLE_PATH),{});
 assert.equal(response.status,200);assert.equal(await response.text(),studioStyle);assert.match(response.headers.get('cache-control'),/immutable/);assert.equal(response.headers.get('set-cookie'),null);
 const head=await handle(new Request('https://fixture.invalid'+STUDIO_STYLE_PATH,{method:'HEAD'}),{});assert.equal(await head.text(),'');
 await assert.rejects(()=>handle(new Request('https://fixture.invalid'+STUDIO_STYLE_PATH,{method:'POST'}),{}));
 for(const html of [main,trials,odysseyDashboard,metricsDashboard])assert.ok(html.includes('href="'+STUDIO_STYLE_PATH+'"'));
 const page=await handle(new Request('https://fixture.invalid/admin'),{PROFILE_DB:{}}),html=await page.text();
 const nonce=html.match(/<link rel="stylesheet" nonce="([a-f0-9]+)"/)[1];assert.ok(page.headers.get('content-security-policy').includes("style-src 'nonce-"+nonce+"'"));
 assert.equal(page.headers.get('cache-control'),'no-store');
});
