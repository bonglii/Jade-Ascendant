'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {runProcess,qa}=require('./check_event_touch.cjs');
const copied=[
 'scripts/ui/pavilion_aura_visual.gd','scripts/ui/pavilion_aura_preview.gd',
 'scripts/player/lin_yue_pavilion_aura_presentation.gd',
 'scripts/effects/premium_actor_material.gd','assets/shaders/premium_actor.gdshader',
 'assets/character/player/player_lin_yue_idle_walk_spriteframes.tres',
 'assets/character/player/polish_20261014/walk.png',
 'assets/character/player/polish_20261014/idle_hurt.png',
 'assets/character/player/polish_20261014/death.png','tests/aura_polish_smoke.gd',
 'tests/aura_pavilion_integration_smoke.gd','tests/qa_runtime_teardown.gd',
 'tests/pavilion_layout_contract.gd'
];
async function check(project,godot,{exportGeometry=false,native=false}={}){
 const root=fs.realpathSync(project),logs=path.join(root,'.local/aura_polish_qa');fs.mkdirSync(logs,{recursive:true});
 const fixture=path.join(logs,'fixture');fs.mkdirSync(fixture,{recursive:true});
 for(const p of copied){const dest=path.join(fixture,p);fs.mkdirSync(path.dirname(dest),{recursive:true});const bytes=fs.readFileSync(path.join(root,p));if(!fs.existsSync(dest)||!fs.readFileSync(dest).equals(bytes))fs.writeFileSync(dest,bytes);}
 fs.writeFileSync(path.join(fixture,'fixture_settings.gd'),'extends Node\nsignal settings_changed\nvar reduced_effects: bool = false\n');
 fs.writeFileSync(path.join(fixture,'fixture_pavilion.gd'),'extends Node\nsignal pavilion_changed\nvar fixture_state: Dictionary = {"id":"plain","owned":["plain"],"coins":1234}\nvar mutation_calls: int = 0\nfunc is_aura_feature_enabled() -> bool: return true\nfunc get_cosmetic_id() -> String: return str(fixture_state.id)\nfunc is_cosmetic_owned(id: String) -> bool: return id in fixture_state.owned\n');
 fs.writeFileSync(path.join(fixture,'project.godot'),'config_version=5\n[application]\nconfig/name="jade-aura-fixture"\nconfig/features=PackedStringArray("4.7", "GL Compatibility")\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="jade_aura_polish_qa_'+crypto.randomUUID()+'"\n[autoload]\nSettingsManager="*res://fixture_settings.gd"\nPavilionManager="*res://fixture_pavilion.gd"\n[display]\nwindow/size/viewport_width=390\nwindow/size/viewport_height=844\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[debug]\ngdscript/warnings/shadowed_variable_base_class=2\n');
 await runProcess(godot,['--headless','--audio-driver','Dummy','--editor','--path',fixture,'--import','--quit'],{cwd:root,logs,name:'import-aura',totalMs:120000});
 await runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/aura_pavilion_integration_smoke.gd','--check-only'],{cwd:root,logs,name:'parse-native-aura-integration',totalMs:30000});
 await runProcess(godot,[...(native?[]:['--headless']),'--verbose','--audio-driver','Dummy','--path',fixture,'--script','res://tests/aura_polish_smoke.gd',...(exportGeometry?['--','--export-geometry']:[])],{cwd:root,logs,name:'aura-polish'+(native?'-native':''),marker:'AURA_POLISH checks=',totalMs:120000});
 const output=path.join(fixture,'.local/aura_output');if(fs.existsSync(output))fs.cpSync(output,path.join(logs,'output'),{recursive:true});
 console.log('AURA_POLISH_QA=PASS; ECONOMY_CODE=UNCHANGED; NATIVE_GUI='+native+'; PHONE=NOT_TESTED');
}
if(require.main===module&&!process.argv.includes('--native-ui'))check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3],{exportGeometry:process.argv.includes('--export-geometry'),native:process.argv.includes('--native')}).catch(e=>{console.error('AURA_POLISH_STOPPED: '+e.message);process.exitCode=1;});
module.exports={check,copied};

async function nativeUi(project,godot){
 const root=fs.realpathSync(project),logs=path.join(root,'.local/aura_polish_qa');fs.mkdirSync(logs,{recursive:true});
 await qa(root,godot,{only:[]});
 const fixture=path.join(root,'.local/event_touch_qa/fixture'),config=path.join(fixture,'project.godot'),original=fs.readFileSync(config,'utf8');
 try{
  fs.writeFileSync(config,original.replace(/config\/custom_user_dir_name="[^"\r\n]*"/,'config/custom_user_dir_name="jade_aura_live_qa_'+crypto.randomUUID()+'"'));
  await runProcess(godot,['--verbose','--audio-driver','Dummy','--rendering-method','gl_compatibility','--path',fixture,'--script','res://tests/aura_pavilion_integration_smoke.gd'],{cwd:root,logs,name:'aura-pavilion-native',marker:'AURA_PAVILION checks=',totalMs:120000});
  const images=path.join(fixture,'.local/aura_native_images');if(fs.existsSync(images))fs.cpSync(images,path.join(logs,'native-images'),{recursive:true});
 }finally{fs.writeFileSync(config,original);}
 console.log('AURA_NATIVE_UI=PASS; PHONE=NOT_TESTED; PUBLISH=NONE; EXPORT=NONE');
}
if(require.main===module&&process.argv.includes('--native-ui'))nativeUi(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3]).catch(e=>{console.error('AURA_NATIVE_STOPPED: '+e.message);process.exitCode=1;});
module.exports.nativeUi=nativeUi;
