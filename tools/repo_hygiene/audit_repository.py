"""Conservative full repository inventory. Findings are review candidates, never deletion authority."""
from pathlib import Path
from collections import defaultdict, deque
import argparse, fnmatch, hashlib, json, re, subprocess, posixpath

TEXT = {'.gd','.tscn','.tres','.cfg','.godot','.gdextension','.gdap','.uid','.import',
        '.py','.ps1','.bat','.cmd','.sh','.mjs','.cjs','.js','.json','.md','.txt','.yml',
        '.yaml','.html','.css','.gdshader','.gdshaderinc','.csv','.kt','.kts','.gradle','.cs','.xml','.ini','.properties'}
MEDIA = {'.png','.svg','.webp','.jpg','.jpeg','.ogg','.wav','.ogv','.ttf','.otf'}
RESOURCE = MEDIA | {'.gd','.tscn','.tres','.gdshader','.gdextension'}
ROOTS = ('project.godot','export_presets.cfg')
RES = re.compile(r'''["'](res://[^"'\r\n]+)["']''')
UID = re.compile(r'uid://[a-z0-9]+')
SKIP = {'.git','.godot','.local','android','node_modules','__pycache__'}

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def git_files(root,*args):
    r=subprocess.run(['git','-C',str(root),'ls-files','-z',*args],capture_output=True,check=True)
    return [p for p in r.stdout.decode('utf-8').split('\0') if p]

