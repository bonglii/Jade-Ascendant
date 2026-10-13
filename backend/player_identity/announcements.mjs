import {fail,json,readBody,exact,digest,mac,checkProof,randomId,nowSeconds} from './mail_admin.mjs';
import {audit} from './mail_studio.mjs';
const ID=/^[a-f0-9]{32}$/;
const id=value=>{if(typeof value!=='string'||!ID.test(value))fail(400,'invalid_announcement_id');return value;};
const integer=value=>{if(!Number.isSafeInteger(value))fail(400,'invalid_announcement_time');return value;};
export function normalizeAnnouncement(input,time=nowSeconds()){
 exact(input,['title','body','kind','starts_at','expires_at']);
 const text=(value,max)=>{if(typeof value!=='string'||!value.trim()||value.length>max||/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(value))fail(400,'invalid_announcement_text');return value.trim();};
 if(!['notice','event','maintenance'].includes(input.kind))fail(400,'invalid_announcement_kind');
 const starts=integer(input.starts_at),expires=integer(input.expires_at);
 if(starts<time-300||starts>time+30*86400||expires<starts+60||expires>starts+30*86400)fail(400,'invalid_announcement_time');
 return {title:text(input.title,100),body:text(input.body,4000),kind:input.kind,starts_at:starts,expires_at:expires};
}
const view=row=>({id:row.id,title:row.title,body:row.body,kind:row.kind,starts_at:row.starts_at,expires_at:row.expires_at,created_at:row.created_at,cancelled:row.cancelled_at>0});
export async function previewAnnouncement(db,env,input){
 const draft=normalizeAnnouncement(input),expires=nowSeconds()+300;
 const count=await db.prepare('SELECT count(*) AS n FROM player_identities').first();
 return {draft,registered_players:count.n,confirm_expires_at:expires,confirm_token:await mac(env,'announcement:'+await digest(JSON.stringify(draft))+':'+expires)};
}
export async function publishAnnouncement(db,env,input){
 exact(input,['draft','confirm_expires_at','confirm_token','request_id']);id(input.request_id);
 // Lost-response retries read the immutable existing publication, even after expiry.
 const draft=normalizeAnnouncement(input.draft,Math.min(nowSeconds(),Number(input.draft?.starts_at)||nowSeconds()));
 const fingerprint=await digest(JSON.stringify(draft));
 const existing=await db.prepare('SELECT * FROM player_announcements WHERE request_id=?').bind(input.request_id).first();
 if(existing){if(existing.fingerprint!==fingerprint)fail(409,'request_reused');return view(existing);}
 const time=nowSeconds(),expires=integer(input.confirm_expires_at);
 if(expires<=time||expires>time+300||draft.expires_at<=time+60||draft.starts_at<time-300)fail(400,'announcement_preview_expired');
 if(!await checkProof(env,'announcement:'+fingerprint+':'+expires,input.confirm_token))fail(403,'preview_required');
 await db.prepare('INSERT OR IGNORE INTO player_announcements(id,request_id,fingerprint,title,body,kind,starts_at,expires_at,created_at) SELECT ?,?,?,?,?,?,?,?,? WHERE (SELECT count(*) FROM player_announcements WHERE cancelled_at=0 AND expires_at>?)<20').bind(randomId(),input.request_id,fingerprint,draft.title,draft.body,draft.kind,draft.starts_at,draft.expires_at,time,time).run();
 const row=await db.prepare('SELECT * FROM player_announcements WHERE request_id=?').bind(input.request_id).first();
 if(!row)fail(409,'announcement_active_limit');
 if(row.fingerprint!==fingerprint)fail(409,'request_reused');
 await audit(db,'announcement_publish',{announcement_id:row.id});
 return view(row);
}
export async function announcementAdminRoute(db,env,request,url){
 const path=url.pathname;
 if(!path.startsWith('/admin/api/announcements/'))return null;
 if(path==='/admin/api/announcements/history'&&request.method==='GET'){
  const rows=await db.prepare('SELECT a.*,(SELECT count(*) FROM player_announcement_reads r WHERE r.announcement_id=a.id) AS read_count FROM player_announcements a ORDER BY created_at DESC,id DESC LIMIT 50').all();
  return json(200,{entries:rows.results.map(row=>({...view(row),read_count:row.read_count})),server_time:nowSeconds()});
 }
 if(request.method!=='POST')fail(405,'method_not_allowed');
 const input=await readBody(request,20000);
 if(path==='/admin/api/announcements/preview')return json(200,await previewAnnouncement(db,env,input));
 if(path==='/admin/api/announcements/publish')return json(200,await publishAnnouncement(db,env,input));
 if(path==='/admin/api/announcements/cancel'){
  exact(input,['announcement_id']);const announcement=id(input.announcement_id);
  if(!await db.prepare('SELECT id FROM player_announcements WHERE id=?').bind(announcement).first())fail(404,'announcement_not_found');
  await db.prepare('UPDATE player_announcements SET cancelled_at=? WHERE id=? AND cancelled_at=0').bind(nowSeconds(),announcement).run();
  await audit(db,'announcement_cancel',{announcement_id:announcement});return json(200,{ok:true});
 }
 fail(404,'not_found');
}
export async function listAnnouncementEntries(db,owner,time=nowSeconds()){
 const rows=await db.prepare('SELECT a.* FROM player_announcements a WHERE a.cancelled_at=0 AND a.starts_at<=? AND a.expires_at>? AND NOT EXISTS(SELECT 1 FROM player_announcement_reads r WHERE r.announcement_id=a.id AND r.owner_binding=?) ORDER BY a.created_at,a.id LIMIT 20').bind(time,time,owner).all();
 return rows.results.map(view);
}
export async function announcementPlayerRoute(db,owner,request,url){
 if(url.pathname==='/v1/mail/announcements'){
  if(request.method!=='GET')fail(405,'method_not_allowed');
  const time=nowSeconds();
  return json(200,{version:1,owner_binding:owner,server_time:time,entries:await listAnnouncementEntries(db,owner,time)});
 }
 if(url.pathname==='/v1/mail/announcement_read'){
  if(request.method!=='POST')fail(405,'method_not_allowed');
  const input=await readBody(request,512);exact(input,['announcement_id']);const announcement=id(input.announcement_id);
  if(!await db.prepare('SELECT id FROM player_announcements WHERE id=? AND starts_at<=?').bind(announcement,nowSeconds()).first())fail(404,'announcement_not_found');
  await db.prepare('INSERT OR IGNORE INTO player_announcement_reads(announcement_id,owner_binding,read_at) VALUES(?,?,?)').bind(announcement,owner,nowSeconds()).run();
  return json(200,{ok:true,announcement_id:announcement,owner_binding:owner});
 }
 return null;
}
