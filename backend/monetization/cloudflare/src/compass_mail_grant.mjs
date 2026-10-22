// Fixed service binding, bounded response, no public grant/mutation endpoint.
export async function readCompassMailGrant(env,owner){
 if(!/^[a-f0-9]{64}$/.test(owner)||!env.ODYSSEY_PROFILE||!/^[a-f0-9]{64}$/.test(env.ODYSSEY_ADMIN_KEY||''))return {authorized:false,stage:'unavailable'};
 try{
  const response=await env.ODYSSEY_PROFILE.fetch('https://profile.internal/internal/equipment/compass-grant',{method:'POST',signal:AbortSignal.timeout(5000),headers:{'content-type':'application/json','x-odyssey-key':env.ODYSSEY_ADMIN_KEY},body:JSON.stringify({owner})});
  if(!response.ok)return {authorized:false,stage:'unavailable'};
  const reader=response.body?.getReader();if(!reader)return {authorized:false,stage:'unavailable'};
  let size=0,text='';const decoder=new TextDecoder();
  while(true){const p=await reader.read();if(p.done)break;size+=p.value.length;if(size>256){await reader.cancel();return {authorized:false,stage:'unavailable'};}text+=decoder.decode(p.value,{stream:true});}text+=decoder.decode();
  const data=JSON.parse(text);
  if(data?.version!==1||data.owner_binding!==owner||typeof data.compass_authorized!=='boolean'||Object.keys(data).length!==3)return {authorized:false,stage:'unavailable'};
  return {authorized:data.compass_authorized,stage:data.compass_authorized?'verified':'not_granted'};
 }catch{return {authorized:false,stage:'unavailable'};}
}
