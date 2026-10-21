import {updatePushAdminRoute} from './update_push.mjs';
import {odysseyAdmin,odysseyDashboard} from './odyssey.mjs';
import {MailError,fail,json,readBody,exact,digest,mac,checkProof,session,login,sameOrigin,randomId,nowSeconds} from './mail_admin.mjs';
import {ownerBinding} from './worker.mjs';
import dashboard from './dashboard.mjs';
import {pavilionRoute} from './pavilion.mjs';
import {announcementAdminRoute,announcementPlayerRoute,listAnnouncementEntries} from './announcements.mjs';
import {normalizeReward,hasReward,needsGiftClient,REWARD_CATALOG,EXPANSION_CLIENT_FENCE_IDS as EXPANSION_ITEM_IDS} from './mail_rewards.mjs';
export {REWARD_CATALOG};
import {studioRoute,historyPage,countRecipients,selector,segment,audit} from './mail_studio.mjs';
export {MailError};
const ID=/^[a-f0-9]{32}$/;
const UID=/^JA[0-9A-HJKMNP-TV-Z]{10}$/;
export async function mapMailBatch(entries,operation){const out=[];for(let offset=0;offset<entries.length;offset+=4)out.push(...await Promise.all(entries.slice(offset,offset+4).map(operation)));return out;}
const primary=db=>db?.withSession?db.withSession('first-primary'):db;
const list=async statement=>(await statement.all()).results;
const install=value=>{if(!ID.test(value||''))fail(400,'invalid_installation');return value;};
const mailId=value=>{if(!ID.test(value||''))fail(400,'invalid_mail_id');return value;};
const integer=(value,min,max)=>{if(!Number.isSafeInteger(value)||value<min||value>max)fail(400,'invalid_amount');return value;};
export function normalizeDraft(input,time=nowSeconds(),allowRetired=false){
 exact(input,['title','body','sender','audience','target_uid','expires_at','reward','segment']);
 const text=(value,max)=>{if(typeof value!=='string'||!value.trim()||value.length>max||/[\x00-\x08\x0b\x0c\x0e-\x1f]/.test(value))fail(400,'invalid_text');return value.trim();};
 if(!['uid','all','segment'].includes(input.audience))fail(400,'invalid_audience');
 const target=input.audience==='uid'?String(input.target_uid||'').trim().toUpperCase():'';
 if(input.audience==='uid'&&!UID.test(target))fail(400,'invalid_uid');
 if(input.audience!=='uid'&&input.target_uid)fail(400,'invalid_uid');
 integer(input.expires_at,time+60,time+90*86400);
 const reward=input.reward;if(!reward||typeof reward!=='object'||Array.isArray(reward))fail(400,'invalid_reward');
 const normalizedReward=normalizeReward(reward,allowRetired);
 return {title:text(input.title,100),body:text(input.body,4000),sender:text(input.sender,60),audience:input.audience,target_uid:target,expires_at:input.expires_at,reward:normalizedReward,...(input.audience==='segment'?{segment:segment(input.segment)}:{})};
}
const recipientCount=countRecipients;
async function preview(db,env,input){
 const draft=normalizeDraft(input),count=await recipientCount(db,draft);if(count<1)fail(404,'recipient_not_found');if(count>50000)fail(400,'audience_limit');
 const fingerprint=await digest(JSON.stringify(draft)),expires=nowSeconds()+300;
 return {draft,recipient_count:count,confirm_expires_at:expires,confirm_token:await mac(env,`preview:${fingerprint}:${count}:${expires}`)};
}
export async function sendMail(db,env,input,jobId=''){
 exact(input,['draft','recipient_count','confirm_expires_at','confirm_token','request_id']);mailId(input.request_id);
 // Expiry can pass during a lost-response retry; existing immutable sends may
 // be read again, but never republished or expanded to newly registered users.
 const existing=await db.prepare('SELECT * FROM mail_campaigns WHERE request_id=?').bind(input.request_id).first();
 const draft=normalizeDraft(input.draft,Math.min(nowSeconds(),Number(input.draft?.expires_at)-60),Boolean(existing));
 const fingerprint=await digest(JSON.stringify(draft));
 if(existing){if(existing.fingerprint!==fingerprint)fail(409,'request_reused');return campaign(db,existing);}
 if(draft.expires_at<=nowSeconds()+60)fail(400,'invalid_expiry');
 integer(input.recipient_count,1,50000);integer(input.confirm_expires_at,nowSeconds()+1,nowSeconds()+300);
 if(!await checkProof(env,`preview:${fingerprint}:${input.recipient_count}:${input.confirm_expires_at}`,input.confirm_token))fail(403,'preview_required');
 const id=randomId(),time=nowSeconds(),selection=selector(draft,time),jobGuard=jobId?' AND EXISTS(SELECT 1 FROM mail_jobs WHERE id=? AND state=\'scheduled\')':'',jobArgs=jobId?[jobId]:[];
 await db.batch([
  db.prepare('INSERT OR IGNORE INTO mail_campaigns(id,request_id,fingerprint,title,body,sender,reward_json,audience,target_uid,created_at,expires_at) SELECT ?,?,?,?,?,?,?,?,?,?,? WHERE (SELECT count(*) FROM player_identities p WHERE '+selection.sql+')=?'+jobGuard).bind(id,input.request_id,fingerprint,draft.title,draft.body,draft.sender,JSON.stringify(draft.reward),draft.audience==='segment'?'all':draft.audience,draft.audience==='segment'?JSON.stringify(draft.segment):draft.target_uid,time,draft.expires_at,...selection.args,input.recipient_count,...jobArgs),
  db.prepare('INSERT OR IGNORE INTO mail_recipients(mail_id,owner_binding) SELECT c.id,p.owner_binding FROM mail_campaigns c JOIN player_identities p ON ('+selection.sql+') WHERE c.request_id=? AND c.fingerprint=? AND c.published_at=0').bind(...selection.args,input.request_id,fingerprint),
  db.prepare('UPDATE mail_campaigns SET published_at=? WHERE request_id=? AND fingerprint=? AND published_at=0').bind(time,input.request_id,fingerprint),
  ...(jobId?[db.prepare('UPDATE mail_jobs SET state=\'sent\',campaign_id=(SELECT id FROM mail_campaigns WHERE request_id=?),updated_at=? WHERE id=? AND state=\'scheduled\' AND EXISTS(SELECT 1 FROM mail_campaigns WHERE request_id=?)').bind(input.request_id,time,jobId,input.request_id)]:[])
 ]);
 const row=await db.prepare('SELECT * FROM mail_campaigns WHERE request_id=?').bind(input.request_id).first();
 if(!row)fail(409,'preview_stale');if(row.fingerprint!==fingerprint)fail(409,'request_reused');return campaign(db,row);
}
async function campaign(db,row){
 const stats=await db.prepare('SELECT count(*) AS recipients,sum(CASE WHEN r.delivered_at>0 THEN 1 ELSE 0 END) AS delivered,sum(CASE WHEN r.read_at>0 THEN 1 ELSE 0 END) AS read_count,sum(CASE WHEN k.reserved_at>0 THEN 1 ELSE 0 END) AS reserved,sum(CASE WHEN k.acknowledged_at>0 AND NOT EXISTS(SELECT 1 FROM mail_claim_resolution x WHERE x.mail_id=k.mail_id AND x.owner_binding=k.owner_binding) THEN 1 ELSE 0 END) AS claimed,sum(CASE WHEN EXISTS(SELECT 1 FROM mail_claim_resolution x WHERE x.mail_id=k.mail_id AND x.owner_binding=k.owner_binding) THEN 1 ELSE 0 END) AS resolved FROM mail_recipients r LEFT JOIN mail_claims k ON k.mail_id=r.mail_id AND k.owner_binding=r.owner_binding WHERE r.mail_id=?').bind(row.id).first();
 return {id:row.id,title:row.title,body:row.body,sender:row.sender,audience:row.target_uid.startsWith('{')?'segment':row.audience,target_uid:row.target_uid.startsWith('{')?'':row.target_uid,...(row.target_uid.startsWith('{')?{segment:JSON.parse(row.target_uid)}:{}),reward:JSON.parse(row.reward_json),created_at:row.created_at,expires_at:row.expires_at,cancelled:row.cancelled_at>0,...Object.fromEntries(Object.entries(stats).map(([k,v])=>[k,v??0]))};
}
async function getRecipient(db,owner,id){const row=await db.prepare('SELECT c.*,r.delivered_at,r.read_at,r.deleted_at FROM mail_campaigns c JOIN mail_recipients r ON r.mail_id=c.id WHERE r.owner_binding=? AND c.id=? AND c.published_at>0').bind(owner,id).first();if(!row)fail(404,'mail_not_found');return row;}
async function receipt(db,owner,id){return db.prepare('SELECT * FROM mail_claims WHERE owner_binding=? AND mail_id=?').bind(owner,id).first();}
export async function claimMail(db,owner,input,giftClient=false,chainClient=false,glaiveClient=false,expansionClient=false,odysseyClient=false){
 exact(input,['mail_id','installation_id']);const id=mailId(input.mail_id),installation=install(input.installation_id);
 const letter=await getRecipient(db,owner,id);if(!odysseyClient&&JSON.parse(letter.reward_json).items?.heavenweaver_compass)fail(409,'client_upgrade_required');if(!expansionClient&&EXPANSION_ITEM_IDS.some(key=>JSON.parse(letter.reward_json).items?.[key]))fail(409,'client_upgrade_required');if(!glaiveClient&&JSON.parse(letter.reward_json).items?.celestial_returning_glaive)fail(409,'client_upgrade_required');if(!chainClient&&JSON.parse(letter.reward_json).items?.jade_binding_chain)fail(409,'client_upgrade_required');if(!giftClient&&needsGiftClient(JSON.parse(letter.reward_json)))fail(409,'client_upgrade_required');let held=await receipt(db,owner,id);
 if(!held){
  if(!hasReward(JSON.parse(letter.reward_json)))fail(409,'no_attachment');
  // Eligibility is checked in the INSERT itself so cancellation/expiry cannot
  // race a separate read. One unique (mail,owner) reservation wins all devices.
  await db.prepare('INSERT OR IGNORE INTO mail_claims(mail_id,owner_binding,installation_id,receipt_id,reward_json,reserved_at) SELECT c.id,r.owner_binding,?,?,c.reward_json,? FROM mail_campaigns c JOIN mail_recipients r ON r.mail_id=c.id WHERE c.id=? AND r.owner_binding=? AND c.published_at>0 AND c.cancelled_at=0 AND c.expires_at>? AND r.deleted_at=0').bind(installation,randomId(),nowSeconds(),id,owner,nowSeconds()).run();
  held=await receipt(db,owner,id);if(!held)fail(409,'mail_unavailable');
 }
 if(held.acknowledged_at>0)return {mail_id:id,owner_binding:owner,delivery_state:'claimed'};
 if(held.installation_id!==installation)fail(409,'claimed_on_other_device');
 return {mail_id:id,owner_binding:owner,installation_id:installation,receipt_id:held.receipt_id,delivery_state:'pending',reward:JSON.parse(held.reward_json)};
}
export async function acknowledgeMail(db,owner,input){
 exact(input,['mail_id','installation_id','receipt_id']);const id=mailId(input.mail_id),installation=install(input.installation_id),receiptId=mailId(input.receipt_id);
 const held=await receipt(db,owner,id);if(!held||held.installation_id!==installation||held.receipt_id!==receiptId)fail(409,'receipt_mismatch');
 await db.batch([db.prepare('UPDATE mail_claims SET acknowledged_at=? WHERE mail_id=? AND owner_binding=? AND acknowledged_at=0').bind(nowSeconds(),id,owner),db.prepare('UPDATE mail_recipients SET read_at=CASE WHEN read_at=0 THEN ? ELSE read_at END WHERE mail_id=? AND owner_binding=?').bind(nowSeconds(),id,owner)]);
 return {mail_id:id,owner_binding:owner,delivery_state:'claimed'};
}
async function inbox(db,owner,url,giftClient=false,chainClient=false,glaiveClient=false,announcementClient=false,expansionClient=false,odysseyClient=false){
 const installation=install(url.searchParams.get('installation_id'));
 const after=url.searchParams.get('after')||'';if(after&&!ID.test(after))fail(400,'invalid_cursor');
 const rows=await list(db.prepare('SELECT c.*,r.read_at,r.deleted_at,k.installation_id AS claim_installation,k.receipt_id,k.acknowledged_at,k.reserved_at FROM mail_campaigns c JOIN mail_recipients r ON r.mail_id=c.id LEFT JOIN mail_claims k ON k.mail_id=r.mail_id AND k.owner_binding=r.owner_binding WHERE r.owner_binding=? AND c.published_at>0 AND r.deleted_at=0 AND c.id>? '+(giftClient?'':"AND COALESCE(json_extract(c.reward_json,'$.celestial_jade'),0)=0 AND COALESCE(json_extract(c.reward_json,'$.pavilion_seal'),0)=0 AND NOT EXISTS(SELECT 1 FROM json_each(json_extract(c.reward_json,'$.items')) j WHERE j.key<>'refinement_shard') " )+(chainClient?'':"AND COALESCE(json_extract(c.reward_json,'$.items.jade_binding_chain'),0)=0 " )+(glaiveClient?'':"AND COALESCE(json_extract(c.reward_json,'$.items.celestial_returning_glaive'),0)=0 " )+(expansionClient?'':"AND NOT EXISTS(SELECT 1 FROM json_each(json_extract(c.reward_json,'$.items')) j WHERE j.key IN ("+EXPANSION_ITEM_IDS.map(id=>"'"+id+"'").join(',')+")) ")+(odysseyClient?'':"AND COALESCE(json_extract(c.reward_json,'$.items.heavenweaver_compass'),0)=0 ")+'ORDER BY c.id LIMIT 41'  ).bind(owner,after));
 const page=rows.slice(0,40),time=nowSeconds();
 if(page.length)await db.batch(page.map(row=>db.prepare('UPDATE mail_recipients SET delivered_at=? WHERE owner_binding=? AND mail_id=? AND delivered_at=0').bind(time,owner,row.id)));
 return {version:1,owner_binding:owner,server_time:time,next_cursor:rows.length>40?page.at(-1).id:'',...(announcementClient&&rows.length<=40?{announcements:await listAnnouncementEntries(db,owner,time)}:{}),entries:page.map(row=>{
  const reward=JSON.parse(row.reward_json),claimed=row.acknowledged_at>0,own=row.claim_installation===installation,pending=!!row.reserved_at&&!claimed;
  return {id:'server:'+row.id,mail_id:row.id,title:row.title,body:row.body,sender:row.sender,reward:hasReward(reward)?reward:{},created_at:row.created_at,expires_at:row.expires_at,read:row.read_at>0,claimed:claimed||!hasReward(reward),pending:pending&&own,receipt_id:pending&&own?row.receipt_id:'',can_claim:!claimed&&hasReward(reward)&&(!pending||own)&&(pending||(!row.cancelled_at&&row.expires_at>time)),blocked_on_other_device:pending&&!own,cancelled:row.cancelled_at>0,expired:row.expires_at<=time};
 })};
}
export function createMailHandler({verify}={}){
 return async(request,env)=>{
  const url=new URL(request.url),path=url.pathname,db=primary(env.PROFILE_DB);if(!db)fail(503,'service_unavailable');
  if(path.startsWith('/admin/assets/')){await session(request,env);if(request.method!=='GET'||!/^\/admin\/assets\/[a-z0-9_]+\.png$/.test(path)||!env.ASSETS)fail(404,'not_found');return env.ASSETS.fetch(request);}
  if(path==='/admin/odyssey'){await session(request,env);if(request.method!=='GET')fail(405,'method_not_allowed');const nonce=randomId();return new Response(odysseyDashboard.replaceAll('__NONCE__',nonce),{headers:{'content-type':'text/html;charset=utf-8','cache-control':'no-store','content-security-policy':`default-src 'none'; script-src 'nonce-${nonce}'; style-src 'nonce-${nonce}'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'`}});}
  if(path==='/admin'||path==='/admin/'){
   if(request.method!=='GET')fail(405,'method_not_allowed');const nonce=randomId();
   return new Response(dashboard.replaceAll('__NONCE__',nonce),{headers:{'content-type':'text/html;charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer','content-security-policy':`default-src 'none'; script-src 'nonce-${nonce}'; style-src 'nonce-${nonce}'; style-src-attr 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; base-uri 'none'; frame-ancestors 'none'; form-action 'self'`}});
  }
  if(path==='/admin/api/login'){if(request.method!=='POST')fail(405,'method_not_allowed');return login(request,env,db);}
  if(path.startsWith('/admin/api/')){
   const auth=await session(request,env,request.method!=='GET');
   if(path==='/admin/api/odyssey')return odysseyAdmin(request,env);
   const update=await updatePushAdminRoute(db,env,request,url);if(update)return update;
   const announcement=await announcementAdminRoute(db,env,request,url);if(announcement)return announcement;
   if(path==='/admin/api/session'&&request.method==='GET')return json(200,{...auth,reward_catalog:REWARD_CATALOG});
   const bannerResponse=await pavilionRoute(db,request,url);if(bannerResponse)return bannerResponse;
   const upgraded=await studioRoute(db,env,request,url,auth,{normalizeDraft,preview,sendMail,campaign,verifyPreview});if(upgraded)return upgraded;
   if(path==='/admin/api/logout'&&request.method==='POST')return json(200,{ok:true},{'set-cookie':'jade_admin=; Path=/admin; HttpOnly; Secure; SameSite=Strict; Max-Age=0'});
   if(path==='/admin/api/preview'&&request.method==='POST')return json(200,await preview(db,env,await readBody(request)));
   if(path==='/admin/api/send'&&request.method==='POST'){const sent=await sendMail(db,env,await readBody(request));await audit(db,'send',{mail_id:sent.id});return json(200,sent);}
   if(path==='/admin/api/history'&&request.method==='GET'){
    return json(200,await historyPage(db,url,campaign));
   }
   if(path==='/admin/api/recipients'&&request.method==='GET'){
    const id=mailId(url.searchParams.get('mail_id')),after=url.searchParams.get('after')||'';if(after&&!UID.test(after))fail(400,'invalid_cursor');
    const rows=await list(db.prepare('SELECT p.public_uid,r.delivered_at,r.read_at,r.deleted_at,k.reserved_at,k.acknowledged_at,(SELECT resolved_at FROM mail_claim_resolution x WHERE x.mail_id=k.mail_id AND x.owner_binding=k.owner_binding) AS resolved_at FROM mail_recipients r JOIN player_identities p ON p.owner_binding=r.owner_binding LEFT JOIN mail_claims k ON k.mail_id=r.mail_id AND k.owner_binding=r.owner_binding WHERE r.mail_id=? AND p.public_uid>? ORDER BY p.public_uid LIMIT 101').bind(id,after));
    return json(200,{entries:rows.slice(0,100),next_cursor:rows.length>100?rows[99].public_uid:''});
   }
   if(path==='/admin/api/cancel'&&request.method==='POST'){
    const input=await readBody(request);exact(input,['mail_id']);const id=mailId(input.mail_id);
    const row=await db.prepare('SELECT * FROM mail_campaigns WHERE id=? AND published_at>0').bind(id).first();if(!row)fail(404,'mail_not_found');
    await db.prepare('UPDATE mail_campaigns SET cancelled_at=? WHERE id=? AND cancelled_at=0').bind(nowSeconds(),id).run();return json(200,{ok:true});
   }
   fail(404,'not_found');
  }
  if(!path.startsWith('/v1/mail/'))fail(404,'not_found');
  const owner=await ownerBinding(await verify(request,env));
  // A native token callback can race an account switch. This untrusted header
  // can only narrow the signed identity, never select a different recipient.
  if(request.headers.get('x-jade-owner-binding')!==owner)fail(409,'account_changed');
  if(!await db.prepare('SELECT public_uid FROM player_identities WHERE owner_binding=?').bind(owner).first())fail(409,'profile_required');
  const announcement=await announcementPlayerRoute(db,owner,request,url);if(announcement)return announcement;
  const version=request.headers.get('x-jade-client-version')||'';
  await db.prepare('INSERT INTO mail_player_activity(owner_binding,last_seen,client_version) VALUES(?,?,?) ON CONFLICT(owner_binding) DO UPDATE SET last_seen=excluded.last_seen,client_version=CASE WHEN excluded.client_version<>\'\' THEN excluded.client_version ELSE client_version END').bind(owner,nowSeconds(),/^[a-zA-Z0-9._+-]{1,40}$/.test(version)?version:'').run();
  if(path==='/v1/mail/list'&&request.method==='GET')return json(200,await inbox(db,owner,url,request.headers.get('x-jade-mail-features')==='gifts-v2',request.headers.get('x-jade-equipment-catalog')==='jade-chain-v1',request.headers.get('x-jade-returning-glaive')==='v1',request.headers.get('x-jade-announcements')==='v1',request.headers.get('x-jade-ascendant-arsenal')==='v1',request.headers.get('x-jade-odyssey')==='v1'));
  if(request.method!=='POST')fail(405,'method_not_allowed');const input=await readBody(request,path.endsWith('_batch')?4096:512);
  if(path==='/v1/mail/claim_batch'||path==='/v1/mail/ack_batch'){
   exact(input,['entries']);
   if(!Array.isArray(input.entries)||input.entries.length<1||input.entries.length>8)fail(400,'invalid_batch');
   const ids=new Set();
   // Validate the whole envelope before touching any reservation.
   for(const entry of input.entries){exact(entry,path.endsWith('claim_batch')?['mail_id','installation_id']:['mail_id','installation_id','receipt_id']);mailId(entry.mail_id);install(entry.installation_id);if(path.endsWith('ack_batch'))mailId(entry.receipt_id);if(ids.has(entry.mail_id))fail(400,'duplicate_mail');ids.add(entry.mail_id);}
   const entries=await mapMailBatch(input.entries,async entry=>{try{
    const entryDb=primary(env.PROFILE_DB);
    const result=path.endsWith('claim_batch')?await claimMail(entryDb,owner,entry,request.headers.get('x-jade-mail-features')==='gifts-v2',request.headers.get('x-jade-equipment-catalog')==='jade-chain-v1',request.headers.get('x-jade-returning-glaive')==='v1',request.headers.get('x-jade-ascendant-arsenal')==='v1',request.headers.get('x-jade-odyssey')==='v1'):await acknowledgeMail(entryDb,owner,entry);
    return {...result,success:true};
   }catch(error){if(!(error instanceof MailError)||error.status>=500)throw error;return {mail_id:entry.mail_id,success:false,error:error.code};}});
   return json(200,{owner_binding:owner,entries});
  }
  if(path==='/v1/mail/delete_all'){
   exact(input,[]);
   // Hide completed/expired letters only. Never discard unclaimed gifts or an
   // unacknowledged lease, and never erase campaign/receipt audit records.
   const changed=await db.prepare(`UPDATE mail_recipients SET deleted_at=? WHERE owner_binding=? AND deleted_at=0
    AND NOT EXISTS(SELECT 1 FROM mail_claims k WHERE k.mail_id=mail_recipients.mail_id AND k.owner_binding=mail_recipients.owner_binding AND k.acknowledged_at=0)
    AND (EXISTS(SELECT 1 FROM mail_claims k WHERE k.mail_id=mail_recipients.mail_id AND k.owner_binding=mail_recipients.owner_binding AND k.acknowledged_at>0)
     OR EXISTS(SELECT 1 FROM mail_campaigns c WHERE c.id=mail_recipients.mail_id AND (c.expires_at<=? OR c.cancelled_at>0 OR (COALESCE(json_extract(c.reward_json,'$.spirit_stone'),0)=0 AND COALESCE(json_extract(c.reward_json,'$.celestial_jade'),0)=0 AND COALESCE(json_extract(c.reward_json,'$.pavilion_seal'),0)=0 AND NOT EXISTS(SELECT 1 FROM json_each(json_extract(c.reward_json,'$.items')))))))`).bind(nowSeconds(),owner,nowSeconds()).run();
   return json(200,{ok:true,owner_binding:owner,deleted_count:changed.meta?.changes||0});
  }
  if(path==='/v1/mail/claim')return json(200,await claimMail(db,owner,input,request.headers.get('x-jade-mail-features')==='gifts-v2',request.headers.get('x-jade-equipment-catalog')==='jade-chain-v1',request.headers.get('x-jade-returning-glaive')==='v1',request.headers.get('x-jade-ascendant-arsenal')==='v1',request.headers.get('x-jade-odyssey')==='v1'));
  if(path==='/v1/mail/ack')return json(200,await acknowledgeMail(db,owner,input));
  if(path==='/v1/mail/read_all'){
   exact(input,[]);await db.prepare('UPDATE mail_recipients SET read_at=? WHERE owner_binding=? AND read_at=0 AND deleted_at=0').bind(nowSeconds(),owner).run();return json(200,{ok:true,owner_binding:owner});
  }
  exact(input,['mail_id']);const id=mailId(input.mail_id),row=await getRecipient(db,owner,id);
  if(path==='/v1/mail/read'){
   await db.prepare('UPDATE mail_recipients SET read_at=? WHERE mail_id=? AND owner_binding=? AND read_at=0').bind(nowSeconds(),id,owner).run();return json(200,{ok:true,mail_id:id,owner_binding:owner});
  }
  if(path==='/v1/mail/delete'){
   // Pending reservations must finish before deletion, even after expiry.
   await db.prepare('UPDATE mail_recipients SET deleted_at=? WHERE mail_id=? AND owner_binding=? AND NOT EXISTS(SELECT 1 FROM mail_claims k WHERE k.mail_id=? AND k.owner_binding=? AND k.acknowledged_at=0) AND (?=1 OR EXISTS(SELECT 1 FROM mail_claims k WHERE k.mail_id=? AND k.owner_binding=? AND k.acknowledged_at>0))').bind(nowSeconds(),id,owner,id,owner,!hasReward(JSON.parse(row.reward_json))||row.expires_at<=nowSeconds()||row.cancelled_at>0?1:0,id,owner).run();
   if(!(await getRecipient(db,owner,id)).deleted_at)fail(409,'claim_before_delete');return json(200,{ok:true,mail_id:id,owner_binding:owner});
  }
  fail(404,'not_found');
 };
}

