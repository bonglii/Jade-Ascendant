import {EXPANSION_ITEM_IDS} from './mail_rewards.mjs';
import {fail,json,exact,readBody,digest,randomId,nowSeconds} from './mail_admin.mjs';
import {REWARD_CATALOG} from './mail_rewards.mjs';
const ID=/^[a-f0-9]{32}$/;
export const ARTWORKS=[{id:'sanctum',name:'Jade Sanctum'},{id:'celestial_gate',name:'Celestial Gate'}];
export const BASE_RATES={common:6000,rare:2900,epic:900,legendary:200};
export const FEATURED_CATALOG=Object.values(REWARD_CATALOG).filter(x=>x.rarity==='legendary');
const itemIds=new Set(FEATURED_CATALOG.map(x=>x.id));
const number=(value,min,max)=>{if(!Number.isSafeInteger(value)||value<min||value>max)fail(400,'invalid_banner_value');return value;};
const text=(value,max)=>{if(typeof value!=='string'||!value.trim()||value.length>max||/[\x00-\x1f<>]/.test(value))fail(400,'invalid_banner_text');return value.trim();};
export function normalizeDocument(input){
 exact(input,['banners']);if(!Array.isArray(input.banners)||input.banners.length>12)fail(400,'banner_limit');
 const seen=new Set();return {banners:input.banners.map(b=>{
  exact(b,['id','title','subtitle','artwork','featured','rates','starts_at','ends_at','enabled']);
  if(!ID.test(b.id||'')||seen.has(b.id))fail(400,'invalid_banner_id');seen.add(b.id);
  if(typeof b.enabled!=='boolean')fail(400,'invalid_banner_value');
  if(!ARTWORKS.some(x=>x.id===b.artwork))fail(400,'invalid_banner_artwork');
  if(!Array.isArray(b.featured)||b.featured.length<1||b.featured.length>5||new Set(b.featured).size!==b.featured.length||b.featured.some(id=>!itemIds.has(id)))fail(400,'invalid_banner_equipment');
  exact(b.rates,Object.keys(BASE_RATES));let total=0;for(const key of Object.keys(BASE_RATES))total+=number(b.rates[key],1,10000);if(total!==10000)fail(400,'invalid_banner_rates');
  const starts=number(b.starts_at,0,4102444800),ends=number(b.ends_at,starts+60,4102444800);if(ends-starts>90*86400)fail(400,'invalid_banner_schedule');
  return {id:b.id,title:text(b.title,60),subtitle:text(b.subtitle,100),artwork:b.artwork,featured:[...b.featured],rates:{...b.rates},starts_at:starts,ends_at:ends,enabled:b.enabled};
 })};
}
export async function currentDocument(db){
 const control=await db.prepare('SELECT revision FROM pavilion_control WHERE id=1').first();
 const row=control?.revision?await db.prepare('SELECT document_json FROM pavilion_revisions WHERE revision=?').bind(control.revision).first():null;
 return {revision:control?.revision||0,document:row?JSON.parse(row.document_json):{banners:[]}};
}
export function activeBanner(document,time){
 // Most recent entry has priority; this also allows immediate replacements.
 return [...document.banners].reverse().find(b=>b.enabled&&b.starts_at<=time&&b.ends_at>time)||null;
}
export function publicSnapshot(current,time=nowSeconds(),expansionClient=false){
 let validUntil=time+300;
 for(const b of current.document.banners)if(b.enabled)for(const point of [b.starts_at,b.ends_at])if(point>time)validUntil=Math.min(validUntil,point);
 return {version:1,revision:current.revision,server_time:time,valid_until:validUntil,banner:(()=>{const selected=activeBanner(current.document,time);if(!selected)return null;const featured=selected.featured.filter(id=>id!=="astral_resonance_bell"&&(expansionClient||!EXPANSION_ITEM_IDS.includes(id)));return featured.length?{...selected,featured}:null;})()};
}
export async function publishDocument(db,input){
 exact(input,['expected_revision','request_id','document']);number(input.expected_revision,0,Number.MAX_SAFE_INTEGER-1);if(!ID.test(input.request_id||''))fail(400,'invalid_banner_id');
 const document=normalizeDocument(input.document),fingerprint=await digest(JSON.stringify(document));
 const existing=await db.prepare('SELECT revision,fingerprint FROM pavilion_revisions WHERE request_id=?').bind(input.request_id).first();
 if(existing){if(existing.fingerprint!==fingerprint)fail(409,'request_reused');return {...await currentDocument(db),published_revision:existing.revision};}
 const revision=input.expected_revision+1,operation=randomId(),time=nowSeconds();
 // D1 batch is atomic; the unique operation guards INSERT/audit on stale CAS.
 await db.batch([
  db.prepare('UPDATE pavilion_control SET revision=?,operation_id=? WHERE id=1 AND revision=?').bind(revision,operation,input.expected_revision),
  db.prepare('INSERT INTO pavilion_revisions(revision,request_id,fingerprint,document_json,created_at) SELECT ?,?,?,?,? WHERE EXISTS(SELECT 1 FROM pavilion_control WHERE id=1 AND revision=? AND operation_id=?)').bind(revision,input.request_id,fingerprint,JSON.stringify(document),time,revision,operation),
  db.prepare("INSERT INTO mail_admin_audit(id,action,detail_json,created_at) SELECT ?,'banner_publish',?,? WHERE EXISTS(SELECT 1 FROM pavilion_control WHERE id=1 AND revision=? AND operation_id=?)").bind(randomId(),JSON.stringify({revision}),time,revision,operation)
 ]);
 const applied=await db.prepare('SELECT revision,fingerprint FROM pavilion_revisions WHERE request_id=?').bind(input.request_id).first();
 if(!applied)fail(409,'banner_stale');if(applied.fingerprint!==fingerprint)fail(409,'request_reused');return {...await currentDocument(db),published_revision:applied.revision};
}
export async function pavilionRoute(db,request,url){
 const path=url.pathname;
 if(path==='/admin/api/pavilion'&&request.method==='GET')return json(200,{...await currentDocument(db),server_time:nowSeconds(),catalog:FEATURED_CATALOG,artworks:ARTWORKS,base_rates:BASE_RATES});
 if(path==='/admin/api/pavilion/publish'&&request.method==='POST')return json(200,await publishDocument(db,await readBody(request)));
 if(path==='/admin/api/pavilion/revisions'&&request.method==='GET')return json(200,{entries:(await db.prepare('SELECT revision,document_json,created_at FROM pavilion_revisions ORDER BY revision DESC LIMIT 30').all()).results.map(r=>({revision:r.revision,document:JSON.parse(r.document_json),created_at:r.created_at}))});
 return null;
}
