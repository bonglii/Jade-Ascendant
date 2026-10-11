#!/usr/bin/env node
/** This scanner is intentionally read-only; exit 2 means valid RELEASE_HOLD. */
import {readFileSync, existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {assessRelease, REQUIRED_CONTRACTS, REQUIRED_IMPLEMENTATIONS} from './m7e5_release_gate_lib.mjs';

const present = {};
const contracts = {};
for (const f of [...REQUIRED_CONTRACTS, ...REQUIRED_IMPLEMENTATIONS,
  'backend/monetization/ssv/functions/package-lock.json']) present[f] = existsSync(f);
// Existence is not supply-chain evidence: an npm-generated untracked lockfile is not accepted.
const lockPath = 'backend/monetization/ssv/functions/package-lock.json';
try {
  present[lockPath] = existsSync(lockPath) && Boolean(execFileSync('git',['ls-files','--error-unmatch','--',lockPath],{encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim());
} catch { present[lockPath] = false; }
for (const path of REQUIRED_CONTRACTS) {
  if (!present[path]) continue;
  try { contracts[path] = JSON.parse(readFileSync(path,'utf8')); }
  catch (err) { console.error(`M7E5 invalid JSON: ${path} (${err.message})`); process.exit(3); }
}
let git = {};
try {
  git = {
    head: execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),
    ciSha: process.env.GITHUB_SHA?.trim() || '',
    dirty: Boolean(execFileSync('git',['status','--porcelain','--untracked-files=normal'],{encoding:'utf8'}).trim()),
  };
} catch (e) {console.error('M7E5 cannot inspect Git HEAD:',e.message); process.exit(3);}
// A current-SHA multi-job CI green assertion requires independent review of GitHub statuses.
// Do not accept an environment variable or client-supplied flag as that external proof.
const result = assessRelease({contracts, present, git, review:{currentShaCIGreen:false}});
console.log(JSON.stringify(result,null,2));
process.exitCode = result.exitCode;
