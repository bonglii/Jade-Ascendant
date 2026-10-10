/**
 * M5 pure SERVER-SIDE resolver for M4 canonical summon transactions. STAGING.
 * No client RNG/pools/pity/results. Inputs must come from M4 verified state.
 * Deliberately NOT wired to public Worker routes or account provisioning.
 */
import {CATALOG_V1} from './summon_catalog_pinned.mjs';
const RARITIES = ['common','rare','epic','legendary'];
const BASE_RATES = [6000,2900,900,200];
const SHARDS = Object.freeze({common:5,rare:12,epic:30,legendary:75});
const PITY_LIMITS = Object.freeze({rare_plus:10,epic_plus:30,legendary:50});
const MAX = 1_000_000_000;
const ITEM = /^[a-z][a-z0-9_]{0,95}$/;
const plain = v => v!==null && typeof v==='object' && !Array.isArray(v) && (Object.getPrototypeOf(v)===Object.prototype || Object.getPrototypeOf(v)===null);
export class TrustedSummonStageError extends Error {constructor(code){super(code);this.name='TrustedSummonStageError';this.code=code;}}
const fail = code => {throw new TrustedSummonStageError(code);};

function secureInt(min,max) {
  if (!Number.isSafeInteger(min)||!Number.isSafeInteger(max)||min>max) fail('invalid_rng_range');
  const range=max-min+1;
  if (range>4294967296) fail('invalid_rng_range');
  const crypto=globalThis.crypto;
  if (!crypto || typeof crypto.getRandomValues!=='function') fail('secure_rng_unavailable');
  const limit=Math.floor(4294967296/range)*range;
  const buffer=new Uint32Array(1);
  do { crypto.getRandomValues(buffer); } while(buffer[0]>=limit);
  return min+(buffer[0]%range);
}

function requireState(s,pullCount) {
  if (![1,10].includes(pullCount)) fail('invalid_pull_count');
  if (!plain(s)||s.state_contract_version!==1||!Array.isArray(s.cleared_stage_keys)||s.cleared_stage_keys.length>200
      ||s.cleared_stage_keys.some(k=>typeof k!=='string'||!/^\d{1,2}-\d{1,2}$/.test(k))
      ||new Set(s.cleared_stage_keys).size!==s.cleared_stage_keys.length
      ||!s.cleared_stage_keys.includes('1-5')
      ||!plain(s.pity)||!['rare_plus','epic_plus','legendary'].every((k,i)=>Number.isInteger(s.pity[k])&&s.pity[k]>=0&&s.pity[k]<[10,30,50][i])
      ||!plain(s.inventory)||Object.keys(s.inventory).length>300||Object.entries(s.inventory).some(([k,v])=>!ITEM.test(k)||v!==1)
      ||!Number.isSafeInteger(s.refinement_shards)||s.refinement_shards<0||s.refinement_shards>MAX
      ||!Number.isSafeInteger(s.lifetime_pulls)||s.lifetime_pulls<0||s.lifetime_pulls>MAX-pullCount
      ||typeof s.wish_item_id!=='string'||typeof s.wish_fate_guaranteed!=='boolean'
      ||(s.wish_fate_guaranteed&&!s.wish_item_id)) fail('invalid_canonical_state');
}

