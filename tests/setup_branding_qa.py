"""Small isolated startup fixture: real Boot/presentation, fake account only.
No Firebase, network, player saves, or purchase SDK is started.
"""
import shutil
import sys
from pathlib import Path
repo = Path(__file__).resolve().parents[1]
qa = Path(sys.argv[1]).resolve()
qa.mkdir(parents=True, exist_ok=True)
for rel in ['scenes/system/boot.tscn', 'scripts/system/boot.gd', 'scripts/system/brand_opening.gd', 'tests/branding_opening_smoke.gd']:
    target=qa/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(repo/rel,target)
(qa/'assets').mkdir(exist_ok=True)
if not (qa/'assets/branding').exists(): (qa/'assets/branding').symlink_to(repo/'assets/branding',target_is_directory=True)
(qa/'account.gd').write_text('extends Node\nvar refreshes: int = 0\nfunc refresh_provider(): refreshes += 1\nfunc get_account_snapshot(): return {"signed_in": "--signed-in" in OS.get_cmdline_user_args()}\n')
(qa/'settings.gd').write_text('extends Node\nvar reduced_effects: bool = "--reduced" in OS.get_cmdline_user_args()\nvar language: String = "id" if "--id" in OS.get_cmdline_user_args() else "en"\n')
for name,title in [('main_menu','MainDestination'),('google_account_entry','AccountDestination')]:
    target=qa/f'scenes/ui/{name}.tscn';target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(f'[gd_scene format=3]\n[node name="{title}" type="Control"]\n')
(qa/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Jade branding isolated QA"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="jade_branding_isolated_qa"\n[autoload]\nGoogleAccountManager="*res://account.gd"\nSettingsManager="*res://settings.gd"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
print('BRANDING_QA_SCOPE=ISOLATED; NETWORK=NONE; PLAYER_SAVES=NONE')
