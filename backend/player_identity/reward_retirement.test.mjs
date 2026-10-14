import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {normalizeReward, CATALOG} from './mail_rewards.mjs';
import dashboard from './dashboard.mjs';
test('retired fragment cannot be authored; historical mail remains readable unchanged',()=>{
 const old={spirit_stone:100,items:{refinement_shard:4}};
 assert.throws(()=>normalizeReward(old),/retired_material/);
 assert.deepEqual(normalizeReward(old,true),old);
 assert.deepEqual(old,{spirit_stone:100,items:{refinement_shard:4}});
 assert.deepEqual(normalizeReward({spirit_stone:180,items:{}}),{spirit_stone:180,items:{}});
 assert.equal(CATALOG.currencies.some(x=>x.id==='refinement_shard'),false);
});
test('dashboard has no active fragment control or stale selector and script still parses',()=>{
 assert.equal(dashboard.includes('id="shards"'),false);
 assert.equal(dashboard.includes("$('shards')"),false);
 assert.equal(dashboard.includes('Duplikat identik dipakai untuk refine'),true);
 for(const match of dashboard.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g))new vm.Script(match[1]);
 assert.match(dashboard,/20\*\(data\.reward\.items\.refinement_shard\|\|0\)/);
});
