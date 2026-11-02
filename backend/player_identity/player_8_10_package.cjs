'use strict';
// Apply and focused QA only. This launcher has no commit, push, export or deployment step.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const core=require('./player_8_10_tools.cjs');
const BRANCH='work/player-8-10-20261027';
function git(root,args,options={}){return core.command('git',args,root,options);}
function ensureWorkBranch(root){
 const current=git(root,['branch','--show-current']);
 if(current===BRANCH||current.startsWith(BRANCH+'-'))return current;
 let name=BRANCH;
 if(git(root,['show-ref','--verify','--quiet','refs/heads/'+name],{allowFailure:true}).status===0)name+='-'+crypto.randomUUID().slice(0,8);
 git(root,['switch','-c',name]);return name;
}
async function run({folder,args=process.argv.slice(2),qaOverride=null}={}){
 const values=new Set(['--project','--godot']);
 for(let i=0;i<args.length;i++){
  if(values.has(args[i])){if(!args[++i]||args[i].startsWith('--'))throw Error('Missing flag value');}
  else if(!['--install-only','--check-only'].includes(args[i]))throw Error('Unknown flag: '+args[i]);
 }
 const value=flag=>{const i=args.indexOf(flag);return i<0?'':args[i+1];};
 const candidates=[value('--project'),process.env.JADE_PROJECT,process.cwd(),'D:/Godot/project/jade-ascendant'].filter(Boolean);
 const candidate=candidates.find(p=>fs.existsSync(path.join(p,'project.godot'))&&fs.existsSync(path.join(p,'backend/player_identity')));
 if(!candidate)throw Error('Project not found. Use --project "D:\\Godot\\project\\jade-ascendant".');
 const root=fs.realpathSync(candidate),manifest=core.readPackage(folder);
 core.assertNoIndexLock(root);
 const origin=git(root,['remote','get-url','origin']);
 if(!/github\.com[:/]bonglii\/Jade-Ascendant(?:\.git)?$/i.test(origin))throw Error('Unexpected repository; no source changed.');
 if(git(root,['merge-base','--is-ancestor',manifest.base,'HEAD'],{allowFailure:true}).status!==0)throw Error('Expected base '+manifest.base+' (tester reliability R2) is not in this branch. No source changed.');
 const local=path.join(root,'.local/player_8_10_batch');fs.mkdirSync(local,{recursive:true});
 const ignore=path.join(root,'.local/.gdignore');if(!fs.existsSync(ignore))core.atomic(ignore,Buffer.alloc(0));
 const report=path.join(local,'review-'+crypto.randomUUID());
 const plans=core.prepareInstall(root,folder,manifest,report);
 const native=require('./player_8_10_native_check.cjs');
 const originalBridge=native.installed(root);
 const assertBridgePreserved=()=>{if(native.installed(root).sha256!==originalBridge.sha256)throw Error('Installed bridge changed during source installation/QA; no automatic restore or overwrite.');};
 const staged=new Map(plans.map(p=>[p.path,p.desired]));
 require('./player_8_10_native_check.cjs').validate(root,relative=>staged.get(relative)||fs.readFileSync(core.safePath(root,relative)));
 const {assertConfig}=await import(require('node:url').pathToFileURL(path.join(root,'backend/player_identity/production_release_contract.mjs')));
 assertConfig(fs.readFileSync(path.join(root,'backend/monetization/cloudflare/wrangler.production-live.toml'),'utf8'));
 if(args.includes('--check-only')){console.log('PLAYER_8_10_PLAN=PASS; FILES='+plans.length+'; SOURCE_WRITES=NONE');return{planned:plans.length};}
 const branch=ensureWorkBranch(root),head=git(root,['rev-parse','HEAD']);
 const backup=path.join(local,'backups',crypto.randomUUID());
 assertBridgePreserved();
 const changed=core.applyInstall(root,plans,backup);
 assertBridgePreserved();
 const stateFile=path.join(local,'receipt.json');
 let state=fs.existsSync(stateFile)?JSON.parse(fs.readFileSync(stateFile,'utf8')):{};
 state={...state,batch:'PLAYER_IMPLEMENTATION_8_10_2026-10-27',revision:manifest.revision||'R1',base:manifest.base,head,branch,installed:true,installed_bridge:originalBridge,last_changed_files:changed,last_backup:changed?backup:(state.last_backup||null),committed:false,pushed:false,deployed:false,exported:false,android_tested:false};
 if(changed>0)state.local_qa=false;
 const save=()=>core.atomic(stateFile,Buffer.from(JSON.stringify(state,null,2)+'\n'));
 save();
 console.log('PLAYER_8_10_INSTALL=PASS; CHANGED='+changed+'; BRANCH='+branch+(changed?'; BACKUP='+backup:''));
 if(args.includes('--install-only')){console.log('FOCUSED_QA=NOT_RUN; COMMIT/PUSH/DEPLOY/EXPORT=NONE');return state;}
 const qa=qaOverride||require(path.join(root,'backend/player_identity/check_player_8_10.cjs'));
 const known='D:/Godot/Godot_v4.7.2-stable_win64_console.exe';
 const requested=value('--godot')||process.env.GODOT_PATH||(fs.existsSync(known)?known:'');
 const godot=qaOverride?qaOverride.resolveGodot(root,requested):require(path.join(root,'backend/player_identity/check_tester_reliability.cjs')).resolveGodot(root,requested);
 const fingerprint=()=>core.sourceFingerprint(root)+core.hash(fs.readFileSync(path.join(root,"release/native/JadeMonetizationNativeBridge-production-candidate.aar")))+core.hash(fs.readFileSync(path.join(root,"docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json")));
 const before=fingerprint()+originalBridge.sha256;
 const qaKey=core.hash(Buffer.from(before+core.hash(fs.readFileSync(godot))));
 if(state.qa_key!==qaKey||!state.local_qa){
  state.local_qa=false;state.pending_qa_key=qaKey;save();
  const result=await qa.check(root,godot);
  if(!result||result.pass!==true)throw Error('Focused QA did not return a pass receipt.');
  assertBridgePreserved();
  if(fingerprint()+originalBridge.sha256!==before)throw Error('Source changed during QA. Re-run to validate the changed inputs.');
  state.local_qa=true;state.qa_key=qaKey;state.qa_source_fingerprint=before;state.qa_utc=new Date().toISOString();state.qa_suites=result.suites;delete state.pending_qa_key;save();
 }else console.log('PLAYER_8_10_RESUME=REUSE_UNCHANGED_QA');
 assertBridgePreserved();
 console.log('PLAYER_8_10_BATCH=PASS; ANDROID=NOT_TESTED; COMMIT/PUSH/DEPLOY/EXPORT=NONE\nNEXT=Export through the protected production launcher, then test the new Android build using ANDROID_CHECKLIST.md.');
 return state;
}
if(require.main===module)run({folder:path.resolve(__dirname,'../..')}).catch(e=>{console.error('PLAYER_8_10_STOPPED: '+e.message);process.exitCode=1;});
module.exports={run,ensureWorkBranch,BRANCH};
