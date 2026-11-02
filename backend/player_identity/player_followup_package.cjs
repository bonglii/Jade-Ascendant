'use strict';
// Apply and focused QA only. This launcher has no commit, push, export or deployment step.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const core=require('./tester_batch_tools.cjs');
const BRANCH='work/player-followup-1-7-20261026';
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
 const local=path.join(root,'.local/player_followup_batch');fs.mkdirSync(local,{recursive:true});
 const ignore=path.join(root,'.local/.gdignore');if(!fs.existsSync(ignore))core.atomic(ignore,Buffer.alloc(0));
 const report=path.join(local,'review-'+crypto.randomUUID());
 const plans=core.prepareInstall(root,folder,manifest,report);
 if(args.includes('--check-only')){console.log('PLAYER_FOLLOWUP_PLAN=PASS; FILES='+plans.length+'; SOURCE_WRITES=NONE');return{planned:plans.length};}
 const branch=ensureWorkBranch(root),head=git(root,['rev-parse','HEAD']);
 const backup=path.join(local,'backups',crypto.randomUUID());
 const changed=core.applyInstall(root,plans,backup);
 const stateFile=path.join(local,'receipt.json');
 let state=fs.existsSync(stateFile)?JSON.parse(fs.readFileSync(stateFile,'utf8')):{};
 state={...state,batch:'PLAYER_BATCH_1_7_2026-10-26',base:manifest.base,head,branch,installed:true,last_changed_files:changed,last_backup:changed?backup:(state.last_backup||null),committed:false,pushed:false,deployed:false,exported:false,android_tested:false};
 if(changed>0)state.local_qa=false;
 const save=()=>core.atomic(stateFile,Buffer.from(JSON.stringify(state,null,2)+'\n'));
 save();
 console.log('PLAYER_FOLLOWUP_INSTALL=PASS; CHANGED='+changed+'; BRANCH='+branch+(changed?'; BACKUP='+backup:''));
 if(args.includes('--install-only')){console.log('FOCUSED_QA=NOT_RUN; COMMIT/PUSH/DEPLOY/EXPORT=NONE');return state;}
 const qa=qaOverride||require(path.join(root,'backend/player_identity/check_player_followup.cjs'));
 const known='D:/Godot/Godot_v4.7.2-stable_win64_console.exe';
 const requested=value('--godot')||process.env.GODOT_PATH||(fs.existsSync(known)?known:'');
 const godot=qaOverride?qaOverride.resolveGodot(root,requested):require(path.join(root,'backend/player_identity/check_tester_reliability.cjs')).resolveGodot(root,requested);
 const before=core.sourceFingerprint(root);
 const qaKey=core.hash(Buffer.from(before+core.hash(fs.readFileSync(godot))));
 if(state.qa_key!==qaKey||!state.local_qa){
  state.local_qa=false;state.pending_qa_key=qaKey;save();
  const result=await qa.check(root,godot);
  if(!result||result.pass!==true)throw Error('Focused QA did not return a pass receipt.');
  if(core.sourceFingerprint(root)!==before)throw Error('Source changed during QA. Re-run to validate the changed inputs.');
  state.local_qa=true;state.qa_key=qaKey;state.qa_source_fingerprint=before;state.qa_utc=new Date().toISOString();state.qa_suites=result.suites;delete state.pending_qa_key;save();
 }else console.log('PLAYER_FOLLOWUP_RESUME=REUSE_UNCHANGED_QA');
 console.log('PLAYER_FOLLOWUP_BATCH=PASS; ANDROID=NOT_TESTED; COMMIT/PUSH/DEPLOY/EXPORT=NONE\nNEXT=Run android_playtest.cmd on the connected phone; keep 8–10 parked until the device checklist is complete.');
 return state;
}
if(require.main===module)run({folder:path.resolve(__dirname,'../..')}).catch(e=>{console.error('PLAYER_FOLLOWUP_STOPPED: '+e.message);process.exitCode=1;});
module.exports={run,ensureWorkBranch,BRANCH};
