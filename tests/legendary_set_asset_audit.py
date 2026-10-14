import hashlib
import json
from pathlib import Path
from PIL import Image

root = Path('assets/effects/legendary_sets')
manifest = json.loads((root / 'packing.json').read_text())
assert {entry['set_id'] for entry in manifest['sets']} == {
    'nine_heavens', 'solar_meridian', 'vermilion_verdict', 'celestial_aegis'}
checks = 1
cell, gutter = manifest['cell'], manifest['gutter']
for entry in manifest['sets']:
    path = root / (entry['set_id'] + '.png')
    assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['atlas_sha256']
    image = Image.open(path)
    assert image.mode == 'RGBA' and image.size == (cell * 2, cell * 2)
    checks += 2
    for frame in entry['frames']:
        x, y, w, h = frame['region']
        alpha = image.crop((x, y, x + w, y + h)).getchannel('A')
        assert alpha.getbbox() is not None
        # Exact alpha=0, even low-opacity authored glow may not cross a gutter.
        for box in [(0, 0, cell, gutter), (0, cell-gutter, cell, cell),
                    (0, 0, gutter, cell), (cell-gutter, 0, cell, cell)]:
            assert alpha.crop(box).getextrema() == (0, 0), (entry['set_id'], frame['index'], box)
        assert list(alpha.getbbox()) == frame['used_rect']
        checks += 6
print('LEGENDARY_ASSET_PASS checks=%d components=16 gutter=16px' % checks)
