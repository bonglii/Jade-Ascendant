#!/usr/bin/env python3
"""Portable source/package checks. Python 3.10+, standard library only.
This is not a GDScript parser, Godot run, Android test, or Play approval.
Run: python tools/validate_release.py --report-dir artifacts/source-check
"""
from __future__ import annotations
import argparse,ast,collections,hashlib,json,re,struct,wave,xml.etree.ElementTree as ET
from pathlib import Path
from validate_phase0 import scan,project_files,string_values


def constant(path: Path, name: str):
    text=path.read_text(encoding='utf-8-sig')
    match=re.search(r'(?m)^const\s+'+re.escape(name)+r'(?:\s*:\s*\w+)?\s*=\s*',text)
    if not match: raise ValueError('Missing constant '+name)
    fragment=text[match.end():]
    end=balanced_end(fragment)
    fragment=re.sub(r'\bColor\(([^()]*)\)',r'[\1]',fragment[:end])
    fragment=re.sub(r'\btrue\b','True',fragment)
    fragment=re.sub(r'\bfalse\b','False',fragment)
    return ast.literal_eval(fragment)


def balanced_end(text: str) -> int:
    """Return the end of the first balanced literal expression.

    GDScript comments can contain apostrophes or bracket characters. Ignore the
    rest of a comment while tracking quotes/delimiters so comments cannot break
    release-data extraction.
    """
    depth=0; quote=''; escaped=False; i=0
    while i < len(text):
        c=text[i]
        if quote:
            if escaped: escaped=False
            elif c=='\\': escaped=True
            elif c==quote: quote=''
            i+=1; continue
        if c=='#':
            newline=text.find('\n',i)
            if newline<0: break
            i=newline+1; continue
        if c in '"\'':
            quote=c; i+=1; continue
        if c in '({[': depth+=1
        elif c in ')}]':
            depth-=1
            if depth==0: return i+1
        i+=1
    raise ValueError('Unclosed constant')


def delimiters(text: str) -> list[str]:
    """Lex quotes/comments and balanced delimiters. Deliberately not compilation."""
    stack=[]; errors=[]; i=0; line=1
    pairs={')':'(',']':'[','}':'{'}
    while i<len(text):
        c=text[i]
        if c=='#':
            n=text.find('\n',i);i=len(text) if n<0 else n;continue
        if c in '\"\'':
            start=line; delim=c*(3 if text.startswith(c*3,i) else 1);i+=len(delim)
            while i<len(text) and not text.startswith(delim,i):
                if text[i]=='\\': i+=2;continue
                line+=text[i]=='\n';i+=1
            if i==len(text): errors.append(f'Unclosed string at line {start}')
            i+=len(delim);continue
        if c in '([{': stack.append((c,line))
        elif c in ')]}':
            if not stack or stack[-1][0]!=pairs[c]: errors.append(f'Mismatched {c} at line {line}')
            else: stack.pop()
        line+=c=='\n';i+=1
    errors.extend(f'Unclosed {c} at line {n}' for c,n in stack)
    return errors


