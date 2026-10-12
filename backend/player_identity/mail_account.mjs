import {fail,json,readBody,exact,randomId,nowSeconds,mac,checkProof} from './mail_admin.mjs';
const enc=new TextEncoder(),hex=b=>Array.from(new Uint8Array(b),v=>v.toString(16).padStart(2,'0')).join('');
const unhex=s=>Uint8Array.from(s.match(/../g)||[],v=>parseInt(v,16));
export async function passwordHash(env,password,salt){const pepper=await mac(env,'password:'+password);const key=await crypto.subtle.importKey('raw',enc.encode(pepper),'PBKDF2',false,['deriveBits']);return hex(await crypto.subtle.deriveBits({name:'PBKDF2',salt:unhex(salt),iterations:100000,hash:'SHA-256'},key,256));}
export const account=db=>db.prepare('SELECT * FROM mail_admin_account WHERE id=1').first();
export function credentials(input){if(typeof input.username!=='string'||!/^[a-zA-Z0-9_.-]{3,40}$/.test(input.username))fail(400,'invalid_username');if(typeof input.password!=='string'||input.password.length<12||input.password.length>128)fail(400,'password_too_short');}
export async function checkAccountLogin(_db,env,input,row){
 const hash=await passwordHash(env,typeof input.password==='string'?input.password:'',row.password_salt);
 if(input.username!==row.username||!await checkProof(env,'compare:'+hash,await mac(env,'compare:'+row.password_hash)))fail(401,'login_failed');
}
export async function issueSession(env,revision=''){
 const exp=nowSeconds()+14400,csrf=randomId(),signature=await mac(env,'session:'+exp+'.'+csrf+(revision?':'+revision:''));
 return json(200,{csrf,expires_at:exp,account_enabled:!!revision},{'set-cookie':`jade_admin=${exp}.${csrf}.${signature}; Path=/admin; HttpOnly; Secure; SameSite=Strict; Max-Age=14400`});
}
export async function accountRoute(db,env,request,path,_auth){
 if(path==='/admin/api/account/setup'&&request.method==='POST'){
  if(await account(db))fail(409,'account_already_setup');const input=await readBody(request,512);exact(input,['username','password']);credentials(input);
  const salt=randomId(),hash=await passwordHash(env,input.password,salt),revision=randomId();
  await db.prepare("INSERT OR IGNORE INTO mail_admin_account(id,username,password_salt,password_hash,totp_sealed,last_step,revision,created_at) VALUES(1,?,?,?,'',-1,?,?)").bind(input.username,salt,hash,revision,nowSeconds()).run();
  if((await account(db)).revision!==revision)fail(409,'account_already_setup');
  const response=await issueSession(env,revision);return json(200,{...await response.json(),username:input.username},Object.fromEntries(response.headers));
 }
 if(path==='/admin/api/account/password'&&request.method==='POST'){
  const row=await account(db);if(!row)fail(409,'account_not_setup');const input=await readBody(request,1000);exact(input,['password','new_password']);credentials({username:row.username,password:input.new_password});await checkAccountLogin(db,env,{username:row.username,password:input.password},row);
  const salt=randomId(),hash=await passwordHash(env,input.new_password,salt),revision=randomId();
  const changed=await db.prepare('UPDATE mail_admin_account SET password_salt=?,password_hash=?,revision=? WHERE id=1 AND revision=? RETURNING id').bind(salt,hash,revision,row.revision).first();if(!changed)fail(409,'account_changed');return issueSession(env,revision);
 }
 return null;
}
