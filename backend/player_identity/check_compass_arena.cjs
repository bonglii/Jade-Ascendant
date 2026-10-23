'use strict';
// Offline payload/production contract check. Runtime proof is the scoped Godot suite.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process');
const {assertConfig}=require('./production_release_contract.mjs');
function check(root=path.resolve(__dirname,'../..')){
 assertConfig(fs.readFileSync(path.join(root,'backend/monetization/cloudflare/wrangler.production-live.toml'),'utf8'));
 const files=JSON.parse(fs.readFileSync(path.join(root,'assets/vfx/compass_pursuit/manifest.json'),'utf8'));
 if(files.length!==3)throw Error('Unexpected art manifest');
 for(const row of files){
  if(!/^assets\/(vfx\/compass_pursuit|world\/boss_arena|ui\/level_up\/skill_art\/v4)\/[a-z_]+\.png$/.test(row.file))throw Error('Invalid art path');
  const bytes=fs.readFileSync(path.join(root,row.file));
  if(crypto.createHash('sha256').update(bytes).digest('hex')!==row.sha256||bytes.toString('hex',0,8)!=='89504e470d0a1a0a')throw Error('Art integrity failed: '+row.file);
 }
 const result=cp.spawnSync(process.execPath,['--test','backend/player_identity/repair_trials_time.test.mjs','backend/player_identity/admin_time.test.mjs','backend/player_identity/liveops_control_release.test.mjs','backend/player_identity/heavenly_trials.test.mjs'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:120000});
 if(result.error||result.status!==0)throw Error('WIB/schedule preflight failed: '+(result.error?.message||result.stdout||result.stderr).slice(-2000));
 console.log('COMPASS_ARENA_SOURCE=PASS; ART=3; GATES=9; SCHEDULE_GUARDS=PASS; RUNTIME_CI=REQUIRED; REMOTE_DATA=UNCHANGED');
}
if(require.main===module){try{check(process.argv[2]);}catch(e){console.error('COMPASS_ARENA_SOURCE_STOPPED: '+e.message);process.exitCode=1;}}
module.exports={check};
