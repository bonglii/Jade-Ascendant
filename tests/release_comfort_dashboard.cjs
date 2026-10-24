'use strict';
const assert=require('node:assert/strict'),{pathToFileURL}=require('node:url'),path=require('node:path'),{JSDOM,VirtualConsole}=require('jsdom');
const root=path.resolve(__dirname,'..'),now=Math.floor(Date.now()/1000),wait=()=>new Promise(r=>setTimeout(r,25));let checks=0;
function check(ok,label){assert.ok(ok,label);checks++;}
(async()=>{
 const {studioStyle}=await import(pathToFileURL(root+'/backend/player_identity/admin_studio_style.mjs'));
 const odyssey=(await import(pathToFileURL(root+'/backend/player_identity/odyssey_dashboard.mjs'))).odysseyDashboard;
 const trials=(await import(pathToFileURL(root+'/backend/player_identity/heavenly_trials_dashboard.mjs'))).default;
 const themes=['jade_wind','scarlet_rite','starfall','froststep','sunforge'];
 const event={id:'odyssey-fixture',starts_at:now-3600,ends_at:now+86400,enabled:true,ads_enabled:true,purchases_enabled:true};
 const campaign={id:'trials-fixture',starts_at:now-3600,enabled:true,ads_enabled:true,shop_enabled:true,themes,reward:{celestial_jade:40,pavilion_seal:1,spirit_stone:600},status:'live'};
 const families=[];
 for(const [html,route,state] of [[odyssey,'odyssey',event],[trials,'trials',campaign]]){
  const errors=[],writes=[];const vc=new VirtualConsole();vc.on('jsdomError',e=>errors.push(e.message));
  const dom=new JSDOM(html,{url:'https://fixture.invalid/admin/'+route,runScripts:'outside-only',pretendToBeVisual:true,virtualConsole:vc});const w=dom.window;
  try{
   w.confirm=()=>true;w.structuredClone=structuredClone;w.scrollTo=()=>{};
   w.fetch=async(url,opt={})=>{const u=new URL(url,w.location.href);assert.equal(u.origin,'https://fixture.invalid');let data;
    if(u.pathname==='/admin/api/session')data={csrf:'test-session'};
    else if(opt.method==='POST'){
     check(opt.headers['x-jade-csrf']==='test-session','quick action retains CSRF');
     const payload=JSON.parse(opt.body);writes.push(payload);Object.assign(state,payload);data=route==='odyssey'?{event:state,server_time:now}:{campaign:state};
    }else if(route==='odyssey')data={event:state,server_time:now};
    else data={version:1,server_time:now,campaigns:[state],calendar:[],current:state,stats:{},schema:{ready:true,missing:[]},refund:{fresh:true,age_seconds:30},ads:{configured:true},profile_binding_configured:true};
    return{ok:true,status:200,json:async()=>structuredClone(data)};
   };
   for(const s of w.document.querySelectorAll('script'))w.eval(s.textContent);
   await wait();const button=w.document.getElementById('toggle-live');check(!button.disabled,route+' quick control ready');const original=structuredClone(state);
   button.click();button.click();await wait();check(writes.length===1&&!state.enabled,route+' single-flight pause');
   const paused=structuredClone(state);paused.enabled=true;check(JSON.stringify(paused)===JSON.stringify(original),route+' preserves season and all reward switches');
   button.click();await wait();check(writes.length===2&&state.enabled,route+' resumes same season');
   w.document.getElementById(route==='odyssey'?'ads':'enabled').dispatchEvent(new w.Event('input',{bubbles:true}));button.click();await wait();check(writes.length===2,route+' unsaved draft preserved');
   const style=w.document.createElement('style');style.textContent=studioStyle;w.document.head.append(style);
   families.push(w.getComputedStyle(w.document.body).fontFamily);check(w.getComputedStyle(w.document.body).fontSize==='14px',route+' same body size');
   for(const el of w.document.querySelectorAll('.studio-workspace h1,.studio-workspace strong,.studio-workspace button'))check(w.getComputedStyle(el).fontFamily.includes('system-ui'),route+' shared typography');
   check(errors.length===0,route+' no DOM errors');
  }finally{dom.window.close();}
 }
 check(families[0]===families[1],'same font between pages');console.log('RELEASE_COMFORT_DASHBOARD checks='+checks+' failures=0');
})().catch(e=>{console.error(e);process.exitCode=1});
