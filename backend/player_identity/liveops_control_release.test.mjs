import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
const read=name=>readFileSync(new URL(name,import.meta.url),'utf8');
test('current live deployment launchers preserve dashboard-configured vars',()=>{
 for(const name of ['deploy_liveops_control.ps1','deploy_heavenly_trials.ps1','deploy_player_flow_batch.ps1','deploy_odyssey_shop.ps1','deploy_update_notifications.ps1','deploy_odyssey_flow.ps1']){
  const lines=read(name).split('\n').filter(line=>/wrangler@4.* deploy /.test(line));assert.ok(lines.length>0,name);for(const line of lines)assert.match(line,/--keep-vars(?:\s|$)/,name);
 }
});
test('operations deployment uses the known resources, additive SQL file and per-target stages',()=>{
 const source=read('deploy_liveops_control.ps1');assert.match(source,/f0e59ec4-effb-4002-b9a5-d246965b5b83/);assert.match(source,/1089de95-8cdc-447d-a9e3-9e743d200cba/);assert.match(source,/0017_liveops_operations_indexes\.sql/);assert.match(source,/--file \$migration --yes/);assert.match(source,/ValidateSet\('indexes','iap','profile','all'\)/);assert.doesNotMatch(source,/--command|force.push|index\.lock|export_production/);
});
