"""Technical sprite extraction/downsampling only; artistic content is imagegen-authored."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path('assets/effects/legendary_sets')
CELL, GUTTER = 256, 16
records = []
for source in sorted((ROOT / 'sources').glob('*.png')):
    image = Image.open(source).convert('RGBA')
    atlas = Image.new('RGBA', (CELL * 2, CELL * 2))
    frames = []
    for index in range(4):
        row, col = divmod(index, 2)
        box = (round(col * image.width / 2), round(row * image.height / 2),
               round((col + 1) * image.width / 2), round((row + 1) * image.height / 2))
        tile = image.crop(box)
        # Full source cell, including authored translucent glow, stays intact.
        # Padding is added AFTER resampling; filtering cannot touch a neighbor.
        tile.thumbnail((CELL - 2 * GUTTER, CELL - 2 * GUTTER), Image.Resampling.LANCZOS)
        frame = Image.new('RGBA', (CELL, CELL))
        frame.alpha_composite(tile, ((CELL - tile.width) // 2, (CELL - tile.height) // 2))
        atlas.alpha_composite(frame, (col * CELL, row * CELL))
        frames.append({'index': index, 'region': [col * CELL, row * CELL, CELL, CELL],
                       'used_rect': list(frame.getbbox())})
    path = ROOT / source.name
    atlas.save(path, optimize=True)
    records.append({'set_id': source.stem, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                    'atlas_sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'frames': frames})
(ROOT / 'packing.json').write_text(json.dumps({'cell': CELL, 'gutter': GUTTER, 'components':
    ['ground_seal', 'open_halo', 'crest', 'guardian'], 'sets': records}, indent=2) + '\n')
print('LEGENDARY_PACK_PASS sets=%d components=%d' % (len(records), len(records) * 4))
