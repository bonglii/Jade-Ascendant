import {credentials,passwordHash} from './mail_account.mjs';
import {randomId,nowSeconds,secret} from './mail_admin.mjs';
import {writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
export async function resetSQL(input){
 credentials(input);const env={MAIL_ADMIN_SECRET:input.key};secret(env);
 const salt=randomId(),hash=await passwordHash(env,input.password,salt),revision=randomId();
 const quoted=s=>"'"+s.replaceAll("'","''")+"'";
 return "INSERT INTO mail_admin_account(id,username,password_salt,password_hash,totp_sealed,last_step,revision,created_at) VALUES(1,"+[input.username,salt,hash,''].map(quoted).join(',')+",-1,"+quoted(revision)+","+nowSeconds()+") ON CONFLICT(id) DO UPDATE SET username=excluded.username,password_salt=excluded.password_salt,password_hash=excluded.password_hash,totp_sealed='',last_step=-1,revision=excluded.revision;\nDELETE FROM mail_admin_recovery;\nINSERT INTO mail_admin_audit(id,action,detail_json,created_at) VALUES("+quoted(randomId())+",'password_reset',"+quoted(JSON.stringify({username:input.username}))+","+nowSeconds()+");\n";
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 try{let data='';for await(const chunk of process.stdin){data+=chunk;if(data.length>4096)throw Error('invalid_input');}if(!process.argv[2])throw Error('output_required');writeFileSync(process.argv[2],await resetSQL(JSON.parse(data)),{mode:0o600});}
 catch(error){const messages={password_too_short:'Password must contain 12-128 characters.',invalid_username:'Username must contain 3-40 letters, numbers, dots, underscores or hyphens.',admin_setup_required:'The protected deployment key is invalid.'};console.error('ADMIN_RESET_PREPARE_FAILED: '+(messages[error.code]||'Unable to parse input or write the temporary SQL file. No credential values are logged.'));process.exitCode=1;}
}
