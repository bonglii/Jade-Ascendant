from pathlib import Path
import hashlib,json
from PIL import Image
root=Path('assets/effects/combat_cels');m=json.loads((root/'packing.json').read_text());checks=0
assert {e['kit'] for e in m['kits']}=={'blades','hostile','impacts'}
for entry in m['kits']:
    path=root/(entry['kit']+'.png');image=Image.open(path)
    assert image.mode=='RGBA' and hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'];checks+=1
    for f in entry['frames']:
        x,y,w,h=f['region'];alpha=image.crop((x,y,x+w,y+h)).getchannel('A')
        assert alpha.getbbox() is not None
        for box in [(0,0,256,16),(0,240,256,256),(0,0,16,256),(240,0,256,256)]:
            assert alpha.crop(box).getextrema()==(0,0),(entry['kit'],f['region']);checks+=1
        assert list(alpha.getbbox())==f['bounds'];checks+=1
print('COMBAT_CEL_ASSET_PASS checks=%d frames=16 gutter=16px'%checks)
