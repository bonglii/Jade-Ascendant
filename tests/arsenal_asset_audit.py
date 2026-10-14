"""Inspect shipped pixels/audio, not generated concepts. Requires Pillow."""
from pathlib import Path
from PIL import Image
import hashlib, json, wave, struct
root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / 'backend/player_identity/mail_reward_catalog.json').read_text())
ids = [x for x in catalog['equipment'] if '/expansion_20261014/' in x['icon_source']]
assert len(ids) == 14
checks = 1
for item in ids:
    path = root / item['icon_source'][6:]
    image = Image.open(path)
    size = 512 if item['slot'] == 'armament' else 256
    assert image.mode == 'RGBA' and image.size == (size, size), item['id']
    alpha = image.getchannel('A').point(lambda value: 255 if value >= 16 else 0)
    bounds = alpha.getbbox()
    assert bounds and min(bounds[0], bounds[1], size-bounds[2], size-bounds[3]) >= (20 if size == 512 else 12), item['id']
    dashboard = root / 'backend/player_identity/web_assets/admin/assets' / (item['id']+'.png')
    assert hashlib.sha256(path.read_bytes()).digest() == hashlib.sha256(dashboard.read_bytes()).digest(), item['id']
    checks += 3
for path in (root / 'assets/audio/arsenal_20261014').glob('*.wav'):
    with wave.open(str(path), 'rb') as sound:
        assert sound.getnchannels() == 1 and sound.getsampwidth() == 2 and sound.getframerate() == 22050
        samples = struct.unpack('<'+'h'*sound.getnframes(), sound.readframes(sound.getnframes()))
        assert 0 < max(abs(x) for x in samples) < 32767*.34
        assert len(samples)/22050 <= 1.0
        checks += 3
print(f'ARSENAL_ASSET_AUDIT checks={checks} failures=0')
