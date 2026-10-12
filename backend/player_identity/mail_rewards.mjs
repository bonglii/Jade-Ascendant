import catalog from './mail_reward_catalog.json' with {type:'json'};
import {fail,exact} from './mail_admin.mjs';
export const CATALOG=catalog;
export const REWARD_CATALOG=Object.fromEntries([...catalog.currencies,...catalog.equipment].map(item=>[item.id,{...item,icon:'/admin/assets/'+item.id+'.png'}]));
const integer=(value,min,max)=>{if(!Number.isSafeInteger(value)||value<min||value>max)fail(400,'invalid_amount');return value;};
export function normalizeReward(input){
 exact(input,['spirit_stone','celestial_jade','pavilion_seal','items']);
 const stone=integer(input.spirit_stone??0,0,100000),jade=integer(input.celestial_jade??0,0,10000),seals=integer(input.pavilion_seal??0,0,100);
 const raw=input.items??{};if(!raw||typeof raw!=='object'||Array.isArray(raw))fail(400,'invalid_reward');
 const items={};let equipment=0;
 for(const id of Object.keys(raw).sort()){
  if(id==='refinement_shard'){const amount=integer(raw[id],0,500);if(amount)items[id]=amount;continue;}
  if(!catalog.equipment.some(item=>item.id===id))fail(400,'invalid_equipment');
  items[id]=integer(raw[id],1,1);if(++equipment>5)fail(400,'equipment_limit');
 }
 return {spirit_stone:stone,items,...(jade?{celestial_jade:jade}:{}),...(seals?{pavilion_seal:seals}:{})};
}
export const hasReward=reward=>reward.spirit_stone>0||(reward.celestial_jade||0)>0||(reward.pavilion_seal||0)>0||Object.values(reward.items).some(x=>x>0);
export const needsGiftClient=reward=>(reward.celestial_jade||0)>0||(reward.pavilion_seal||0)>0||Object.keys(reward.items).some(id=>id!=='refinement_shard');
