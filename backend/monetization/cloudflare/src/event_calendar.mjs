// One limited-event slot. Evergreen progression and normal Pavilion stay independent.
const END=4102444800,START="CAST(json_extract(document,'$.starts_at') AS INTEGER)";
async function exists(db,table){return !!await db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name=?").bind(table).first();}
async function rows(db,table){return await exists(db,table)?(await db.prepare('SELECT id,document,created_at FROM '+table).all()).results:[];}
export function calendar(odyssey,trials,now){
 const rotations=trials.map(r=>({...r,config:JSON.parse(r.document)})).sort((a,b)=>a.config.starts_at-b.config.starts_at);
 const entries=[...odyssey.map(r=>{const c=JSON.parse(r.document);return{kind:'odyssey',id:r.id,...c,ends_at:c.ends_at+259200}}),...rotations.map((r,i)=>({kind:'trials',id:r.id,...r.config,ends_at:rotations[i+1]?.config.starts_at??END}))];
 const slots=entries.filter(e=>e.enabled&&e.ends_at>now).sort((a,b)=>a.starts_at-b.starts_at||a.kind.localeCompare(b.kind));
 const conflicts=[];
 for(let i=0;i<slots.length;i++)for(let j=i+1;j<slots.length;j++)if(slots[i].kind!==slots[j].kind&&slots[i].starts_at<slots[j].ends_at&&slots[j].starts_at<slots[i].ends_at)conflicts.push([slots[i].id,slots[j].id]);
 return {version:1,server_time:now,policy:'one_limited_event_at_a_time',evergreen_independent:true,slots:slots.map(e=>({kind:e.kind,id:e.id,starts_at:e.starts_at,ends_at:e.ends_at===END?null:e.ends_at,status:e.starts_at>now?'scheduled':'live'})),conflicts};
}
export async function readCalendar(db,now){return calendar(await rows(db,'odyssey_events'),await rows(db,'ht_campaigns'),now);}
// The condition is evaluated in the actual write, including initially empty tables.
// Separate preflight reads alone cannot protect concurrent cross-event publishes.
export async function slotGuard(db,kind,event,now){
 if(!event.enabled||!await exists(db,kind==='odyssey'?'ht_campaigns':'odyssey_events'))return {sql:'1=1',args:[]};
 if(kind==='odyssey'){
  if(event.ends_at+259200<=now)return {sql:'1=1',args:[]};
  return {sql:"NOT EXISTS(SELECT 1 FROM ht_campaigns h WHERE json_extract(h.document,'$.enabled')=1 AND CAST(json_extract(h.document,'$.starts_at') AS INTEGER)<? AND COALESCE((SELECT MIN("+START+") FROM ht_campaigns WHERE "+START+">CAST(json_extract(h.document,'$.starts_at') AS INTEGER)),4102444800)>?)",args:[event.ends_at+259200,Math.max(now,event.starts_at)]};
 }
 const next=await db.prepare('SELECT MIN('+START+') AS starts_at FROM ht_campaigns WHERE '+START+'>? AND id<>?').bind(event.starts_at,event.id).first();
 return {sql:"NOT EXISTS(SELECT 1 FROM odyssey_events WHERE json_extract(document,'$.enabled')=1 AND CAST(json_extract(document,'$.starts_at') AS INTEGER)<? AND CAST(json_extract(document,'$.ends_at') AS INTEGER)+259200>?)",args:[next?.starts_at??END,Math.max(now,event.starts_at)]};
}
