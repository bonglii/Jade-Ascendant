'use strict';
// The real manager and Ogg files; isolated signal stubs, no gameplay/network/save access.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),args=process.argv.slice(2);
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const source=fs.readFileSync(path.join(root,'scripts/managers/audio_manager.gd'),'utf8');
const provenance=JSON.parse(fs.readFileSync(path.join(root,'assets/audio/chinese_music/provenance.json'),'utf8'));
for(const row of provenance.tracks){if(sha(fs.readFileSync(path.join(root,'assets/audio/chinese_music',row.file)))!==row.sha256)throw Error('Music bytes differ: '+row.file);}
for(const row of provenance.tracks){
 const name='assets/audio/chinese_music/'+row.file,metadata=fs.readFileSync(path.join(root,name+'.import'),'utf8');
 if(!metadata.includes('importer="oggvorbisstr"')||!metadata.includes('source_file="res://'+name+'"'))throw Error('Missing/mismatched committed Ogg importer: '+row.file);
}
console.log('CHINESE_MUSIC_SOURCE=PASS; OGG_HASHES=2; IMPORT_METADATA=2');
if(!args.includes('--source-only')){
 if(!args[0])throw Error('Supply Godot executable, or --source-only.');
 const engine=path.resolve(args[0]),project=fs.mkdtempSync(path.join(os.tmpdir(),'jade-music-')),evidence=path.join(root,'.local/chinese_music_qa');
 fs.mkdirSync(evidence,{recursive:true});
 try{
  const paths=new Set(['scripts/managers/audio_manager.gd','tests/chinese_music_smoke.gd',...Array.from(source.matchAll(/preload\("res:\/\/([^"\n]+)"\)/g),m=>m[1])]);
  for(const name of paths){const target=path.join(project,name);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(root,name),target);const metadata=path.join(root,name+'.import');if(fs.existsSync(metadata))fs.copyFileSync(metadata,target+'.import');}
  const stubs={ProgressionManager:'signal cultivation_upgraded(upgrade_id, new_level)',PavilionManager:'signal purchase_delivery_finished(product_id, success, message)',MonetizationManager:'signal reward_delivery_finished(placement, success, amount, message)',EquipmentManager:'signal equipment_changed(slot_id, item_id)\nsignal equipment_ascended(item_id, old_star, new_star)',AchievementManager:'signal achievement_unlocked(achievement_id)'};
  let config='config_version=5\n[application]\nconfig/name="Isolated Chinese music QA"\n[autoload]\n';
  for(const [name,signals]of Object.entries(stubs)){fs.writeFileSync(path.join(project,name+'.gd'),'extends Node\n'+signals+'\n');config+=name+'="*res://'+name+'.gd"\n';}
  config+='AudioManager="*res://scripts/managers/audio_manager.gd"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';
  // One fresh-cache import with the actual autoloads enabled from the start.
  // Copy committed importer metadata exactly as a new Git checkout receives it.
  fs.writeFileSync(path.join(project,'project.godot'),config);
  for(const [label,params,marker]of [['import',['--editor','--import'],null],['runtime',['--script','res://tests/chinese_music_smoke.gd'],'CHINESE_MUSIC_RUNTIME=PASS']]){
   const r=cp.spawnSync(engine,['--headless','--path',project,...params],{encoding:'utf8',timeout:90000,windowsHide:true,maxBuffer:8*1024*1024}),output=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(evidence,label+'.log'),output);
   if(r.error||r.status!==0||/SCRIPT ERROR|Parse Error|CHINESE_MUSIC_FAIL|^ERROR:/m.test(output)||marker&&!output.includes(marker))throw Error(r.error?.message||output);
   console.log('CHINESE_MUSIC_'+label.toUpperCase()+'=PASS');if(marker)console.log(output.match(/CHINESE_MUSIC_RUNTIME=PASS[^\n]*/)[0]);
  }
 }finally{fs.rmSync(project,{recursive:true,force:true});}
 console.log('ISOLATED_REAL_AUDIO_MANAGER; AUTOLOAD_SIGNAL_STUBS; ANDROID=NOT_TESTED');
}
