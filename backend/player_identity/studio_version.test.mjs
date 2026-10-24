import test from 'node:test';
import assert from 'node:assert/strict';
import dashboard from './dashboard.mjs';
import {odysseyDashboard as odyssey} from './odyssey_dashboard.mjs';
import trials from './heavenly_trials_dashboard.mjs';
import {studioNav} from './admin_studio_navigation.mjs';
for(const [name,page] of [['main',dashboard],['odyssey',odyssey],['trials',trials]])test('operator can identify the deployed Studio revision: '+name,()=>{
 assert.match(page,/Studio · Comfort 24\.10/);
 assert.match(page,/WIB \(UTC\+7\)/);
});
test('login revision is visible without an authenticated session',()=>assert.match(dashboard,/Jade Studio · Comfort 24\.10/));
test('shared operator navigation retains all eleven tools',()=>assert.equal((studioNav().match(/class="nav-item/g)||[]).length,11));
