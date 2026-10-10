/** Installer-only semantic parity check. The source must come from the local game project. */
import {readFileSync} from 'node:fs';
import {CATALOG_V1} from '../src/summon_catalog_pinned.mjs';
if(process.argv.length!==6) throw Error('VERIFY_EXPECTS_4_LOCAL_SOURCE_PATHS');
const [catalogPath,economyPath,inventoryPath,pavilionPath]=process.argv.slice(2);
const text=readFileSync(catalogPath,'utf8');
const entries=[];
// The one-tab item indentation belongs to EquipmentCatalog.ITEMS.
const pattern=/^(?:\t| {4})"([a-z][a-z0-9_]+)":\s*\{\s*\r?\n([\s\S]*?)^(?:\t| {4})\},?\s*$/gm;
for(const m of text.matchAll(pattern)) {
 const data=m[2];
 const rarity=data.match(/"rarity":\s*"(common|rare|epic|legendary)"/);
 const chapter=data.match(/"requires_chapter":\s*(\d+)/);
 const stage=data.match(/"requires_stage":\s*(\d+)/);
 if(!rarity||!chapter||!stage) throw Error('CATALOG_ITEM_FIELDS_CHANGED:'+m[1]);
 entries.push([m[1],rarity[1],Number(chapter[1]),Number(stage[1])]);
}
entries.sort((a,b)=>a[0].localeCompare(b[0],'en'));
const pinned=CATALOG_V1.map(x=>[x.id,x.rarity,x.chapter,x.stage]);
if(entries.length!==40 || JSON.stringify(entries)!==JSON.stringify(pinned)){
 console.error('LOCAL_CATALOG_COUNT='+entries.length+' PINNED_COUNT='+pinned.length);
 throw Error('LOCAL_CATALOG_DIFFERS_FROM_SERVER_PIN_STOP');
}
const economy=readFileSync(economyPath,'utf8');
const inventory=readFileSync(inventoryPath,'utf8');
const pavilion=readFileSync(pavilionPath,'utf8');
const required=[
 [economy,/"common":\s*6000/,'COMMON_RATE'],
 [economy,/"rare":\s*2900/,'RARE_RATE'],
 [economy,/"epic":\s*900/,'EPIC_RATE'],
 [economy,/"legendary":\s*200/,'LEGENDARY_RATE'],
 [economy,/"rare_plus":\s*10/,'RARE_PITY'],
 [economy,/"epic_plus":\s*30/,'EPIC_PITY'],
 [economy,/"legendary":\s*50/,'LEGENDARY_PITY'],
 [economy,/SINGLE_PULL_JADE_COST:\s*int\s*=\s*100/,'SINGLE_COST'],
 [economy,/TEN_PULL_JADE_COST:\s*int\s*=\s*900/,'TEN_COST'],
 [economy,/NATURAL_LEGENDARY_WISH_CHANCE:\s*float\s*=\s*0\.50/,'WISH_CHANCE'],
 [inventory,/"common":\s*5/,'COMMON_SHARDS'],
 [inventory,/"rare":\s*12/,'RARE_SHARDS'],
 [inventory,/"epic":\s*30/,'EPIC_SHARDS'],
 [inventory,/"legendary":\s*75/,'LEGENDARY_SHARDS'],
 [pavilion,/func _roll_rarity\(/,'RARITY_ALGORITHM_PRESENT'],
 [pavilion,/func _choose_item_for_rarity\(/,'PICK_ALGORITHM_PRESENT'],
 [pavilion,/func _advance_pity\(/,'PITY_ALGORITHM_PRESENT'],
];
for(const [content,rx,label] of required){if(!rx.test(content))throw Error('GAME_RULE_CHANGED_STOP:'+label);}
console.log('GAME_CATALOG_PARITY=PASS_40');
console.log('GAME_SUMMON_RULE_SIGNATURE=PASS');
