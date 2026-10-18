"""Compile real scripts/autoloads with every enabled default warning as error.
Godot supplies its own warning list; production configuration is never changed.
Usage: python tests/setup_warning_cleanup_qa.py QA_DIR /path/to/godot
"""
from pathlib import Path
import json,os,shutil,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
qa=Path(sys.argv[1]).resolve()
godot=sys.argv[2] if len(sys.argv)>2 else os.environ.get('GODOT_BIN') or shutil.which('godot') or shutil.which('godot4')
if not godot:raise SystemExit('Supply the Godot executable as the second argument.')
subprocess.run([sys.executable,str(root/'tests/setup_public_readiness_qa.py'),str(qa)],check=True)
with tempfile.TemporaryDirectory(prefix='jade-warning-probe-') as temp:
    probe=Path(temp)
    (probe/'project.godot').write_text('config_version=5\n')
    (probe/'probe.gd').write_text('''extends SceneTree
func _initialize() -> void:
 var enabled: Dictionary={}
 for property: Dictionary in ProjectSettings.get_property_list():
  var key: String=str(property.name)
  if not key.begins_with('debug/gdscript/warnings/'):continue
  var value: Variant=ProjectSettings.get_setting(key)
  if typeof(value)==TYPE_INT and int(value)>0:enabled[key]=2
 print('WARNING_LEVELS='+JSON.stringify(enabled))
 quit()
''')
    r=subprocess.run([godot,'--headless','--path',str(probe),'--script','res://probe.gd'],capture_output=True,text=True,check=True,timeout=30)
    lines=[line for line in r.stdout.splitlines() if line.startswith('WARNING_LEVELS=')]
    if len(lines)!=1:raise SystemExit('Could not collect Godot default warnings: '+r.stdout+r.stderr)
    levels=json.loads(lines[0].split('=',1)[1])
    assert levels.get('debug/gdscript/warnings/incompatible_ternary')==2
p=qa/'project.godot'
s=p.read_text().replace('jade_paid_v2_qa_public_readiness','jade_warning_cleanup_qa')
assert '[debug]' not in s,'Review existing debug settings before merging QA-only overrides.'
s+='\n[debug]\n'+''.join(key.removeprefix('debug/')+'=2\n' for key in sorted(levels))
p.write_text(s)
print(f'WARNING_QA_SCOPE=ISOLATED; CATEGORIES={len(levels)}; PRODUCTION_CONFIG=UNCHANGED')
