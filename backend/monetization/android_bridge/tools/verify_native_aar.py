"""Check compiled Godot JNI surface and locked release constants; no purchases/network."""
from pathlib import Path
import re, subprocess, tempfile, zipfile, json, hashlib
root=Path(__file__).resolve().parents[1]
source=(root/'bridge/src/main/java/com/yungdevstudio/jadeascendant/monetizationbridge/JadeMonetizationNativeBridge.kt').read_text()
methods=re.findall(r'@UsedByGodot\s+fun\s+(\w+)',source)
assert len(methods)>=10,'Incomplete source JNI inventory'
results=[]
for variant in ['debug','release']:
 artifacts=list((root/'bridge/build/outputs/aar').glob('*-'+variant+'.aar'))
 assert len(artifacts)==1,(variant,'Ambiguous artifact')
 aar=artifacts[0]
 with tempfile.TemporaryDirectory() as temp:
  jar=Path(temp)/'classes.jar'
  with zipfile.ZipFile(aar) as z:
   assert z.testzip() is None,'AAR CRC mismatch'
   jar.write_bytes(z.read('classes.jar'))
  def javap(*args):return subprocess.check_output(['javap','-classpath',str(jar),*args],text=True)
  surface=javap('-public','com.yungdevstudio.jadeascendant.monetizationbridge.JadeMonetizationNativeBridge')
  assert 'org.godotengine.godot.Godot' in surface,'Godot constructor missing'
  for method in methods:assert re.search(r'\b'+re.escape(method)+r'\(',surface),method
  flags=javap('-constants','com.yungdevstudio.jadeascendant.monetizationbridge.BuildConfig')
  if variant=='release':
   assert 'iap-disabled.invalid' in flags and 'JADE_IAP_STAGING_CREDIT_ENABLED = false' in flags,'Release unlock forbidden'
  results.append({'variant':variant,'jni_methods':len(methods),'sha256':hashlib.sha256(aar.read_bytes()).hexdigest()})
print(json.dumps({'native_contract':'PASS','artifacts':results}))
