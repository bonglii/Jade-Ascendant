'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),{redact,packageVersion,steps}=require('./android_player_followup.cjs');
test('evidence strips account details and grant credentials from notes/logs',()=>{
 const text=redact('mail=tester@example.com Authorization: Bearer abc.def.123 nonce=secret_123 token=qwerty note=lag');
 assert.ok(!text.includes('tester@example.com'));assert.ok(!text.includes('abc.def.123'));assert.ok(!text.includes('secret_123'));assert.ok(!text.includes('qwerty'));assert.ok(text.includes('note=lag'));
});
test('device version proof reads the installed package instead of project defaults',()=>{
 assert.deepEqual(packageVersion('versionCode=17 minSdk=23\n versionName=1.0.17\n'),{version_code:'17',version_name:'1.0.17'});
 assert.deepEqual(packageVersion('package missing'),{version_code:'',version_name:''});assert.equal(steps.length,7);
});
