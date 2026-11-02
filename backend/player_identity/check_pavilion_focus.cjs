'use strict';
// Uses a disposable save directory and retained import cache. No live purchases.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {qa,runProcess}=require('./check_event_touch.cjs');
async function check(root,godot,{native=false}={}){
 root=fs.realpathSync(root);
 const logs=path.join(root,'.local/pavilion_focus_qa');fs.mkdirSync(logs,{recursive:true});
 await qa(root,godot,{only:[]});
 const fixture=path.join(root,'.local/event_touch_qa/fixture');
 const config=path.join(fixture,'project.godot'),original=fs.readFileSync(config,'utf8');
 const suites=native?[
  ['pavilion_focus_smoke.gd','PAVILION_FOCUS checks=','jade_pavilion_focus_qa'],
  ['pavilion_secrecy_render_smoke.gd','RARITY_PIXEL_PROOF blue_Rare_vs_purple_Epic=different PASS','jade_gacha_qa']
 ]:[
  ['pavilion_focus_smoke.gd','PAVILION_FOCUS checks=','jade_pavilion_focus_qa'],
  ['pavilion_weapon_picker_smoke.gd','PAVILION_WEAPON_PICKER_CHECKS=','jade_hero_qa'],
  ['pavilion_sanctum_smoke.gd','GACHA_NATIVE_QA checks=','jade_gacha_qa'],
  ['paid_gameplay_v2_smoke.gd','PAID_GAMEPLAY_V2_CHECKS=','jade_paid_v2_qa'],
  ['server_jade_delivery_smoke.gd','SERVER_JADE_DELIVERY checks=','jade_server_delivery_qa']
 ];
 try{
  for(const [script,marker,prefix]of suites){
   fs.writeFileSync(config,original.replace(/config\/custom_user_dir_name="[^"\r\n]*"/,'config/custom_user_dir_name="'+prefix+'_'+crypto.randomUUID()+'"'));
   await runProcess(godot,[...(native?[]:['--headless']),'--verbose','--audio-driver','Dummy','--rendering-method','gl_compatibility','--path',fixture,'--script','res://tests/'+script],{cwd:root,logs,name:script+(native?'-native':''),marker,totalMs:150000,idleMs:100000});
  }
 }finally{fs.writeFileSync(config,original);}
 const images=path.join(fixture,'.local/pavilion_focus_qa/images');
 if(native&&fs.existsSync(images))fs.cpSync(images,path.join(logs,'images'),{recursive:true});
 console.log('PAVILION_FOCUS_QA=PASS; NATIVE_GUI='+native+'; PHONE=NOT_TESTED; LIVE_PURCHASE=NONE; DEPLOY=NONE');
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3],{native:process.argv.includes('--native')}).catch(e=>{console.error('PAVILION_FOCUS_STOPPED: '+e.message);process.exitCode=1;});
module.exports={check};
