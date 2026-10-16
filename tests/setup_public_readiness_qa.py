"""Use a disposable user-data scope; never run save fixtures on a player's files."""
import re
import sys
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
qa = Path(sys.argv[1]).resolve()
qa.mkdir(parents=True, exist_ok=True)
for name in ["assets", "scripts", "scenes", "tests", "backend", "addons", "release"]:
    target = qa / name
    if not target.exists():
        target.symlink_to(repo / name, target_is_directory=True)
source = (repo / "project.godot").read_text()
source = re.sub(r"\[editor_plugins\][\s\S]*?(?=\n\[|\Z)", "[editor_plugins]\nenabled=PackedStringArray()\n", source)
for folder in ["scripts", "addons"]:
    for path in (repo / folder).rglob("*.gd.uid"):
        uid = path.read_text().strip()
        if uid in source:
            source = source.replace(uid, "res://" + str(path.relative_to(repo)).removesuffix(".uid"))
source = source.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="jade_paid_v2_qa_public_readiness"')
(qa / "project.godot").write_text(source)