export async function verifyPreview(db,env,input){
 const draft=normalizeDraft(input.draft);const fingerprint=await digest(JSON.stringify(draft));
 integer(input.recipient_count,1,50000);integer(input.confirm_expires_at,nowSeconds()+1,nowSeconds()+300);
 if(!await checkProof(env,`preview:${fingerprint}:${input.recipient_count}:${input.confirm_expires_at}`,input.confirm_token))fail(403,'preview_required');
 if(await recipientCount(db,draft)!==input.recipient_count)fail(409,'preview_stale');return draft;
}
export async function processScheduled(env){
 const db=primary(env.PROFILE_DB),time=nowSeconds();
 const jobs=await list(db.prepare("SELECT * FROM mail_jobs WHERE state='scheduled' AND run_at<=? AND updated_at<=? ORDER BY run_at,id LIMIT 3").bind(time,time-30));
 for(const job of jobs){try{
   if(JSON.parse(job.draft_json).expires_at<=nowSeconds()+60)fail(400,'invalid_expiry');
   const p=await preview(db,env,JSON.parse(job.draft_json));await sendMail(db,env,{...p,request_id:job.request_id},job.id);
  }catch(error){
   const permanent=error instanceof MailError&&[400,404].includes(error.status);
   await db.prepare("UPDATE mail_jobs SET state=?,error_code=?,updated_at=? WHERE id=? AND state='scheduled'").bind(permanent?'failed':'scheduled',permanent?error.code:'retry_pending',nowSeconds(),job.id).run();
   console.warn('JADE_MAIL_SCHEDULE stage='+ (permanent?'failed':'retry_pending'));
  }
 }
}