function getPool(cleared) {
  const unlocked=new Set(cleared);
  const pool=Object.fromEntries(RARITIES.map(r=>[r,[]]));
  for(const it of CATALOG_V1){
    if((it.chapter===0||it.stage===0)||unlocked.has(it.chapter+'-'+it.stage)) pool[it.rarity].push(it.id);
  }
  return pool;
}
function getRates(pool) {
  const rates=[...BASE_RATES];
  for(let i=RARITIES.length-1;i>=0;i--){
    if(pool[RARITIES[i]].length) continue;
    const displaced=rates[i];rates[i]=0;
    if(displaced<=0) continue;
    let fallback=-1;
    for(let j=i-1;j>=0;j--){if(pool[RARITIES[j]].length){fallback=j;break;}}
    if(fallback===-1) for(let j=i+1;j<RARITIES.length;j++){if(pool[RARITIES[j]].length){fallback=j;break;}}
    if(fallback!==-1) rates[fallback]+=displaced;
  }
  if(rates.reduce((a,b)=>a+b,0)!==10000) fail('catalog_pool_empty');
  return rates;
}
function chooseRarity(state,pool,rates,rand) {
  if(pool.legendary.length && state.pity.legendary>=PITY_LIMITS.legendary-1) return ['legendary',true];
  if(pool.epic.length && state.pity.epic_plus>=PITY_LIMITS.epic_plus-1) return ['epic',false];
  if(pool.rare.length && state.pity.rare_plus>=PITY_LIMITS.rare_plus-1) return ['rare',false];
  const n=rand(1,10000);
  if(!Number.isSafeInteger(n)||n<1||n>10000) fail('invalid_secure_rng_result');
  let running=0;
  for(let i=0;i<RARITIES.length;i++){running+=rates[i];if(n<=running) return [RARITIES[i],false];}
  fail('catalog_invalid_rates');
}
function pick(options,rand) {
  if(!options?.length) fail('empty_roll_pool');
  const i=rand(0,options.length-1);
  if(!Number.isSafeInteger(i)||i<0||i>=options.length) fail('invalid_secure_rng_result');
  return options[i];
}
function resolver(rand,{canonicalState:input,pullCount}) {
  requireState(input,pullCount);
  const state=structuredClone(input);
  const pool=getPool(state.cleared_stage_keys);
  const rates=getRates(pool);
  if(state.wish_item_id && !pool.legendary.includes(state.wish_item_id)) fail('wish_not_unlocked');
  const results=[];
  for(let i=0;i<pullCount;i++){
    const [rarity,hard]=chooseRarity(state,pool,rates,rand);
    const wish=state.wish_item_id;
    const wishEligible=rarity==='legendary' && !!wish;
    const wasGuaranteed=state.wish_fate_guaranteed;
    let item;
    if(wishEligible && (hard || wasGuaranteed || rand(0,1)===0)) item=wish;
    else if(wishEligible){const nonWish=pool.legendary.filter(x=>x!==wish);item=pick(nonWish.length?nonWish:pool.legendary,rand);}
    else item=pick(pool[rarity],rand);
    const wishHit=wishEligible&&item===wish;
    const wishFateConsumed=wishEligible&&wasGuaranteed&&wishHit;
    const wishFateActivated=wishEligible&&!wishHit&&!hard;
    if(wishEligible) state.wish_fate_guaranteed=!wishHit;
    const duplicate=state.inventory[item]===1;
    const shards=duplicate?SHARDS[rarity]:0;
    if(!duplicate) state.inventory[item]=1;
    state.refinement_shards+=shards;
    if(state.refinement_shards>MAX) fail('shard_overflow');
    results.push({item_id:item,rarity,duplicate,duplicate_shards:shards,hard_legendary_pity:hard,wish_hit:wishHit,wish_fate_activated:wishFateActivated,wish_fate_consumed:wishFateConsumed});
    const rank=RARITIES.indexOf(rarity);
    state.pity.rare_plus=rank>=1?0:state.pity.rare_plus+1;
    state.pity.epic_plus=rank>=2?0:state.pity.epic_plus+1;
    if(pool.legendary.length) state.pity.legendary=rank>=3?0:state.pity.legendary+1;
  }
  state.lifetime_pulls+=pullCount;
  return {outcome:{outcome_contract_version:1,pull_count:pullCount,results,next_pity:{...state.pity}},nextState:state};
}
// The only production-facing resolver; cryptographic randomness generated inside Worker.
export function resolveTrustedSummonStage(args) {return resolver(secureInt,args);}
// Test harness only -- NEVER import this from a Worker route.
export function createTestOnlyTrustedResolver(randomInt) {
  if(typeof randomInt!=='function') fail('invalid_test_rng');
  return args=>resolver(randomInt,args);
}
export function getStagedPoolSnapshot(clearedStageKeys) {
  if(!Array.isArray(clearedStageKeys)) fail('invalid_cleared_stages');
  const pool=getPool(clearedStageKeys);
  return {pool,rates:getRates(pool)};
}
