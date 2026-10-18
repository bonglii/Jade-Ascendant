'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process'),{pathToFileURL}=require('node:url');
function wranglerEntry(root){
 const ps="$ErrorActionPreference='Stop'; & npx.cmd --yes wrangler@4.151.0 --version; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; $cache=(& npm.cmd config get cache | Select-Object -Last 1); if ($LASTEXITCODE -ne 0) { throw 'Cannot locate npm cache' }; $cache=$cache.Trim(); $base=Join-Path $cache '_npx'; foreach ($dir in (Get-ChildItem -LiteralPath $base -Directory)) { $pkg=Join-Path $dir.FullName 'node_modules/wrangler/package.json'; if (Test-Path -LiteralPath $pkg) { $meta=[IO.File]::ReadAllText($pkg)|ConvertFrom-Json; if ($meta.version -eq '4.151.0') { $entry=Join-Path $dir.FullName 'node_modules/wrangler/bin/wrangler.js'; if (Test-Path -LiteralPath $entry) { [Console]::WriteLine('JADE_WRANGLER_ENTRY='+$entry); exit 0 } } } }; throw 'Wrangler 4.151.0 JS entry not found'";
 const exe=path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe');
 const r=spawnSync(exe,['-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',Buffer.from(ps,'utf16le').toString('base64')],{cwd:root,encoding:'utf8',timeout:180000,maxBuffer:4*1024*1024});
 const match=(r.stdout||'').match(/^JADE_WRANGLER_ENTRY=(.+)$/m);
 if(r.error||r.status!==0||!match)throw Error('Wrangler preparation failed. '+(r.stderr||r.stdout||r.error||''));
 const entry=match[1].trim(),meta=JSON.parse(fs.readFileSync(path.resolve(path.dirname(entry),'../package.json'),'utf8'));
 if(meta.version!=='4.151.0'||!fs.existsSync(entry))throw Error('Unexpected Wrangler entry');
 console.log('REFUND_WRANGLER=4.151.0; INVOCATION=DIRECT_NODE_ARGV');return entry;
}
function queryRunner(root,entry,folder){
 const config=path.join(root,'backend/monetization/cloudflare/wrangler.production-live.toml');
 const content=fs.readFileSync(config,'utf8');
 if(!/^name\s*=\s*"jade-ascendant-iap"\s*$/m.test(content)||!content.includes('f0e59ec4-effb-4002-b9a5-d246965b5b83')||!content.includes('database_name = "jade-iap-ledger"')||!content.includes('JADE_REAL_MONEY_RELEASE_ENABLED = "true"'))throw Error('Unexpected production database or config');
 let counter=0;
 return function execute(sql,label,{file=false}={}){
  const id=String(++counter).padStart(2,'0')+'-'+label;
  if(!file)fs.writeFileSync(path.join(folder,id+'.sql'),sql+'\n');
  const args=[entry,'d1','execute','jade-iap-ledger','--remote','--config',config,file?'--file':'--command',sql,'--json','--yes'];
  // Direct Node argv preserves JSON quotes. Never pass SQL through cmd.exe/npx.cmd.
  const r=spawnSync(process.execPath,args,{cwd:root,encoding:'utf8',timeout:120000,maxBuffer:8*1024*1024});
  fs.writeFileSync(path.join(folder,id+'.stdout.log'),r.stdout||'');fs.writeFileSync(path.join(folder,id+'.stderr.log'),r.stderr||'');
  if(r.error||r.status!==0)throw Error('D1 '+label+' failed. '+(r.stderr||r.stdout||r.error||'')+'\nLogs: '+folder);
  if(file)return null;
  let data;try{data=JSON.parse((r.stdout||'').trim());}catch{throw Error('D1 JSON response invalid; inspect '+path.join(folder,id+'.stdout.log'));}
  if(!Array.isArray(data)||data.some(x=>x.success!==true||!Array.isArray(x.results)))throw Error('D1 returned an unsuccessful result');
  return data.flatMap(x=>x.results);
 };
}
async function recover(root,{execute}={}){
 root=fs.realpathSync(root);const contract=await import(pathToFileURL(path.join(root,'backend/player_identity/refund_resolution_contract.mjs')).href);
 const folder=path.join(root,'.local/refund_resolution',crypto.randomUUID());fs.mkdirSync(folder,{recursive:true});
 const query=execute||queryRunner(root,wranglerEntry(root),folder);
 const schema=path.join(root,'backend/monetization/cloudflare/migrations/0014_refund_resolution.sql');
 query(schema,'schema',{file:true});
 const names=[...fs.readFileSync(schema,'utf8').matchAll(/CREATE (?:TABLE|INDEX|TRIGGER) IF NOT EXISTS ([a-z0-9_]+)/g)].map(x=>x[1]);
 const found=query('SELECT name FROM sqlite_master WHERE name IN ('+names.map(contract.quote).join(',')+')','schema-check');
 if(new Set(found.map(x=>x.name)).size!==names.length)throw Error('Refund resolution schema is incomplete; account untouched');
 const accounts=query(contract.OWNER_QUERY,'account-before');if(accounts.length!==1)throw Error('Case account is absent or ambiguous');
 const before=query(contract.voidQuery(accounts[0].owner_key),'void-credit-before');const plan=contract.reviewedPlan(accounts,before);
 fs.writeFileSync(path.join(folder,'reviewed-plan.json'),JSON.stringify(plan,null,2)+'\n');
 if(!plan.alreadyApplied){
  console.log('REFUND_CASE_REVIEW=PASS; ACCOUNT_REF='+contract.CASE.accountRef+'; REFUNDED_CREDIT=100; WALLET='+plan.before+' -> '+plan.after+'; HOLD=held -> released');
  query(contract.settlementInsert(plan),'apply-once');
 }else console.log('REFUND_SETTLEMENT_ALREADY_RECORDED=PASS; ADDITIONAL_DEBIT=0');
 const next=query(contract.OWNER_QUERY,'account-after'),voids=query(contract.voidQuery(accounts[0].owner_key),'void-credit-after');
 const result=contract.reviewedPlan(next,voids);
 if(!result.alreadyApplied||result.holdStatus!=='released')throw Error('Settlement recorded or attempted, but account still requires review. No repeat debit performed.');
 const audit=query('SELECT debit_jade,balance_before,balance_after,wallet_revision_before,wallet_revision_after FROM iap_refund_resolutions_v1 WHERE resolution_key='+contract.quote(result.key),'audit-check');
 if(audit.length!==1||audit[0].debit_jade!==100||audit[0].balance_before!==100||audit[0].balance_after!==0||audit[0].wallet_revision_after!==audit[0].wallet_revision_before+1)throw Error('Settlement audit differs; manual review required');
 console.log('REFUND_ACCOUNT_RECOVERED=PASS; ACCOUNT_REF='+contract.CASE.accountRef+'; CURRENT_WALLET='+result.balance+'; HOLD=released; AUDIT=RECORDED; PURCHASE=NONE; WORKER_DEPLOY=NONE');
 return {balance:result.balance,alreadyApplied:plan.alreadyApplied};
}
if(require.main===module){recover(process.argv[2]||path.resolve(__dirname,'../..')).catch(e=>{console.error('REFUND_RESOLUTION_STOPPED: '+e.message);process.exitCode=1;});}
module.exports={recover,queryRunner};
