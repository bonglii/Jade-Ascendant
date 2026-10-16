import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {assertConfig,assertReadiness,LIVE_GATES,TABLES} from './production_release_contract.mjs';
const live=readFileSync(new URL('../monetization/cloudflare/wrangler.production-live.toml',import.meta.url),'utf8');
test('durable live config pins existing production and all nine gates',()=>{assert.equal(assertConfig(live),true);assert.equal(LIVE_GATES.length,9);assert.equal(TABLES.length,15);});
test('rejects a locked gate, staging target, wrong DB and unreviewed legacy write flag',()=>{
 for(const changed of [live.replace('JADE_REAL_MONEY_RELEASE_ENABLED = "true"','JADE_REAL_MONEY_RELEASE_ENABLED = "false"'),live.replace('f0e59ec4-effb-4002-b9a5-d246965b5b83','c7c9841f-cbd3-4563-b13f-21ed90d45120'),live.replace('name = "jade-ascendant-iap"','name = "jade-ascendant-iap-staging"'),live.replace('JADE_PAID_LOADOUT_WRITE_ENABLED = "false"','JADE_PAID_LOADOUT_WRITE_ENABLED = "true"')])assert.throws(()=>assertConfig(changed));
 assert.throws(()=>assertConfig(live+'\nJADE_IAP_BACKEND_ENABLED = "true"\n'));
});
test('readiness requires actual complete schema and fresh, non-future refund observation',()=>{
 const value=[{success:true,results:[{schema_count:15,refund_age_seconds:200}]}];assert(assertReadiness(value));
 for(const row of [{schema_count:1,refund_age_seconds:0},{schema_count:15,refund_age_seconds:null},{schema_count:15,refund_age_seconds:1201},{schema_count:15,refund_age_seconds:-1}])assert.throws(()=>assertReadiness([{success:true,results:[row]}]));
 assert.throws(()=>assertReadiness({error:{code:7403}}));
});
