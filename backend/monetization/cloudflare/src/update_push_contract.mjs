const fail=(code,status=400)=>{throw Object.assign(new Error(code),{code,status});};
export function draft(input){
 if(!input||Object.keys(input).sort().join(',')!=='body,title,version_code,version_name')fail('invalid_update_draft',400);
 if(!Number.isSafeInteger(input.version_code)||input.version_code<1||input.version_code>999999999||!/^\d{1,3}\.\d{1,3}\.\d{1,3}(?:[.-][A-Za-z0-9]{1,20})?$/.test(input.version_name||''))fail('invalid_update_version',400);
 for(const [key,max] of [['title',80],['body',240]])if(typeof input[key]!=='string'||!input[key].trim()||input[key].length>max||/[\x00-\x1f\x7f]/.test(input[key]))fail('invalid_update_text',400);
 return {version_code:input.version_code,version_name:input.version_name,title:input.title.trim(),body:input.body.trim()};
}
