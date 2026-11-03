"""Meaningful reference-detection fixtures; no game/player userdata is used."""
from pathlib import Path
import importlib.util, json, subprocess, tempfile, unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('audit_repository',ROOT/'tools/repo_hygiene/audit_repository.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class RepositoryAuditTest(unittest.TestCase):
    def test_godot_uid_formats_global_classes_and_ignored_sources(self):
        with tempfile.TemporaryDirectory(prefix='jade_hygiene_qa_') as d:
            root=Path(d)
            files={
                'project.godot':'[application]\nrun/main_scene="res://main.tscn"\n',
                'export_presets.cfg':'exclude_filter="tests/*,tools/*,docs/*,artifacts/*,.local/*"\n',
                'main.tscn':'[ext_resource path="res://main.gd" type="Script" id="1"]\n',
                'main.gd':'extends Node\nvar sdk=ExampleAd.new()\nconst A="uid://abc123"\nfunc get_art():return load("res://assets/boss_%d.png" % 1)\n',
                'addons/example/plugin.cfg':'[plugin]\nscript="editor.gd"\n',
                'addons/example/editor.gd':'extends EditorPlugin\nfunc files():return DirAccess.get_files_at("res://")\n',
                'addons/example/ad.gd':'class_name ExampleAd\nextends RefCounted\n',
                'assets/uid.png':'uid texture',
                'assets/uid.png.import':'[remap]\nuid="uid://abc123"\n[deps]\nsource_file="res://assets/uid.png"\n',
                'assets/boss_1.png':'boss one','assets/boss_2.png':'boss two',
                'assets/orphan.png':'orphan',
                'assets/sources/.gdignore':'','assets/sources/master.png':'master',
                'tools/master.py':'source="assets/sources/master.png"\n',
                'docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json':json.dumps({'inputs':{}}),
            }
            for name,text in files.items():
                p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
            for args in [['init','-q'],['config','user.name','Fixture'],['config','user.email','qa@example.invalid'],['add','--all'],['commit','-qm','fixture']]:subprocess.run(['git',*args],cwd=root,check=True,capture_output=True)
            result=module.audit(root);resources={r['path']:r for r in result['resources']}
            self.assertTrue(resources['assets/uid.png']['reachable'])
            self.assertTrue(resources['assets/boss_1.png']['reachable'])
            self.assertTrue(resources['assets/boss_2.png']['reachable'])
            self.assertTrue(resources['addons/example/ad.gd']['reachable'])
            self.assertFalse(resources['assets/orphan.png']['reachable'])
            self.assertTrue(resources['assets/sources/master.png']['godot_ignored'])
            self.assertFalse(resources['assets/sources/master.png']['reachable'])
            self.assertIn('tools/master.py',resources['assets/sources/master.png']['other_name_consumers'])
            self.assertFalse(result['uid_collisions'])
            self.assertTrue(all(result['export_dev_exclusions'].values()))
            self.assertTrue((root/'assets/orphan.png').exists(),'audit never deletes candidates')

if __name__=='__main__':unittest.main()
