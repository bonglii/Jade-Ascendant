import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync, sign} from 'node:crypto';
import {verifyGoogleSsv, buildPendingLedgerCandidate} from '../../ssv/m7e4b_ssv_verifier.mjs';
import {fixture,event,time} from './odyssey_flow_fixture.mjs';
import {service,creditAd} from '../src/odyssey_service.mjs';
const pair=generateKeyPairSync('ec',{namedCurve:'prime256v1'});
const unit='ca-app-pub-3082528078187093/8339864838';
function callback(nonce,adUnit='8339864838',encoded=false) {
 const raw=new URLSearchParams({ad_network:'123',ad_unit:adUnit,reward_amount:'1',reward_item:'Dice',timestamp:String(time*1000),transaction_id:'6'.repeat(32),custom_data:nonce,user_id:''}).toString();
 const signature=sign('sha256',Buffer.from(raw),pair.privateKey).toString('base64url')+'==';
 return '?'+raw+'&signature='+(encoded?encodeURIComponent(signature):signature)+'&key_id=1';
}
const opts=nonce=>({trustedGoogleKeys:{'1':pair.publicKey},expectedAdUnit:unit,expectedCustomData:nonce,expectedRewardAmount:1,expectedRewardItem:'Dice',nowMs:time*1000});
test('documented numeric Google unit and percent-encoded padding preserve exact signed bytes',()=>{
 const nonce='n'.repeat(32),query=callback(nonce,undefined,true),proof=verifyGoogleSsv(query,opts(nonce));
 assert.equal(proof.adUnit,unit);
 assert.equal(buildPendingLedgerCandidate(proof,{nonce,adUnit:unit,userId:'alice',intentId:'intent',placement:'odyssey',rewardAmount:1,rewardItem:'Dice'}).userId,'alice');
 assert.throws(()=>verifyGoogleSsv(query.replace('reward_item=Dice','reward_item=Coins'),opts(nonce)),/SIGNATURE_INVALID/);
});
test('numeric IDs do not relax publisher, suffix, nonce or signature checks',()=>{
 const nonce='n'.repeat(32);
 for(const other of ['8339864839','ca-app-pub-0000000000000000/8339864838','08339864838']) assert.throws(()=>verifyGoogleSsv(callback(nonce,other),opts(nonce)),/INTENT_BINDING_MISMATCH/);
 assert.throws(()=>verifyGoogleSsv(callback(nonce).replace('&signature=','&signature=%26'),opts(nonce)));
});
test('real documented callback format credits once, is owner scoped and restores receipt',async()=>{
 const f=fixture();f.raw.prepare('UPDATE odyssey_events SET document=?').run(JSON.stringify({...event,ads_enabled:true}));
 const api=service(f.db,{economy:4,now:()=>time}),before=await api.read('alice');
 const intent=await api.execute('alice',{event_id:event.id,request_id:'8'.repeat(32),revision:before.revision,action:{kind:'ad_intent'}});
 const query=callback(intent.ad_intent.nonce,undefined,true),env={ODYSSEY_AD_UNIT:unit,ODYSSEY_AD_REWARD_ITEM:'Dice'},deps={keys:async()=>({'1':pair.publicKey}),now:()=>time*1000};
 await creditAd(f.db,query,env,deps);await creditAd(f.db,query,env,deps);
 assert.equal((await api.read('alice')).state.tickets,4);assert.equal((await api.read('bob')).state.tickets,3);
});
