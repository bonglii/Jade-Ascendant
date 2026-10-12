import {account,checkAccountLogin,issueSession} from './mail_account.mjs';
const encoder=new TextEncoder();
export class MailError extends Error {constructor(status,code){super(code);this.status=status;this.code=code;}}
export const fail=(status,code)=>{throw new MailError(status,code);};
export const nowSeconds=()=>Math.floor(Date.now()/1000);
export const randomId=()=>crypto.randomUUID().replaceAll('-','');
export const json=(status,data,extra={})=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json','cache-control':'no-store','x-content-type-options':'nosniff',...extra}});
export async function readBody(request,max=20000){
 if(request.headers.get('content-type')?.split(';')[0]!=='application/json')fail(400,'invalid_body');
 const reader=request.body?.getReader();let size=0;const chunks=[];
 if(reader)while(true){const item=await reader.read();if(item.done)break;size+=item.value.length;if(size>max){await reader.cancel();fail(413,'body_too_large');}chunks.push(item.value);}
 const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
 try{const value=JSON.parse(new TextDecoder().decode(bytes));if(!value||typeof value!=='object'||Array.isArray(value))fail(400,'invalid_body');return value;}catch{fail(400,'invalid_body');}
}
export const exact=(value,keys)=>{if(!value||typeof value!=='object'||Array.isArray(value)||Object.keys(value).some(k=>!keys.includes(k)))fail(400,'invalid_fields');};
export const digest=async text=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',encoder.encode(text))),x=>x.toString(16).padStart(2,'0')).join('');
const equal=(a,b)=>{if(typeof a!=='string'||typeof b!=='string'||a.length!==b.length)return false;let diff=0;for(let i=0;i<a.length;i++)diff|=a.charCodeAt(i)^b.charCodeAt(i);return diff===0;};
export function secret(env){if(!/^[a-f0-9]{64}$/.test(env.MAIL_ADMIN_SECRET||''))fail(503,'admin_setup_required');return env.MAIL_ADMIN_SECRET;}
export async function mac(env,value){const key=await crypto.subtle.importKey('raw',encoder.encode(secret(env)),{name:'HMAC',hash:'SHA-256'},false,['sign']);return Array.from(new Uint8Array(await crypto.subtle.sign('HMAC',key,encoder.encode(value))),x=>x.toString(16).padStart(2,'0')).join('');}
export function sameOrigin(request){if(request.headers.get('origin')!==new URL(request.url).origin)fail(403,'origin_rejected');}
export async function session(request,env,mutate=false){
 secret(env);const raw=(request.headers.get('cookie')||'').split(';').map(x=>x.trim()).find(x=>x.startsWith('jade_admin='))?.slice(11)||'';
 const parts=raw.split('.');if(parts.length!==3||!/^\d+$/.test(parts[0])||!/^[a-f0-9]{32}$/.test(parts[1])||!/^[a-f0-9]{64}$/.test(parts[2]))fail(401,'admin_required');
 const current=await account(env.PROFILE_DB),revision=current?':'+current.revision:'';
 const exp=Number(parts[0]);if(exp<=nowSeconds()||exp>nowSeconds()+14400||!equal(parts[2],await mac(env,'session:'+parts[0]+'.'+parts[1]+revision)))fail(401,'admin_required');
 if(mutate){sameOrigin(request);if(!equal(request.headers.get('x-jade-csrf'),parts[1]))fail(403,'csrf_rejected');}
 return {csrf:parts[1],expires_at:exp,account_enabled:!!current,username:current?.username||''};
}
export async function login(request,env,db){
 sameOrigin(request);const input=await readBody(request,512);exact(input,['password','username']);
 const root=secret(env),time=nowSeconds(),bucket=await mac(env,'login:'+String(request.headers.get('cf-connecting-ip')||'unknown'));
 const count=await db.prepare('INSERT INTO mail_admin_attempts(bucket,window_at,attempts) VALUES(?,?,1) ON CONFLICT(bucket) DO UPDATE SET attempts=CASE WHEN window_at<? THEN 1 ELSE attempts+1 END,window_at=CASE WHEN window_at<? THEN ? ELSE window_at END RETURNING attempts').bind(bucket,time,time-60,time-60,time).first();
 if(count.attempts>12)fail(429,'login_rate_limited');
 const current=await account(db);
 if(current)await checkAccountLogin(db,env,input,current);
 else if(typeof input.password!=='string'||!equal(await digest(input.password),await digest(root)))fail(401,'login_failed');
 await db.prepare('DELETE FROM mail_admin_attempts WHERE window_at<?').bind(time-86400).run();
 return issueSession(env,current?.revision||'');
}
export const checkProof=async(env,value,signature)=>equal(signature,await mac(env,value));
