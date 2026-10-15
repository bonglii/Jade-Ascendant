/** Google Play voidedpurchases.list adapter; no OAuth credentials accepted from callers.
 * Wire getAccessToken ONLY to the existing private service-account OAuth helper.
 * Never expose this function through a public HTTP route or log the response.
 */
export class VoidedPlayGatewayErrorRC7 extends Error {
  constructor(code){super(code);this.name='VoidedPlayGatewayErrorRC7';this.code=code;}
}
const fail=code=>{throw new VoidedPlayGatewayErrorRC7(code);};
const PACKAGE='com.yungdevstudio.jadeascendant';
const API=`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/purchases/voidedpurchases`;
const MAX_BYTES=4*1024*1024;
export async function requestVoidedPlayPageRC7({
  getAccessToken, fetcher=fetch, startTimeMs, endTimeMs, pageToken=null,
}={}) {
  if(typeof getAccessToken!=='function'||typeof fetcher!=='function') fail('trusted_gateway_required');
  if(!Number.isSafeInteger(startTimeMs)||!Number.isSafeInteger(endTimeMs)||
      startTimeMs<=0||endTimeMs<=startTimeMs)fail('invalid_range');
  if(pageToken!==null && (typeof pageToken!=='string'||pageToken.length<1||pageToken.length>512||
    !/^[A-Za-z0-9+/_=-]+$/.test(pageToken)))fail('invalid_page_token');
  const params=new URLSearchParams({
    type:'0',
    'pageSelection.maxResults':'500',
    includeQuantityBasedPartialRefund:'true',
  });
  if(pageToken){
    params.set('pageSelection.token',pageToken);
  }else{
    params.set('startTime',String(startTimeMs));
    params.set('endTime',String(endTimeMs));
  }
  const access=await getAccessToken();
  if(typeof access!=='string'||access.length<20||access.length>8192||!/^[-A-Za-z0-9_./]+$/.test(access))
    fail('play_oauth_unavailable');
  let response;
  try {
    response=await fetcher.call(globalThis,`${API}?${params}`,{
      method:'GET',redirect:'manual',
      headers:{Authorization:`Bearer ${access}`,Accept:'application/json'},
      signal:AbortSignal.timeout(15000),
    });
  }catch(error){
    if(error?.name==='TimeoutError'||error?.name==='AbortError')fail('play_fetch_timeout');
    if(/illegal invocation/i.test(String(error?.message||'')))fail('play_fetch_receiver');
    if(/redirect/i.test(String(error?.message||'')))fail('play_fetch_redirect_mode');
    fail('play_fetch_unavailable');
  }
  // Safe fixed labels only: never include Google body, OAuth token or URL query.
  if(!response?.ok){
    const status=response?.status;
    if(status>=300&&status<400)fail('play_redirect_denied');
    if([401,403,404,429].includes(status))fail('play_http_'+status);
    if(status>=500&&status<=599)fail('play_http_5xx');
    fail('play_http_other');
  }
  if(!/^application\/json(?:\s*;|$)/i.test(response.headers?.get('content-type')||''))
    fail('invalid_play_content_type');
  const advertised=response.headers.get('content-length');
  if(advertised!==null && (!/^\d+$/.test(advertised)||Number(advertised)>MAX_BYTES))
    fail('oversized_play_page');
  if(!response.body) fail('invalid_play_page');
  const reader=response.body.getReader();
  const chunks=[];let length=0;
  try{
    while(true){
      const {value,done}=await reader.read();
      if(done)break;
      length+=value.byteLength;
      if(length>MAX_BYTES){await reader.cancel();fail('oversized_play_page');}
      chunks.push(value);
    }
  }finally{reader.releaseLock();}
  const bytes=new Uint8Array(length);let at=0;
  for(const chunk of chunks){bytes.set(chunk,at);at+=chunk.length;}
  let parsed;
  try{parsed=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}
  catch{fail('invalid_play_page');}
  if(!parsed||typeof parsed!=='object'||Array.isArray(parsed))fail('invalid_play_page');
  return parsed;
}
