"""Exercise the real Android preset export hook using a tiny pack, not an APK."""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
godot = str(Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="jade-metadata-") as temporary:
    root = Path(temporary)
    shutil.copytree(repo / "addons/JadeReleaseMetadata", root / "addons/JadeReleaseMetadata")
    native = root / "addons/JadeMonetizationNativeBridge/bin/release"
    native.mkdir(parents=True)
    shutil.copyfile(repo / "release/native/JadeMonetizationNativeBridge-production-candidate.aar", native / "JadeMonetizationNativeBridge-release.aar")
    proof_path = repo / "docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json"
    proof = json.loads(proof_path.read_text())
    candidate = repo / "release/native/JadeMonetizationNativeBridge-production-candidate.aar"
    actual_digest = hashlib.sha256(candidate.read_bytes()).hexdigest()
    assert proof.get("target") == "production-candidate" and actual_digest == proof["aar_sha256"], "Current native candidate must match its independent proof"
    (root / "docs/checkpoints").mkdir(parents=True)
    shutil.copyfile(proof_path, root / "docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json")
    (root / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Metadata fixture"\n[editor_plugins]\nenabled=PackedStringArray("res://addons/JadeReleaseMetadata/plugin.cfg")\n')
    (root / "export_presets.cfg").write_text('[preset.0]\nname="Android"\nplatform="Android"\nrunnable=false\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\nexport_path=""\n[preset.0.options]\nversion/name="9.8.7"\nversion/code=987\npackage/unique_name="com.yungdevstudio.jadeascendant"\n')
    env = dict(os.environ, JADE_BUILD_SOURCE_REVISION="a" * 40)
    prefix = [godot, "--headless", "--audio-driver", "Dummy", "--path", str(root)]
    for suffix in [["--editor", "--import", "--quit"], ["--export-pack", "Android", str(root / "metadata.zip")]]:
        result = subprocess.run(prefix + suffix, env=env, capture_output=True, text=True, timeout=40)
        log = result.stdout + result.stderr
        assert result.returncode == 0 and "SCRIPT ERROR" not in log and "ERROR:" not in log, log
    with zipfile.ZipFile(root / "metadata.zip") as archive:
        name = next(name for name in archive.namelist() if name.endswith("release/build_metadata.json"))
        data = json.loads(archive.read(name))
    assert data["version_name"] == "9.8.7" and data["version_code"] == 987
    assert data["iap_target"] == "production" and data["debug"] is False
    assert data["source_revision"] == "a" * 40
    assert data["native_sha256"] == actual_digest
print("ANDROID_EXPORT_METADATA_HOOK=PASS; PRESET_VERSION_CODE_SOURCE_TARGET=VERIFIED; APK_BUILD=NONE")
