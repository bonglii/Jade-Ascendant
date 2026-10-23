import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import html from './heavenly_trials_dashboard.mjs';
const {validateDashboardPage}=createRequire(import.meta.url)('./check_liveops_control.cjs');

test('validate the actual generated dashboard with interpolated WIB helpers',()=>{
 assert.match(html,/const StudioTime=/);
 assert.equal(validateDashboardPage(html),1);
});
test('raw module template reproduces the old syntax-check failure',()=>{
 const source=readFileSync(new URL('./heavenly_trials_dashboard.mjs',import.meta.url),'utf8');
 assert.match(source,/\$\{adminTimeJS\}/);
 assert.throws(()=>validateDashboardPage(source),SyntaxError);
});
test('invalid JavaScript in an additional inline script still fails the gate',()=>{
 assert.throws(()=>validateDashboardPage(html+'<script nonce="__NONCE__">const broken=;</script>'),SyntaxError);
});
test('missing generated HTML or script cannot produce a passing check',()=>{
 assert.throws(()=>validateDashboardPage(undefined),/not a string/);
 assert.throws(()=>validateDashboardPage('<main>No script</main>'),/script missing/);
});