def audit(root):
    root=root.resolve();tracked=git_files(root);known=set(tracked)
    head=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()
    rows={};texts={};by_size=defaultdict(list);folders=defaultdict(lambda:{'files':0,'bytes':0})
    for relative in tracked:
        p=root/relative
        if p.is_symlink():rows[relative]={'path':relative,'symlink':True};continue
        if not p.is_file():rows[relative]={'path':relative,'missing':True};continue
        size=p.stat().st_size;rows[relative]={'path':relative,'bytes':size}
        by_size[size].append(relative);folder=relative.split('/')[0]
        folders[folder]['files']+=1;folders[folder]['bytes']+=size
        if p.suffix.lower() in TEXT or relative in ROOTS:
            try:texts[relative]=p.read_text(encoding='utf-8-sig')
            except (UnicodeError,OSError):pass
    duplicate_groups=[]
    for size,paths in by_size.items():
        if len(paths)<2 or size==0:continue
        groups=defaultdict(list)
        for p in paths:
            digest=sha(root/p);rows[p]['sha256']=digest;groups[digest].append(p)
        for digest,names in groups.items():
            if len(names)>1:duplicate_groups.append({'sha256':digest,'bytes_each':size,'extra_bytes':size*(len(names)-1),'paths':sorted(names)})
    ignored_roots=[str(Path(p).parent).replace('\\','/')+'/' for p in tracked if Path(p).name=='.gdignore']
    def ignored(p):return any(p.startswith(prefix) for prefix in ignored_roots)
    uid_owner={};uid_owners=defaultdict(set)
    for p,t in texts.items():
        if Path(p).suffix in {'.uid','.import','.tscn','.tres'}:
            match=UID.search(t[:2500])
            if match:
                owner=p.removesuffix('.uid').removesuffix('.import');uid_owner[match.group()]=owner;uid_owners[match.group()].add(owner)
    edges=defaultdict(set);incoming=defaultdict(set);dynamic=[];missing=[];basename_refs=defaultdict(set)
    dynamic_covered=defaultdict(set)
    for source,text in texts.items():
        if source.endswith('.import'):continue # source_file inside its own metadata is not a consumer.
        for match in RES.finditer(text):
            value=match.group(1)[6:];p=root/value
            if value in known:
                edges[source].add(value);incoming[value].add(source)
            elif p.is_dir() or any(c in value for c in ['*','%','$','{']) or Path(value).suffix.lower() not in (RESOURCE|{'.json','.cfg','.csv','.txt'}):
                pattern=re.sub(r'%[-+0-9.]*[sdfi]|\$[A-Za-z_]\w*|\{[^}]+\}','*',value)
                direct_listing='DirAccess.get_files_at(' in text[max(0,match.start()-45):match.start()]
                matches=[r for r in tracked if not ignored(r) and (fnmatch.fnmatchcase(r,pattern) if '*' in pattern else r.startswith(pattern)) and (not direct_listing or '/' not in r[len(value):])]
                runtime_syntax=Path(source).suffix in {'.gd','.tscn','.tres','.cfg','.godot'}
                dynamic.append({'source':source,'prefix':value,'matches':len(matches),'resource_loader_candidate':runtime_syntax})
                if runtime_syntax:
                    for target in matches:edges[source].add(target);dynamic_covered[target].add(source)
            else:missing.append({'source':source,'reference':value})
        for uid in UID.findall(text):
            target=uid_owner.get(uid)
            if target and target in known and target!=source:
                edges[source].add(target);incoming[target].add(source)
    classes={}
    for p,t in texts.items():
        if p.endswith('.gd'):
            m=re.search(r'^class_name\s+([A-Za-z_]\w*)',t,re.M)
            if m:classes[m.group(1)]=p
    if classes:
        class_pattern=re.compile(r'\b(?:'+'|'.join(map(re.escape,classes))+r')\b')
        for source,text in texts.items():
            if not source.endswith('.gd'):continue
            for name in set(class_pattern.findall(text)):
                target=classes[name]
                if target!=source:edges[source].add(target);incoming[target].add(source)
    # Relative plugin scripts/resources are valid Godot consumers too.
    for source,text in texts.items():
        if Path(source).suffix not in {'.cfg','.tscn','.tres'}:continue
        for value in re.findall(r'[\"\']([^\"\'\r\n]+)[\"\']',text):
            target=posixpath.normpath(posixpath.join(str(Path(source).parent),value))
            if target in known and target!=source:edges[source].add(target);incoming[target].add(source)
    # Tool/CI/manifests often refer to relative paths without res://.
    all_names={Path(p).name for p in tracked if Path(p).suffix.lower() in (RESOURCE|{'.py','.ps1','.mjs','.cjs'})}
    name_pattern=re.compile('|'.join(re.escape(n) for n in sorted(all_names,key=lambda n:-len(n))))
    for source,text in texts.items():
        if source.endswith('.import'):continue
        for name in set(name_pattern.findall(text)):
            basename_refs[name].add(source)
    reachable=set();queue=deque(ROOTS)
    # Editor/export plugins are part of the supported author workflow too.
    queue.extend(p for p in tracked if p.startswith('addons/') and p.endswith(('plugin.cfg','.gdextension','.gdap')))
    while queue:
        p=queue.popleft()
        if p in reachable:continue
        reachable.add(p);queue.extend(q for q in edges.get(p,()) if not ignored(q))
    resources=[]
    for p,row in rows.items():
        if Path(p).suffix.lower() not in RESOURCE or row.get('missing') or row.get('symlink'):continue
        external=incoming[p]-{p,p+'.import',p+'.uid'}
        weak=basename_refs[Path(p).name]-{p,p+'.import',p+'.uid'}
        resources.append({'path':p,'bytes':row['bytes'],'reachable':p in reachable,'godot_ignored':ignored(p),
            'direct_consumers':sorted(external),'dynamic_consumers':sorted(dynamic_covered[p]),
            'other_name_consumers':sorted(weak-external-dynamic_covered[p])})
    candidates=[r for r in resources if not r['reachable'] and not r['direct_consumers'] and not r['dynamic_consumers']]
    strong_candidates=[r for r in candidates if not r['other_name_consumers']]
    excludes=[];preset=texts.get('export_presets.cfg','')
    for line in preset.splitlines():
        if line.startswith('exclude_filter='):excludes=line.partition('=')[2].strip('"').split(',');break
    dev_roots={key:any(fnmatch.fnmatchcase(key+'/audit.gd',pattern) for pattern in excludes) for key in ['tests','tools','docs','artifacts','.local']}
    natives=json.loads(texts.get('docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json','{}'))
    native_results=[]
    for p,expected in natives.get('inputs',{}).items():
        actual=sha(root/p) if (root/p).is_file() else ''
        # Native provenance uses LF-normalized source bytes.
        if actual!=expected and (root/p).is_file():actual=hashlib.sha256((root/p).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
        native_results.append({'path':p,'matches':actual==expected})
    proof_path='release/native/JadeMonetizationNativeBridge-production-candidate.aar'
    untracked=[]
    for p in git_files(root,'--others','--exclude-standard'):
        f=root/p
        if f.is_file() and not f.is_symlink():untracked.append({'path':p,'bytes':f.stat().st_size,'tracked':False,'deletion_approved':False})
    return {'format':1,'base_commit':head,'scope':'Repository checkout; owner Windows extra files require the local scanner',
        'summary':{'tracked_files':len(tracked),'tracked_bytes':sum(r.get('bytes',0) for r in rows.values()),
            'resource_files':len(resources),'reachable_resources':sum(r['reachable'] for r in resources),
            'no_direct_or_dynamic_consumer_candidates':len(candidates),'no_known_consumer_candidates':len(strong_candidates),
            'duplicate_groups':len(duplicate_groups),'duplicate_extra_bytes':sum(g['extra_bytes'] for g in duplicate_groups)},
        'folders':dict(folders),'export_dev_exclusions':dev_roots,'export_exclude_patterns':excludes,
        'native':{'input_count':len(native_results),'all_inputs_match':all(r['matches'] for r in native_results),
            'candidate_aar_matches':(root/proof_path).is_file() and sha(root/proof_path)==natives.get('aar_sha256'),
            'mismatches':[r['path'] for r in native_results if not r['matches']]},
        'duplicate_groups':sorted(duplicate_groups,key=lambda g:-g['extra_bytes']),
        'dynamic_resource_families':dynamic,'missing_literal_references':missing,'uid_collisions':{k:sorted(v) for k,v in uid_owners.items() if len(v)>1},'godot_ignored_roots':ignored_roots,
        'resources':resources,'unreferenced_candidates':sorted(strong_candidates,key=lambda r:-r['bytes']),
        'untracked_visible_to_git':untracked,
        'limitations':['No candidate is automatically safe to delete. Dynamic loads, artist sources, manifests and historical proofs need review.',
            'all_resources export includes unreachable importable assets unless an explicit exclusion matches.',
            'Owner caches/saves/backup/receipt/recovery and ignored build outputs are not read or removed by this audit.']}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[2]);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();result=audit(args.project);args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'summary':result['summary'],'native':result['native'],'export_dev_exclusions':result['export_dev_exclusions']}))
if __name__=='__main__':main()
