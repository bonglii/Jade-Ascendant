import {fail,json,readBody,exact,randomId,nowSeconds,digest} from './mail_admin.mjs';
import {accountRoute} from './mail_account.mjs';
const ID=/^[a-f0-9]{32}$/,UID=/^JA[0-9A-HJKMNP-TV-Z]{10}$/;
const rows=async s=>(await s.all()).results;
const validID=id=>{if(!ID.test(id||''))fail(400,'invalid_mail_id');return id;};
export function selector(draft,time=nowSeconds()){
 if(draft.audience==='uid')return {sql:'p.public_uid=?',args:[draft.target_uid]};
 if(draft.audience==='all')return {sql:'1=1',args:[]};
 const segment=draft.segment;
 if(segment.kind==='version')return {sql:'EXISTS(SELECT 1 FROM mail_player_activity a WHERE a.owner_binding=p.owner_binding AND a.client_version=?)',args:[segment.value]};
 if(segment.kind==='registered7')return {sql:'p.created_at>=?',args:[time-7*86400]};
 return {sql:'EXISTS(SELECT 1 FROM mail_player_activity a WHERE a.owner_binding=p.owner_binding AND a.last_seen'+(segment.kind==='inactive30'?'<':'>=')+'?)',args:[time-(segment.kind==='active7'?7:30)*86400]};
}
export function segment(input){exact(input,['kind','value']);if(!['active7','active30','inactive30','registered7','version'].includes(input.kind))fail(400,'invalid_segment');const value=input.kind==='version'?input.value:'';if(input.kind==='version'&&(typeof value!=='string'||!/^[a-zA-Z0-9._+-]{1,40}$/.test(value)))fail(400,'invalid_segment');return {kind:input.kind,value};}
export async function countRecipients(db,draft){const s=selector(draft);return (await db.prepare('SELECT count(*) AS n FROM player_identities p WHERE '+s.sql).bind(...s.args).first()).n;}
export async function audit(db,action,detail){await db.prepare('INSERT INTO mail_admin_audit(id,action,detail_json,created_at) VALUES(?,?,?,?)').bind(randomId(),action,JSON.stringify(detail),nowSeconds()).run();}
export function historyFilter(url){
 const archive=url.searchParams.get('archive')==='1',query=(url.searchParams.get('q')||'').trim().slice(0,100),status=url.searchParams.get('status')||'all';
 if(!['all','active','expired','cancelled','pending'].includes(status))fail(400,'invalid_filter');
 let sql='c.published_at>0 AND '+(archive?'':'NOT ')+'EXISTS(SELECT 1 FROM mail_archives a WHERE a.mail_id=c.id)';const args=[];
 if(query){sql+=' AND (instr(lower(c.title),lower(?))>0 OR c.id=? OR EXISTS(SELECT 1 FROM mail_recipients r JOIN player_identities p ON p.owner_binding=r.owner_binding WHERE r.mail_id=c.id AND p.public_uid=?))';args.push(query,query,query.toUpperCase());}
 if(status==='active'){sql+=' AND c.cancelled_at=0 AND c.expires_at>?';args.push(nowSeconds());}
 if(status==='expired'){sql+=' AND c.cancelled_at=0 AND c.expires_at<=?';args.push(nowSeconds());}
 if(status==='cancelled')sql+=' AND c.cancelled_at>0';
 if(status==='pending')sql+=' AND EXISTS(SELECT 1 FROM mail_claims k WHERE k.mail_id=c.id AND k.acknowledged_at=0)';
 return {sql,args};
}
export async function historyPage(db,url,campaign){
 const before=Number(url.searchParams.get('before')||Number.MAX_SAFE_INTEGER);if(!Number.isSafeInteger(before)||before<1)fail(400,'invalid_cursor');const filter=historyFilter(url);
 const data=await rows(db.prepare('SELECT c.rowid AS cursor,c.* FROM mail_campaigns c WHERE '+filter.sql+' AND c.rowid<? ORDER BY c.rowid DESC LIMIT 31').bind(...filter.args,before));
 return {entries:await Promise.all(data.slice(0,30).map(row=>campaign(db,row))),next_cursor:data.length>30?data[29].cursor:null,cutoff:data[0]?.cursor||0};
}
const csv=value=>'"'+String(value??'').replaceAll('"','""').replace(/^[=+@\-\t\r]/,"'$&")+'"';
export async function studioRoute(db,env,request,url,auth,helpers){
 const path=url.pathname;const handled=await accountRoute(db,env,request,path,auth);if(handled)return handled;
 if(path==='/admin/api/players'&&request.method==='GET'){
  const q=(url.searchParams.get('q')||'').trim().toUpperCase();if(!/^JA[0-9A-HJKMNP-TV-Z]{0,10}$/.test(q))fail(400,'invalid_uid');
  const data=await rows(db.prepare('SELECT p.public_uid,p.created_at,a.last_seen,a.client_version,(SELECT count(*) FROM mail_recipients r WHERE r.owner_binding=p.owner_binding) AS mails,(SELECT count(*) FROM mail_claims k WHERE k.owner_binding=p.owner_binding AND k.acknowledged_at=0) AS pending FROM player_identities p LEFT JOIN mail_player_activity a ON a.owner_binding=p.owner_binding WHERE p.public_uid LIKE ? ORDER BY p.public_uid LIMIT 51').bind(q+'%'));
  return json(200,{entries:data.slice(0,50),truncated:data.length>50});
 }
 if(path==='/admin/api/drafts'&&request.method==='GET')return json(200,{entries:(await rows(db.prepare('SELECT * FROM mail_drafts ORDER BY updated_at DESC LIMIT 100'))).map(r=>({id:r.id,draft:JSON.parse(r.draft_json),updated_at:r.updated_at}))});
 if(path==='/admin/api/drafts/save'&&request.method==='POST'){
  const input=await readBody(request);exact(input,['id','draft']);const draft=helpers.normalizeDraft(input.draft),id=input.id?validID(input.id):randomId();
  if(!input.id&&(await db.prepare('SELECT count(*) AS n FROM mail_drafts').first()).n>=100)fail(409,'draft_limit');
  await db.prepare('INSERT INTO mail_drafts(id,draft_json,updated_at) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET draft_json=excluded.draft_json,updated_at=excluded.updated_at').bind(id,JSON.stringify(draft),nowSeconds()).run();return json(200,{id});
 }
 if(path==='/admin/api/drafts/delete'&&request.method==='POST'){const input=await readBody(request,128);exact(input,['id']);await db.prepare('DELETE FROM mail_drafts WHERE id=?').bind(validID(input.id)).run();return json(200,{ok:true});}
 if(path==='/admin/api/jobs'&&request.method==='GET')return json(200,{entries:await rows(db.prepare('SELECT id,draft_json,run_at,state,campaign_id,error_code,created_at FROM mail_jobs ORDER BY created_at DESC LIMIT 100'))});
 if(path==='/admin/api/jobs/schedule'&&request.method==='POST'){
  const input=await readBody(request);exact(input,['preview','run_at','request_id']);const id=validID(input.request_id),p=input.preview;exact(p,['draft','recipient_count','confirm_expires_at','confirm_token']);
  const fingerprint=await digest(JSON.stringify({draft:p.draft,run_at:input.run_at})),existing=await db.prepare('SELECT * FROM mail_jobs WHERE request_id=?').bind(id).first();
  if(existing){if(existing.fingerprint!==fingerprint)fail(409,'request_reused');return json(200,{id:existing.id});}
  await helpers.verifyPreview(db,env,p);
  const time=nowSeconds();if(!Number.isSafeInteger(input.run_at)||input.run_at<time+60||input.run_at>time+30*86400||p.draft.expires_at<input.run_at+60)fail(400,'invalid_schedule');
  await db.prepare('INSERT OR IGNORE INTO mail_jobs(id,request_id,fingerprint,draft_json,run_at,state,created_at,updated_at) VALUES(?,?,?,?,?,\'scheduled\',?,?)').bind(id,id,fingerprint,JSON.stringify(p.draft),input.run_at,time,time).run();return json(200,{id});
 }
 if(path==='/admin/api/jobs/cancel'&&request.method==='POST'){const input=await readBody(request,128);exact(input,['id']);const job=await db.prepare('UPDATE mail_jobs SET state=\'cancelled\',updated_at=? WHERE id=? AND state=\'scheduled\' RETURNING id').bind(nowSeconds(),validID(input.id)).first();if(!job)fail(409,'job_already_processed');return json(200,{ok:true});}
 if(path==='/admin/api/archive'&&request.method==='POST'){
  const input=await readBody(request,512);exact(input,['mail_id','cutoff','q','status']);
  if(input.mail_id){const id=validID(input.mail_id);await db.prepare('INSERT OR IGNORE INTO mail_archives(mail_id,archived_at) SELECT id,? FROM mail_campaigns WHERE id=? AND published_at>0').bind(nowSeconds(),id).run();}
  else{if(!Number.isSafeInteger(input.cutoff)||input.cutoff<1)fail(400,'invalid_cursor');const u=new URL(url);u.searchParams.set('q',String(input.q||''));u.searchParams.set('status',String(input.status||'all'));u.searchParams.delete('archive');const filter=historyFilter(u);await db.prepare('INSERT OR IGNORE INTO mail_archives(mail_id,archived_at) SELECT c.id,? FROM mail_campaigns c WHERE '+filter.sql+' AND c.rowid<=?').bind(nowSeconds(),...filter.args,input.cutoff).run();}
  await audit(db,'archive',input);return json(200,{ok:true});
 }
 if(path==='/admin/api/archive/restore'&&request.method==='POST'){const input=await readBody(request,128);exact(input,['mail_id']);await db.prepare('DELETE FROM mail_archives WHERE mail_id=?').bind(validID(input.mail_id)).run();await audit(db,'restore',input);return json(200,{ok:true});}
 if(path==='/admin/api/export'&&request.method==='GET'){
  const filter=historyFilter(url),data=await rows(db.prepare('SELECT c.*,count(r.owner_binding) AS recipients,sum(CASE WHEN r.delivered_at>0 THEN 1 ELSE 0 END) AS delivered,sum(CASE WHEN r.read_at>0 THEN 1 ELSE 0 END) AS read_count,sum(CASE WHEN k.acknowledged_at=0 THEN 1 ELSE 0 END) AS pending,sum(CASE WHEN k.acknowledged_at>0 AND x.resolved_at IS NULL THEN 1 ELSE 0 END) AS claimed,sum(CASE WHEN x.resolved_at>0 THEN 1 ELSE 0 END) AS resolved FROM mail_campaigns c LEFT JOIN mail_recipients r ON r.mail_id=c.id LEFT JOIN mail_claims k ON k.mail_id=r.mail_id AND k.owner_binding=r.owner_binding LEFT JOIN mail_claim_resolution x ON x.mail_id=k.mail_id AND x.owner_binding=k.owner_binding WHERE '+filter.sql+' GROUP BY c.id ORDER BY c.rowid DESC LIMIT 5001').bind(...filter.args));if(data.length>5000)fail(400,'export_limit');
  const table=[['ID','Title','Target','Created UTC','Expires UTC','Recipients','Delivered','Read','Pending','Claimed','Closed by admin','Status']];for(const c of data)table.push([c.id,c.title,c.target_uid||c.audience,new Date(c.created_at*1000).toISOString(),new Date(c.expires_at*1000).toISOString(),c.recipients,c.delivered,c.read_count,c.pending,c.claimed,c.resolved,c.cancelled_at?'cancelled':c.expires_at<=nowSeconds()?'expired':'active']);
  return new Response('\ufeff'+table.map(r=>r.map(csv).join(',')).join('\r\n'),{headers:{'content-type':'text/csv;charset=utf-8','content-disposition':'attachment; filename="jade-mail-history.csv"','cache-control':'no-store','x-content-type-options':'nosniff'}});
 }
 if(path==='/admin/api/resolve'&&request.method==='POST'){
  const input=await readBody(request,1000);exact(input,['mail_id','uid','reason','confirmation']);validID(input.mail_id);if(!UID.test(input.uid||'')||input.confirmation!=='CLOSE WITHOUT REWARD'||typeof input.reason!=='string'||input.reason.trim().length<10||input.reason.length>500)fail(400,'resolution_confirmation_required');
  const held=await db.prepare('SELECT k.* FROM mail_claims k JOIN player_identities p ON p.owner_binding=k.owner_binding WHERE k.mail_id=? AND p.public_uid=? AND k.acknowledged_at=0').bind(input.mail_id,input.uid).first();if(!held)fail(409,'no_pending_claim');
  const result=await db.batch([db.prepare('INSERT OR IGNORE INTO mail_claim_resolution(mail_id,owner_binding,reason,resolved_at) SELECT mail_id,owner_binding,?,? FROM mail_claims WHERE mail_id=? AND owner_binding=? AND acknowledged_at=0').bind(input.reason.trim(),nowSeconds(),held.mail_id,held.owner_binding),db.prepare('UPDATE mail_claims SET acknowledged_at=? WHERE mail_id=? AND owner_binding=? AND acknowledged_at=0').bind(nowSeconds(),held.mail_id,held.owner_binding)]);if(!result[0].meta?.changes)fail(409,'no_pending_claim');await audit(db,'resolve_without_reward',{mail_id:held.mail_id,uid:input.uid});return json(200,{ok:true});
 }
 if(path==='/admin/api/audit'&&request.method==='GET')return json(200,{entries:await rows(db.prepare('SELECT action,detail_json,created_at FROM mail_admin_audit ORDER BY created_at DESC,id DESC LIMIT 100'))});
 return null;
}
