"""Isolated real-autoload parser check; production warning settings stay untouched."""
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[1]
qa=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/setup_public_readiness_qa.py'),str(qa)],check=True)
p=qa/'project.godot'
s=p.read_text().replace('jade_paid_v2_qa_public_readiness','jade_warning_cleanup_qa')
# Source currently has no debug section; fail if that contract changes.
assert '[debug]' not in s
s+='\n[debug]\ngdscript/warnings/shadowed_variable=2\ngdscript/warnings/shadowed_variable_base_class=2\ngdscript/warnings/narrowing_conversion=2\n'
p.write_text(s)
print('WARNING_QA_SCOPE=ISOLATED; PRODUCTION_CONFIG=UNCHANGED')
