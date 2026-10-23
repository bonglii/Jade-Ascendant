'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{pathToFileURL}=require('node:url');
const {JSDOM,VirtualConsole}=require('jsdom');
const root=path.resolve(process.argv[2]||path.join(__dirname,'..')),wait=()=>new Promise(r=>setTimeout(r,20));
(async()=>{
 const main=(await import(pathToFileURL(root+'/backend/player_identity/dashboard.mjs'))).default;
 const trials=(await import(pathToFileURL(root+'/backend/player_identity/heavenly_trials_dashboard.mjs'))).default;
 const odyssey=(await import(pathToFileURL(root+'/backend/player_identity/odyssey_dashboard.mjs'))).odysseyDashboard;
 const catalog=JSON.parse(fs.readFileSync(root+'/backend/player_identity/mail_reward_catalog.json'));
 const requests=[],errors=[],now=Math.floor(Date.now()/1000),states=[];let checks=0;
 const check=(v,m)=>{assert.ok(v,m);checks++};
 const reward_catalog=Object.fromEntries([...catalog.currencies,...catalog.equipment].map(x=>[x.id,{...x,icon:'/admin/assets/'+x.id+'.png'}]));
 const operations={version:1,server_time:now,campaigns:[],calendar:[],current:null,stats:{participants:12,attempts:32,wins:19,running:2,claimable_tiers:6,claimed_tiers:8,pending_mail:0,ad_bonuses:4},schema:{ready:true,missing:[]},refund:{fresh:true,age_seconds:30},ads:{configured:true},profile_binding_configured:true};
 function make(html,route){
  const vc=new VirtualConsole();vc.on('jsdomError',e=>errors.push(e.message));
  const dom=new JSDOM(html.replaceAll('__NONCE__','local-only'),{url:'https://fixture.invalid'+route,runScripts:'outside-only',pretendToBeVisual:true,virtualConsole:vc});const w=dom.window;
  w.structuredClone=structuredClone;w.scrollTo=()=>{};w.confirm=()=>false;w.prompt=()=>null;w.IntersectionObserver=class{observe(){}unobserve(){}disconnect(){}};w.crypto.randomUUID=require('node:crypto').randomUUID;
  w.fetch=async(url,opt={})=>{const u=new URL(url,w.location.href);assert.equal(u.origin,'https://fixture.invalid');const body=opt.body?JSON.parse(opt.body):null;requests.push({path:u.pathname,body,method:opt.method||'GET'});let d={};switch(u.pathname){
   case '/admin/api/session':d={csrf:'local-test',account_enabled:true,username:'Operator',reward_catalog};break;
   case '/admin/api/history':d={entries:[],cutoff:now,next_cursor:null};break;
   case '/admin/api/jobs':case '/admin/api/drafts':d={entries:[]};break;
   case '/admin/api/drafts/save':d={id:'d'.repeat(32)};break;
   case '/admin/api/pavilion':d={revision:1,server_time:now,catalog:catalog.equipment,artworks:[{id:'sanctum',name:'Jade Sanctum'}],base_rates:{common:6000,rare:2900,epic:900,legendary:200},document:{banners:[]}};break;
   case '/admin/api/updates/history':case '/admin/api/announcements/history':d={entries:[],server_time:now};break;
   case '/admin/api/announcements/preview':d={registered_players:10,draft:body,confirm_expires_at:now+300};break;
   case '/admin/api/trials/operations':d=operations;break;
   case '/admin/api/odyssey':d={event:null,server_time:now};break;
  }return{ok:true,status:200,json:async()=>d};};
  for(const script of w.document.querySelectorAll('script'))w.eval(script.textContent);states.push(dom);return w;
 }
 const w=make(main,'/admin');await wait();
 check(!w.document.getElementById('studio').hidden,'session opens studio');
 check(requests.length===1&&requests[0].path.endsWith('/session'),'login reads only one session; hidden admin sections make no requests');
 check(w.document.querySelector('.metrics').hidden,'unloaded history counters do not appear as empty compose metrics');
 if(process.env.JADE_ADMIN_RENDER_HTML){
  const clone=new JSDOM(w.document.documentElement.outerHTML);const d=clone.window.document;
  d.querySelectorAll('script,dialog,#login-panel,[data-view][hidden],.metrics[hidden],#message[hidden]').forEach(n=>n.remove());
  d.querySelectorAll('.equipment-grid .gear-card').forEach((n,i)=>{if(i>=6)n.remove()});
  const style=(await import(pathToFileURL(root+'/backend/player_identity/admin_studio_style.mjs'))).studioStyle;
  d.querySelector('link[rel=stylesheet]').outerHTML='<style>'+style+'</style>';
  d.querySelectorAll('img').forEach(n=>n.remove());
  fs.writeFileSync(process.env.JADE_ADMIN_RENDER_HTML,'<!doctype html>'+d.documentElement.outerHTML);clone.window.close();
 }

 const nav=id=>w.document.querySelector('[data-nav='+id+']');
 for(let i=0;i<8;i++)nav('pavilion').click();await wait();
 check(requests.filter(x=>x.path==='/admin/api/pavilion').length===1,'rapid tab presses coalesce one read');
 check(w.document.getElementById('banner-start').value.length===16,'Pavilion default date filled');
 w.document.getElementById('banner-title').value='Unsaved local draft';nav('compose').click();nav('pavilion').click();await wait();
 check(w.document.getElementById('banner-title').value==='Unsaved local draft','navigation keeps unfinished banner draft');
 w.document.getElementById('banner-reload').click();await wait();check(w.document.getElementById('banner-title').value==='Unsaved local draft','explicit server refresh keeps the unfinished banner too');
 check(w.document.getElementById('banner-publish').hidden,'refresh requires a fresh reviewed revision before publish');
 for(let i=0;i<8;i++)nav('announcements').click();await wait();
 check(requests.filter(x=>x.path==='/admin/api/announcements/history').length===1,'announcement nav does not double load');
 check(requests.filter(x=>x.path==='/admin/api/updates/history').length===1,'notification history uses the same coalesced view read');
 const $=id=>w.document.getElementById(id);$('ann-title').value='Upcoming rotation';$('ann-body').value='Local preview';$('ann-start').value='2027-01-01T00:05';
 $('announcement-form').dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));await wait();
 check(requests.find(x=>x.path==='/admin/api/announcements/preview').body.starts_at===Date.parse('2026-12-31T17:05:00Z')/1000,'real announcement form converts WIB to UTC once');
 check($('ann-confirm').textContent.includes('WIB'),'preview labels fixed timezone');
 check(!requests.some(x=>x.method==='POST'&&!x.path.endsWith('/preview')),'opening tabs and preview never publish or grant');
 for(let i=0;i<8;i++)$('save-draft').click();await wait();check(requests.filter(x=>x.path==='/admin/api/drafts/save').length===1,'save-draft spam creates only one pending write');
 nav('history').click();await wait();check(requests.filter(x=>x.path==='/admin/api/history').length===1,'history loads on demand');
 const t=make(trials,'/admin/trials');await wait();
 check(!t.document.getElementById('publish').disabled,'Trials session/readiness opens editor');
 check(t.document.getElementById('start').value.endsWith('04:00'),'Trials proposes Monday04 WIB automatically');
 t.document.getElementById('start').value='2026-10-26T04:00';t.document.getElementById('start').dispatchEvent(new t.Event('change'));
 check(t.document.getElementById('utc').textContent.includes('2026-10-25T21:00:00.000Z'),'Trials preview converts WIB to actual Sunday UTC');
 const o=make(odyssey,'/admin/odyssey');await wait();check(o.document.getElementById('clock').textContent.includes('WIB'),'Odyssey clock explicitly identifies fixed zone');
 const ostart=o.document.getElementById('start'),keep=ostart.value;ostart.dispatchEvent(new o.Event('input',{bubbles:true}));const reads=requests.filter(x=>x.path==='/admin/api/odyssey').length;o.document.getElementById('reload').click();await wait();check(ostart.value===keep&&requests.filter(x=>x.path==='/admin/api/odyssey').length===reads,'Odyssey refresh cannot silently discard unfinished changes');
 check(errors.length===0,'all full dashboard scripts run without DOM/script exceptions: '+errors.join(';'));
 for(const dom of states)dom.window.close();
 fs.mkdirSync(path.join(root,'.local/retention_dashboard_qa'),{recursive:true});fs.writeFileSync(path.join(root,'.local/retention_dashboard_qa/dashboard-dom.json'),JSON.stringify({checks,failures:0,requests,errors,scope:'full generated HTML scripts in isolated DOM; no production access, not a visual or device test'},null,2));console.log('DASHBOARD_DOM checks='+checks+' failures=0');
})().catch(e=>{console.error(e);process.exitCode=1});
