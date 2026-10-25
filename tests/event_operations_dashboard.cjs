'use strict';
const assert=require('node:assert/strict'),{JSDOM,VirtualConsole}=require('jsdom'),{pathToFileURL}=require('node:url'),path=require('node:path');
const root=path.resolve(__dirname,'..'),wait=()=>new Promise(r=>setTimeout(r,20));let checks=0;
const check=(ok,label)=>{assert.ok(ok,label);checks++;};
(async()=>{
 const html=(await import(pathToFileURL(root+'/backend/player_identity/dashboard.mjs'))).default;
 for(const scenario of ['valid','expired','network']){
  const errors=[],vc=new VirtualConsole();vc.on('jsdomError',e=>errors.push(e.message));
  const dom=new JSDOM(html,{url:'https://fixture.invalid/admin#view-pavilion',runScripts:'outside-only',pretendToBeVisual:true,virtualConsole:vc}),w=dom.window;
  try{
   let release;const pending=new Promise(r=>release=r);const writes=[];
   w.structuredClone=structuredClone;w.scrollTo=()=>{};w.IntersectionObserver=class{observe(){}unobserve(){}disconnect(){}};w.fetch=async(url,opts={})=>{
    if(opts.method==='POST')writes.push(url);
    if(url==='/admin/api/session'){await pending;if(scenario==='network')throw Error('offline');return{ok:scenario!=='expired',status:scenario==='expired'?401:200,json:async()=>scenario==='expired'?{error:'admin_required'}:{csrf:'fixture',account_enabled:true,username:'fixture',reward_catalog:{}}};}
    return{ok:true,status:200,json:async()=>({entries:[],banners:[],assets:[],revision:0})};
   };
   check(w.document.getElementById('login-panel').hidden,'login is hidden before any JavaScript or network completes');
   for(const s of w.document.querySelectorAll('script'))w.eval(s.textContent);
   check(w.document.getElementById('login-panel').hidden&&!w.document.getElementById('auth-check').hidden,'pending session shows neutral loading, never a login flash');
   release();await wait();await wait();
   if(scenario==='valid')check(!w.document.getElementById('studio').hidden&&w.document.getElementById('login-panel').hidden,'valid session opens Studio directly');
   if(scenario==='expired')check(!w.document.getElementById('login-panel').hidden&&w.document.getElementById('studio').hidden,'actually expired session exposes login');
   if(scenario==='network')check(w.document.getElementById('login-panel').hidden&&!w.document.getElementById('auth-retry').hidden,'network uncertainty preserves pending session and offers retry');
   check(writes.length===0&&errors.length===0,'session recovery makes no mutation and raises no browser errors');
  }finally{w.close();}
 }
 const odyssey=(await import(pathToFileURL(root+'/backend/player_identity/odyssey_dashboard.mjs'))).odysseyDashboard;
 check(odyssey.includes('class="odyssey-page"')&&!odyssey.includes('nav span,.eyebrow'),'Odyssey-specific decoration cannot restyle shared sidebar labels');
 check(!odyssey.includes('Georgia')&&odyssey.includes('Aturan &amp; jadwal event'),'Odyssey uses shared typography and exposes event rules');

 const {eventCalendarHTML,eventCalendarJS}=await import(pathToFileURL(root+'/backend/player_identity/event_calendar_dashboard.mjs'));
 const dom=new JSDOM(eventCalendarHTML,{url:'https://fixture.invalid/admin',runScripts:'outside-only'}),w=dom.window;
 try{
  let reads=0,release;const pending=new Promise(r=>release=r);w.StudioTime={formatWib:String};w.AbortController=AbortController;
  w.fetch=async()=>{const n=++reads;if(n===1)await pending;return{ok:true,json:async()=>({version:1,slots:[],conflicts:[]})}};
  w.eval(eventCalendarJS+';refreshEventCalendar();refreshEventCalendar(true);refreshEventCalendar(true);');
  check(reads===1,'calendar keeps only one in-flight read');release();await wait();await wait();
  check(reads===2,'saving while reading queues exactly one fresh calendar read');
  check(w.document.getElementById('event-calendar-status').textContent.includes('Tidak ada'),'calendar renders fresh status without editing draft');
 }finally{w.close()}
 console.log('EVENT_OPERATIONS_DASHBOARD checks='+checks+' failures=0');
})().catch(e=>{console.error(e);process.exitCode=1});