def png_header(path: Path):
    data=path.read_bytes()
    if data[:8]!=b'\x89PNG\r\n\x1a\n': raise ValueError('Not PNG: '+str(path))
    return struct.unpack('>IIBB',data[16:26])


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--report-dir',type=Path,default=Path('artifacts/source-check'))
    args=parser.parse_args();p=args.project.resolve();report=args.report_dir.resolve();report.mkdir(parents=True,exist_ok=True)
    checks=[]
    def check(value,label,details=None):
        entry={'name':label,'status':'PASS' if value else 'FAIL'}
        if details is not None: entry['details']=details
        checks.append(entry)
    source=scan(p)
    check(source['static_status']=='PASS','Literal resource references and scene resource IDs',source['errors'])
    scripts=list(p.glob('scripts/**/*.gd'))+list(p.glob('tests/*.gd'))+list(p.glob('tools/*.gd'))
    syntax=[]
    for file in scripts:
        text=file.read_text(encoding='utf-8-sig')
        syntax.extend({'file':str(file.relative_to(p)),'error':e} for e in delimiters(text))
        funcs=re.findall(r'(?m)^(?:static )?func (\w+)\(',text)
        syntax.extend({'file':str(file.relative_to(p)),'error':'Duplicate function '+k} for k,v in collections.Counter(funcs).items() if v>1)
    check(not syntax,'Lexical delimiter and duplicate-function checks (not GDScript compilation)',syntax)
    stages=constant(p/'scripts/data/chapter_one_catalog.gd','STAGES')
    items=constant(p/'scripts/data/equipment_catalog.gd','ITEMS')
    check(set(stages)=={1,2,3,4,5},'Five stable Chapter 1 stage IDs')
    check(len({v['scene_path'] for v in stages.values()})==5 and all(v['implemented'] for v in stages.values()),'Five implemented scene destinations')
    check([k for k,v in stages.items() if v['is_chapter_boss']]==[5],'Only the fifth trial is the chapter finale')
    check(stages[1]['wave_duration']==14.0 and stages[1]['first_clear_stones']==100 and stages[1]['repeat_clear_stones']==100,'Stage 1 timing and stone rewards preserved')
    check(len({str(v['accent']) for v in stages.values()})==5,'Distinct stage palettes')
    weight_errors=[]
    for key,stage in stages.items():
        for band in stage['enemy_bands']:
            weights=band['weights']
            if len(weights)!=6 or sum(weights)!=100 or min(weights)<0:weight_errors.append([key,band])
    check(not weight_errors,'Enemy probability tables sum to 100',weight_errors)
    permanent_slots={'armament','robe','bracer','boots','pendant'}
    slot_counts=collections.Counter(v['slot'] for v in items.values())
    check(len(items)==25 and set(slot_counts)==permanent_slots,'Equipment V2 contains twenty-five items across five permanent slots',dict(slot_counts))
    check(all(slot_counts[slot]==5 for slot in permanent_slots),'Equipment V2 provides five collection choices per permanent slot',dict(slot_counts))
    equipment_manager_text=(p/'scripts/ui/equipment_manager.gd').read_text(encoding='utf-8-sig')
    slot_func=re.search(r'func\s+get_slot_ids\(\)\s*->\s*Array\[String\]:\s*\n\s*return\s*\[(.*?)\]',equipment_manager_text,re.S)
    manager_slot_constants=re.findall(r'\bSLOT_[A-Z_]+\b',slot_func.group(1)) if slot_func else []
    expected_manager_slots=['SLOT_ARMAMENT','SLOT_ROBE','SLOT_BRACER','SLOT_BOOTS','SLOT_PENDANT']
    check(
        manager_slot_constants==expected_manager_slots
        and 'const SLOT_ARMAMENT: String = "armament"' in equipment_manager_text,
        'EquipmentManager runtime exposes Dao Armament plus four legacy slots',
        manager_slot_constants
    )
    armament_ids={k for k,v in items.items() if v['slot']=='armament'}
    expected_armaments={'wanderer_jade_jian','mistveil_jian','spirit_seal_fan','cinnabar_moon_saber','nine_heavens_star_sword'}
    check(armament_ids==expected_armaments,'Dao Armament collection contains the five approved Gate 1.3 identities',sorted(armament_ids))
    check(items['wanderer_jade_jian']['rarity']=='common' and items['wanderer_jade_jian']['damage_bonus']==.03,'Foundation Dao Armament identity and passive preserved')
    check(items['spirit_seal_fan']['experience_bonus']==.05 and items['spirit_seal_fan']['pickup_radius_bonus']==10.0,'Spirit-Seal Fan is a utility armament rather than a damage clone')
    check(items['mirror_edge_bracer']['damage_bonus']<items['jade_edge_bracer']['damage_bonus'] and items['mirror_edge_bracer']['critical_chance_bonus']>items['jade_edge_bracer']['critical_chance_bonus'],'Mirror-Edge Bracer remains a crit-oriented sidegrade')
    rarity_counts=collections.Counter(v['rarity'] for v in items.values())
    check(rarity_counts=={'common':5,'rare':8,'epic':7,'legendary':5},'Equipment V2 rarity distribution remains intentionally broad without inflating Legendary count',dict(rarity_counts))
    signature_keys={'signature_effect_name','signature_effect_description'}
    common_items={k:v for k,v in items.items() if v['rarity']=='common'}
    rare_items={k:v for k,v in items.items() if v['rarity']=='rare'}
    epic_items={k:v for k,v in items.items() if v['rarity']=='epic'}
    legendary_items={k:v for k,v in items.items() if v['rarity']=='legendary'}
    core_stat_keys={'max_health_flat','damage_bonus','movement_speed_bonus','experience_bonus','critical_chance_bonus'}
    rare_stat_keys=core_stat_keys|{'pickup_radius_bonus'}
    special_mechanic_keys={'blood_qi_heal_bonus','starting_shield_charges','critical_damage_bonus','pickup_radius_bonus','low_health_damage_bonus','attack_cooldown_reduction','moving_damage_bonus','level_up_heal_flat','low_health_critical_chance_bonus'}
    check(all(not any(key in data for key in signature_keys) and sum(key in data for key in core_stat_keys)==1 for data in common_items.values()),'Common equipment stays simple with one core stat and no signature mechanic')
    check(all(not any(key in data for key in signature_keys) and sum(key in data for key in rare_stat_keys)>=2 for data in rare_items.values()),'Rare equipment stays readable as multi-stat sidegrades without signature mechanics')
    check(all(all(key in data and str(data[key]).strip() for key in signature_keys) for data in epic_items.values()),'Every Epic equipment item declares a signature effect')
    check(all(any(key in data for key in special_mechanic_keys) for data in epic_items.values()),'Every Epic equipment item owns a real special mechanic channel')
    check(all(all(key in data and str(data[key]).strip() for key in signature_keys) for data in legendary_items.values()),'Every Legendary equipment item declares a signature effect')
    check(all(any(key in data for key in special_mechanic_keys) for data in legendary_items.values()),'Every Legendary equipment item owns a real special mechanic channel')
    check(items['cinnabar_moon_saber'].get('low_health_damage_bonus')==.06,'Cinnabar Moon Saber has Blood Moon low-health damage identity')
    check(items['nine_heavens_star_sword'].get('attack_cooldown_reduction')==.06,'Nine Heavens Star Sword has universal weapon-tempo identity')
    check(items['shadowstep_boots'].get('moving_damage_bonus')==.04,'Shadowstep Boots reward active movement')
    check(items['starstep_boots'].get('level_up_heal_flat')==2.0,'Starstep Boots convert level gains into recovery')
    check(items['sword_heart_pendant'].get('low_health_critical_chance_bonus')==.03,'Sword-Heart Pendant gains critical focus under pressure')
    ascension_multipliers=constant(p/'scripts/ui/equipment_manager.gd','ASCENSION_CORE_MULTIPLIERS')
    ascension_cost_multipliers=constant(p/'scripts/ui/equipment_manager.gd','ASCENSION_COST_MULTIPLIERS')
    ascension_stats=constant(p/'scripts/ui/equipment_manager.gd','ASCENSION_SCALABLE_STATS')
    duplicate_shards=constant(p/'scripts/managers/inventory_manager.gd','DUPLICATE_SHARDS')
    check(ascension_multipliers=={1:1.0,2:1.05,3:1.10,4:1.15,5:1.20},'Equipment Ascension core-passive multipliers are bounded from 1-star through 5-star',ascension_multipliers)
    check(ascension_cost_multipliers=={2:1,3:2,4:3,5:5},'Equipment Ascension shard curve follows 1/2/3/5 duplicate-equivalent steps',ascension_cost_multipliers)
    check(duplicate_shards=={'common':5,'rare':12,'epic':30,'legendary':75},'Duplicate-to-Refinement conversion remains the Ascension economy authority',duplicate_shards)
    check(set(ascension_stats)=={'max_health_flat','damage_bonus','movement_speed_bonus','experience_bonus','critical_chance_bonus'},'Ascension scales core passives only and excludes Signature Effect channels',ascension_stats)
    check(all(token in equipment_manager_text for token in ('var ascension_stars: Dictionary = {}','func get_item_star(','func get_effective_item_data(','func get_ascension_cost_for_star(','func can_ascend_item(','func ascend_item(','SaveManager.write_save_batch({','equipment_ascended.emit')),'EquipmentManager implements persistent atomic 1-star to 5-star Ascension runtime')
    check('"ascension_stars": stars.duplicate(true)' in equipment_manager_text and 'save_data.get("ascension_stars", {})' in equipment_manager_text,'Equipment save payload persists Ascension stars while legacy saves default safely')
    save_manager_text=(p/'scripts/managers/save_manager.gd').read_text(encoding='utf-8-sig')
    check('if data.has("ascension_stars"):' in save_manager_text and 'if star < 1 or star > 5:' in save_manager_text,'SaveManager validates optional Ascension stars without invalidating legacy equipment v1 saves')
    equipment_screen_text=(p/'scripts/ui/equipment_screen.gd').read_text(encoding='utf-8-sig')
    backpack_screen_text=(p/'scripts/ui/backpack_screen.gd').read_text(encoding='utf-8-sig')
    equipment_scene_text=(p/'scenes/ui/equipment_screen.tscn').read_text(encoding='utf-8-sig')
    backpack_scene_text=(p/'scenes/ui/backpack_screen.tscn').read_text(encoding='utf-8-sig')
    ascension_ui_nodes=('AscensionStatusLabel','AscensionPreviewLabel','AscendButton','AscendHintLabel')
    check(all(f'name="{node}"' in equipment_scene_text for node in ascension_ui_nodes) and 'name="SignatureEffectLabel"' in equipment_scene_text,'Hero Equipment scene exposes star/status/preview/Ascend controls and Signature Effect terminology')
    check(all(f'name="{node}"' in backpack_scene_text for node in ascension_ui_nodes),'Hero Backpack scene exposes star/status/preview/Ascend controls')
    check(all(token in equipment_screen_text for token in ('EquipmentManager.get_effective_item_data(','EquipmentManager.get_item_star(','EquipmentManager.get_ascension_cost(','EquipmentManager.ascend_item(','StarBadge','_build_ascension_stat_preview')),'Hero Equipment UI renders effective star-scaled stats and can request Ascension safely')
    check(all(token in backpack_screen_text for token in ('EquipmentManager.get_effective_item_data(','EquipmentManager.get_item_star(','EquipmentManager.get_ascension_cost(','EquipmentManager.ascend_item(','StarBadge','_build_ascension_stat_preview')),'Hero Backpack UI renders effective star-scaled stats and can request Ascension safely')
    check('AwakenedEffectLabel' not in equipment_scene_text and 'awakened_effect_label' not in equipment_screen_text,'Player-facing Equipment detail no longer uses obsolete Awakened Effect naming')
    player_stats_text=(p/'scripts/stats/player_stats.gd').read_text(encoding='utf-8-sig')
    weapon_manager_text=(p/'scripts/weapon/weapon_manager.gd').read_text(encoding='utf-8-sig')
    player_text=(p/'scripts/player/player_1.gd').read_text(encoding='utf-8-sig')
    check(all(key in player_stats_text for key in ('moving_damage_bonus','low_health_damage_bonus','low_health_critical_chance_bonus')),'PlayerStats consumes conditional equipment signature mechanics')
    check('attack_cooldown_reduction' in weapon_manager_text,'WeaponManager consumes Dao Armament cooldown reduction dynamically')
    check('level_up_heal_flat' in player_text,'Player consumes Starstep level-up recovery dynamically')
    check(all(v['price']>0 and v['forge_cost']>0 for v in items.values()),'Positive currency and shard prices')
    baseline_stats={'verdant_qi_robe':('max_health_flat',10),'jade_guard_bracer':('damage_bonus',.05),'cloudstep_boots':('movement_speed_bonus',.05),'spirit_jade_pendant':('experience_bonus',.05)}
    check(all(items[k][field]==value for k,(field,value) in baseline_stats.items()),'Four original equipment bonuses retained')
    icons=constant(p/'scripts/ui/equipment_visual_catalog.gd','ITEM_ICON_PATHS')
    check(set(items)<=set(icons) and 'refinement_shard' in icons and all((p/value[6:]).is_file() for value in icons.values()),'Every equipment/material icon resolves')
    for path in (p/'assets/branding').glob('*.svg'): ET.parse(path)
    languages=constant(p/'scripts/managers/localization_manager.gd','INDONESIAN')
    specs=re.compile(r'%(?:\d+\$)?[-+0 #]*\d*(?:\.\d+)?[sdifg%]')
    mismatches=[key for key,value in languages.items() if specs.findall(key)!=specs.findall(value)]
    check(not mismatches,'Translation format arguments preserved',mismatches)
    check(len(languages)>=300,'Indonesian core message catalog',{'entries':len(languages),'visual_language_qa':'NOT_RUN'})
    expected_png={
        'assets/branding/launcher_192.png':(192,192,8,6),
        'assets/branding/adaptive_foreground_432.png':(432,432,8,6),
        'assets/branding/adaptive_background_432.png':(432,432,8,6),
        'assets/branding/adaptive_monochrome_432.png':(432,432,8,6),
        'release/store/play_icon_512.png':(512,512,8,6),
        'release/store/feature_graphic_1024x500.png':(1024,500,8,2),
    }
    for path,expected in expected_png.items():
        actual=png_header(p/path);check(actual==expected,'PNG dimensions/depth/channels: '+path,actual)
    check((p/'release/store/play_icon_512.png').stat().st_size<=1024*1024,'Play icon below 1 MiB')
    audio_errors=[]
    wavs=list((p/'assets/audio').glob('*.wav'))
    for path in wavs:
        with wave.open(str(path)) as clip:
            if clip.getnframes()==0 or clip.getsampwidth()!=2: audio_errors.append(path.name)
            raw=clip.readframes(clip.getnframes());peak=max(abs(x[0]) for x in struct.iter_unpack('<h',raw))
            if peak>=32767:audio_errors.append(path.name+': clipping')
    oggs=list((p/'assets/audio').glob('*.ogg'))
    check(len(wavs)==16 and len(oggs)==3 and not audio_errors,'Nineteen audio assets; PCM SFX are populated and unclipped',audio_errors)
    check(all(x.read_bytes().startswith(b'OggS') and re.search(r'(?m)^loop\s*=\s*true$', x.with_suffix('.ogg.import').read_text()) for x in oggs),'Music has Ogg containers and loop import settings')
    preset=(p/'export_presets.cfg').read_text()
    expected={'gradle_build/use_gradle_build':'true','gradle_build/export_format':'1','gradle_build/target_sdk':'"36"','gradle_build/min_sdk':'"24"','architectures/arm64-v8a':'true','package/show_as_launcher_app':'false','package/show_in_app_library':'true','screen/immersive_mode':'true','screen/edge_to_edge':'true','permissions/internet':'false','permissions/vibrate':'true'}
    check(all(re.search(r'(?m)^'+re.escape(k)+'='+re.escape(v)+r'$',preset) for k,v in expected.items()),'AAB / API 36 / min 24 / ARM64 / immersive offline preset')
    permissions=re.findall(r'(?m)^permissions/([^=]+)=true$',preset)
    check(permissions==['vibrate'],'Only optional vibration permission enabled',permissions)
    excludes=re.search(r'(?m)^exclude_filter="([^"]*)"',preset)[1]
    check(all(x in excludes.split(',') for x in ['tools/*','tests/*','docs/*','artifacts/*','.local/*','scripts/monetization/debug_provider.gd*']),'Development tools and mock provider excluded from export')
    manifest={str(f.relative_to(p)):hashlib.sha256(f.read_bytes()).hexdigest() for f in project_files(p)}
    status='PASS' if all(c['status']=='PASS' for c in checks) else 'FAIL'
    result={'source_status':status,'engine_status':'NOT_RUN','android_build':'NOT_RUN','device_qa':'NOT_RUN','scope':'Source/data/asset packaging checks only. No gameplay, performance, signing, or Play approval claim.','checks':checks,'counts':{'scripts':len(scripts),'resource_references':source['reference_count'],'source_files':len(manifest)},'file_sha256':manifest}
    (report/'release_source_results.json').write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf-8')
    (report/'resource_audit.json').write_text(json.dumps(source,indent=2,ensure_ascii=False),encoding='utf-8')
    print(f'Source: {status} | {sum(c["status"]=="PASS" for c in checks)}/{len(checks)} checks | Engine/Android/device: NOT_RUN')
    for c in checks:
        if c['status']=='FAIL':print('FAIL:',c['name'],c.get('details',''))
    print('Report:',report/'release_source_results.json')
    return 0 if status=='PASS' else 1

if __name__=='__main__':raise SystemExit(main())
