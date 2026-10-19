import {draft} from './update_push_contract.mjs';
/** Public release text only. Existing service credential stays inside the IAP Worker. */
import {internalAuthorized,boundedBody,json} from './odyssey_http.mjs';
const PROJECT='jade-ascendant',TOPIC='jade_release_updates_v1',TOKEN='https://oauth2.googleapis.com/token';
const scope='https://www.googleapis.com/auth/firebase.messaging';
const encoder=new TextEncoder();let cached=null;
const fail=(code,status=503)=>{throw Object.assign(new Error(code),{code,status});};
const b64=bytes=>Buffer.from(bytes).toString('base64url');
export function pushMessage(input,id,time=Math.floor(Date.now()/1000)){
 const d=draft(input);if(!/^[a-f0-9]{32}$/.test(id||''))fail('invalid_update_id',400);
 return {topic:TOPIC,data:{kind:'app_update',campaign_id:id,version_code:String(d.version_code),title:d.title,body:d.body,expires_at:String(time+7*86400)},android:{priority:'HIGH',ttl:'604800s',collapse_key:'jade_app_update',restricted_package_name:'com.yungdevstudio.jadeascendant'}};
}
export function serviceIdentity(env){try{const s=JSON.parse(env.PLAY_SERVICE_ACCOUNT_JSON||'');return typeof s.client_email==='string'&&s.client_email.endsWith('.gserviceaccount.com')?s.client_email:null;}catch{return null;}}
async function access(env,fetcher){
 let key;try{key=JSON.parse(env.PLAY_SERVICE_ACCOUNT_JSON);}catch{fail('push_credentials_missing');}
 if(key.type!=='service_account'||!serviceIdentity(env)||typeof key.private_key!=='string')fail('push_credentials_missing');
 const keyId=b64(await crypto.subtle.digest('SHA-256',encoder.encode(key.private_key)));
 if(cached?.id===keyId&&cached.until>Date.now()+90000)return cached.token;
 const privateKey=await crypto.subtle.importKey('pkcs8',Buffer.from(key.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,''),'base64'),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
 const now=Math.floor(Date.now()/1000),body=b64(encoder.encode(JSON.stringify({iss:key.client_email,scope,aud:TOKEN,iat:now,exp:now+3500}))),head=b64(encoder.encode('{"alg":"RS256","typ":"JWT"}')),content=head+'.'+body;
 const signature=await crypto.subtle.sign('RSASSA-PKCS1-v1_5',privateKey,encoder.encode(content));
 const response=await fetcher.call(globalThis,TOKEN,{method:'POST',redirect:'manual',signal:AbortSignal.timeout(10000),headers:{'content-type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:content+'.'+b64(signature)})});
 if(!response.ok)fail('push_oauth_unavailable');const data=await response.json();if(typeof data.access_token!=='string'||data.access_token.length>8192||!Number.isFinite(data.expires_in)||data.expires_in<60)fail('push_oauth_unavailable');cached={id:keyId,token:data.access_token,until:Date.now()+Math.min(data.expires_in,3400)*1000};return cached.token;
}
export async function safePushFailure(response){
 let code='push_http_'+response.status;
 if(response.status===403){
  code='push_permission_or_api_required';
  try{
   // Google messages may contain credentials or resource IDs. Only allowlisted
   // machine categories are returned; never expose the raw body/message.
   const text=await response.text();if(text.length<=16384){
    const error=JSON.parse(text).error;
    const reasons=Array.isArray(error?.details)?error.details.filter(x=>x?.['@type']==='type.googleapis.com/google.rpc.ErrorInfo').map(x=>x.reason):[];
    if(reasons.includes('SERVICE_DISABLED'))code='push_api_disabled';
    else if(reasons.includes('IAM_PERMISSION_DENIED')||error?.status==='PERMISSION_DENIED')code='push_iam_permission_required';
   }
  }catch{ /* Unknown denial remains explicit and does not become success. */ }
 }
 return {accepted:false,status:'rejected',error:code};
}
export async function sendPush(env,message,{validate=false,fetcher=fetch}={}){
 const token=await access(env,fetcher);let response;
 try{response=await fetcher.call(globalThis,`https://fcm.googleapis.com/v1/projects/${PROJECT}/messages:send`,{method:'POST',redirect:'manual',signal:AbortSignal.timeout(15000),headers:{'content-type':'application/json',authorization:'Bearer '+token},body:JSON.stringify({validate_only:validate,message})});}catch{fail('push_delivery_unknown',502);}
 if(!response.ok){if([400,401,403,404,429].includes(response.status))return safePushFailure(response);fail('push_delivery_unknown',502);}
 let data;try{data=await response.json();}catch{fail('push_delivery_unknown',502);}
 if(typeof data.name!=='string'||!data.name.startsWith('projects/'+PROJECT+'/messages/'))fail('push_delivery_unknown',502);
 return {accepted:true,status:validate?'validated':'accepted',message_id:data.name};
}
export async function updatePushRoute(request,env,{fetcher=fetch}={}){
 try{
  if(!internalAuthorized(request,env))return json(403,{error:'forbidden'});
  if(request.method!=='POST')return json(405,{error:'method_not_allowed'});
  const input=await boundedBody(request);
  if(input.kind==='check'&&Object.keys(input).length===1){
   const result=await sendPush(env,pushMessage({version_code:1,version_name:'0.0.1',title:'Configuration check',body:'Validation only. Nothing is sent.'},'0'.repeat(32)),{validate:true,fetcher});
   return json(200,{...result,project:PROJECT,service_account:serviceIdentity(env),topic:TOPIC,validate_only:true,setup:{api:'fcm.googleapis.com',role:'roles/firebasecloudmessaging.admin',permission:'cloudmessaging.messages.create'}});
  }
  if(input.kind!=='send'||Object.keys(input).sort().join(',')!=='draft,id,kind')fail('invalid_update_command',400);
  return json(200,await sendPush(env,pushMessage(input.draft,input.id),{fetcher}));
 }catch(e){return json(e.status||503,{error:e.code||'push_unavailable',project:PROJECT,service_account:serviceIdentity(env)});}
}
