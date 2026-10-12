import {readFileSync,mkdirSync,copyFileSync,writeFileSync,existsSync,unlinkSync} from 'node:fs';
import {resolve,dirname,relative} from 'node:path';
import {fileURLToPath} from 'node:url';
const here=dirname(fileURLToPath(import.meta.url)),root=resolve(here,'../..');
const catalog=JSON.parse(readFileSync(resolve(here,'mail_reward_catalog.json'),'utf8'));
const directory=resolve(here,'web_assets/admin/assets');mkdirSync(directory,{recursive:true});writeFileSync(resolve(here,'web_assets/.gdignore'),'');
for(const item of [...catalog.currencies,...catalog.equipment]){
 if(!/^[a-z0-9_]+$/.test(item.id)||!item.icon_source.startsWith('res://assets/')||!item.icon_source.endsWith('.png'))throw Error('Invalid reviewed icon manifest');
 const source=resolve(root,item.icon_source.slice(6));if(relative(root,source).startsWith('..'))throw Error('Asset outside project');
 copyFileSync(source,resolve(directory,item.id+'.png'));const sidecar=resolve(directory,item.id+'.png.import');if(existsSync(sidecar))unlinkSync(sidecar);
}
console.log('MAIL_ASSETS_BUILD=PASS; '+(catalog.currencies.length+catalog.equipment.length)+' existing game icons copied unchanged.');
