'use strict';
const path=require('node:path'),fs=require('node:fs'),vm=require('node:vm'),{spawnSync}=require('node:child_process');
const serverTests=[...require('./check_heavenly_trials.cjs').serverTests,'backend/monetization/cloudflare/tests/heavenly_trials_operations.test.mjs','backend/player_identity/liveops_control_release.test.mjs'];
function check(project){
 const root=fs.realpathSync(project),logs=path.join(root,'.local/liveops_control_qa');fs.mkdirSync(logs,{recursive:true});
 const run=spawnSync(process.execPath,['--test','--test-concurrency=1','--test-reporter=tap',...serverTests],{cwd:root,encoding:'utf8',windowsHide:true,maxBuffer:32*1024*1024,timeout:180000});
 fs.writeFileSync(path.join(logs,'server.log'),(run.stdout||'')+(run.stderr||''));
 const summary=(run.stdout||'').split('\n').filter(s=>/^# (tests|pass|fail|skipped|duration)/.test(s));fs.writeFileSync(path.join(logs,'server.json'),JSON.stringify({exit_code:run.status,process_error:run.error?.code||null,summary},null,2)+'\n');
 if(run.error||run.status!==0)throw Error('Server validation failed; inspect '+path.join(logs,'server.log'));
 for(const line of summary)console.log(line);
 const contract=spawnSync(process.execPath,['backend/player_identity/production_release_contract.mjs'],{cwd:root,encoding:'utf8',windowsHide:true});if(contract.status!==0)throw Error('Existing live production contract failed.');console.log(contract.stdout.trim());
 const source=fs.readFileSync(path.join(root,'backend/player_identity/heavenly_trials_dashboard.mjs'),'utf8');const script=source.match(/<script nonce="__NONCE__">([\s\S]*?)<\/script>/)?.[1];if(!script)throw Error('Dashboard script missing.');new vm.Script(script);
 console.log('LIVEOPS_CONTROL_QA=PASS; CLIENT_NATIVE_AAB=UNCHANGED; PURCHASE=NONE; DEPLOY=NONE');
 return {pass:true,summary};
}
if(require.main===module)try{check(process.argv[2]||path.resolve(__dirname,'../..'))}catch(e){console.error('LIVEOPS_CONTROL_QA_STOPPED: '+e.message);process.exitCode=1}
module.exports={check,serverTests};
