"""Collect a fully compiled/tested Android candidate; retain strict export pins."""
import argparse, datetime, hashlib, json, os, pathlib, re, shutil, subprocess, tempfile, xml.etree.ElementTree as ET, zipfile

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def text_hash(path):
    return hashlib.sha256(path.read_text(encoding='utf-8-sig').replace('\r\n','\n').encode()).hexdigest()
def collect(repo, dependencies, java_home):
    installed = repo/'addons/JadeMonetizationNativeBridge/bin/release/JadeMonetizationNativeBridge-release.aar'
    original_bridge_hash = digest(installed)
    build = repo/'backend/monetization/android_bridge'
    aar = build/'bridge/build/outputs/aar/JadeMonetizationNativeBridge-release.aar'
    assert aar.is_file(), 'Release AAR missing'
    dependency_text = dependencies.read_text()
    assert 'BUILD SUCCESSFUL' in dependency_text and 'firebase-appcheck-playintegrity' in dependency_text and 'firebase-messaging:25.1.3' in dependency_text and 'firebase-appcheck-debug' not in dependency_text, 'Release dependency evidence invalid'
    suites = []
    for variant in ['Debug','Release']:
        reports = list((build/('bridge/build/test-results/test'+variant+'UnitTest')).glob('TEST-*.xml'))
        assert reports, 'JVM reports missing: '+variant
        variant_count = 0
        for path in reports:
            root = ET.parse(path).getroot()
            assert all(int(root.get(key,'0')) == 0 for key in ['failures','errors','skipped']), 'Failed/skipped JVM suite: '+path.name
            count = int(root.get('tests','0')); variant_count += count
            suites.append({'variant':variant,'suite':root.get('name'),'tests':count,'failures':0,'errors':0,'skipped':0,'sha256':digest(path)})
        assert variant_count >= 121, 'Missing original/new JVM tests'
        trials = [s for s in suites if s['variant']==variant and s['suite'].endswith('HeavenlyTrialsContractV1Test')]
        assert len(trials)==1 and trials[0]['tests']>=6, 'Ruleset contract tests missing'
    javap = java_home/'bin'/('javap.exe' if os.name=='nt' else 'javap')
    assert javap.is_file(), 'JDK javap required'
    with tempfile.TemporaryDirectory() as temporary:
        jar = pathlib.Path(temporary)/'classes.jar'
        with zipfile.ZipFile(aar) as archive:
            jar.write_bytes(archive.read('classes.jar'))
            assert 'res/xml/jade_run_card_paths.xml' in archive.namelist(), 'Restricted PNG provider paths missing'
            manifest = archive.read('AndroidManifest.xml').decode()
            assert '.jade_run_cards' in manifest and 'JadeRunCardProvider' in manifest and 'JadeRunCardSaveActivity' in manifest
            assert 'WRITE_EXTERNAL_STORAGE' not in manifest and 'READ_MEDIA_IMAGES' not in manifest, 'Broad storage permission forbidden'
        namespace = 'com.yungdevstudio.jadeascendant.monetizationbridge.'
        def inspect(*args):
            return subprocess.check_output([str(javap),'-classpath',str(jar),*args],text=True)
        flags = inspect('-constants',namespace+'BuildConfig')
        for value in ['DEBUG = false','JADE_IAP_PRODUCTION_CANDIDATE_ENABLED = true','JADE_IAP_STAGING_CREDIT_ENABLED = false','JADE_IAP_GAMEPLAY_V2_ENABLED = true','JADE_IAP_TARGET = "production-candidate"','JADE_IAP_WORKER_BASE_URL = "https://jade-ascendant-iap.jade-ascendant-studio.workers.dev"']:
            assert value in flags, 'Native release flag mismatch: '+value
        jni = inspect('-public',namespace+'JadeMonetizationNativeBridge')
        for method in ['exportRunCardV1','requestHeavenlyTrialsV1','getPluginSignals']:
            assert method in jni, 'Native method missing: '+method
    subprocess.run(['node',str(repo/'backend/player_identity/production_release_contract.mjs')],check=True)
    installed = repo/'addons/JadeMonetizationNativeBridge/bin/release/JadeMonetizationNativeBridge-release.aar'
    assert digest(installed)==original_bridge_hash, 'Installed bridge changed during candidate inspection; nothing overwritten'
    paths = list((build/'bridge/src').rglob('*.kt')) + list((build/'bridge/src/main').rglob('*.xml'))
    paths += [repo/p for p in ['backend/monetization/android_bridge/build.gradle.kts','backend/monetization/android_bridge/settings.gradle.kts','backend/monetization/android_bridge/bridge/build.gradle.kts','addons/JadeMonetizationNativeBridge/export_plugin.gd','backend/monetization/android_bridge/bridge/src/test/resources/odyssey_snapshot_v1.json','backend/monetization/android_bridge/bridge/src/test/resources/heavenly_trials_snapshot_v1.json']]
    inputs = {p.relative_to(repo).as_posix():text_hash(p) for p in sorted(set(paths))}
    assert len(inputs)==50, 'Native input inventory changed; review exact set before updating pins'
    proof = {'version':1,'target':'production-candidate','installed':False,'deployed':False,'inputs':inputs,'aar_sha256':digest(aar),'compiled_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'jvm_test_executions':sum(s['tests'] for s in suites),'heavenly_trials_protocol':1,'heavenly_trials_ruleset':2,'run_card_export':1,'update_notifications':1,'odyssey_shop_protocol':4,'odyssey_flow_revision':4,'evidence':'COMPILE_JVM_JNI_PLAY_INTEGRITY_PROVIDER_ONLY_NOT_LIVE_PLAY'}
    # All validation completes before any binary/provenance/export pin is replaced.
    destination = repo/'release/native/JadeMonetizationNativeBridge-production-candidate.aar'
    proof_path = repo/'docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json'
    exporter = repo/'backend/player_identity/export_production.ps1'
    export_text = exporter.read_text()
    export_text, n = re.subn(r"(?m)^\$candidateHash = '[a-f0-9]{64}'", "$candidateHash = '"+proof['aar_sha256']+"'",export_text); assert n==1
    old_pin = re.search(r"if \(\(TextHash \$proofPath\) -ne '([a-f0-9]{64})'\)",export_text);assert old_pin
    old_count = re.search(r'\$inputs.Count -ne (\d+)',export_text);assert old_count and int(old_count[1]) in [48,50]
    shutil.copyfile(aar,destination)
    proof_path.write_text(json.dumps(proof,indent=2,sort_keys=True)+'\n',encoding='utf-8')
    export_text = export_text.replace(old_pin[1],text_hash(proof_path)).replace('$inputs.Count -ne '+old_count[1],'$inputs.Count -ne 50').replace('INPUTS='+old_count[1],'INPUTS=50')
    exporter.write_text(export_text,encoding='utf-8')
    evidence = repo/'docs/checkpoints/player-8-10';evidence.mkdir(exist_ok=True)
    (evidence/'native-tests.json').write_text(json.dumps({'suites':suites,'test_executions':proof['jvm_test_executions'],'android_device_tested':False},indent=2)+'\n')
    (evidence/'native-flags.txt').write_text(flags)
    (evidence/'native-jni.txt').write_text(jni)
    shutil.copyfile(dependencies,evidence/'release-dependencies.txt')
    assert digest(installed)==original_bridge_hash, 'Installed bridge changed during candidate collection'
    print(json.dumps({'native_compile':'PASS','jvm_test_executions':proof['jvm_test_executions'],'source_inputs':len(inputs),'candidate_sha256':proof['aar_sha256'],'installed':False,'deployed':False,'android_tested':False}))
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--repo',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[2]);parser.add_argument('--dependencies',type=pathlib.Path,required=True);parser.add_argument('--java-home',type=pathlib.Path,default=pathlib.Path(os.environ.get('JAVA_HOME','')));args=parser.parse_args()
    collect(args.repo.resolve(),args.dependencies.resolve(),args.java_home.resolve())
