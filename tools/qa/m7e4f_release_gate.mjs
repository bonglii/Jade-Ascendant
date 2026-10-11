/** Read-only release gate; exit 2 means expected RELEASE_HOLD, never modify saves. */
import {readFileSync,existsSync} from 'node:fs';
const read=p=>JSON.parse(readFileSync(p,'utf8'));
const contract=read('backend/monetization/m7e4f_recovery_security_contract.json');
const prev=read('backend/monetization/m7e4e3_crash_delivery_contract.json');
const m6=read('backend/monetization/m6_final_monetization_lock.json');
const risk=contract.knownBlockers;
const proof={
  modelOnly:prev.this_gate_only.in_memory_qa_simulator===true,
  localGrantInactive:prev.this_gate_only.persistent_Godot_receipt_journal===false,
  ackInactive:prev.this_gate_only.server_ack_endpoint===false,
  ssvProductionOff:prev.this_gate_only.production_ssv_enabled===false,
  purchaseOff:m6.play_checkout_enabled===false,
  originalMonetizationPresent:existsSync('scripts/managers/monetization_manager.gd'),
};
const report={phase:'MONETIZATION_M7E4F',verdict:'RELEASE_HOLD',kind:'read_only_release_evidence_gate',
  evidence:proof,blockers:risk,warning:'Test-only gates do not establish Android save recovery, production SSV or approved deployment.',next:'Migrate intent/reward/receipt/ack end-to-end behind disabled flags and test on device, then exact-SHA CI.'};
console.log(JSON.stringify(report,null,2));
if(Object.values(proof).some(x=>!x))process.exitCode=3;
else process.exitCode=2;
