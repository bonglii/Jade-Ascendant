#!/usr/bin/env python3
"""Deterministic exports of the original Jade Ascendant seal/lockup masters.
Requires Inkscape. Master artwork is generated once; exports never regenerate it.
"""
from pathlib import Path
import base64
import subprocess
import shutil
ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/branding'
STORE = ROOT / 'release/store'
COLOR = '#061b1d'

def image(name, x, y, width, height):
    encoded = base64.b64encode((ASSETS / name).read_bytes()).decode('ascii')
    return f'<image x="{x}" y="{y}" width="{width}" height="{height}" xlink:href="data:image/png;base64,{encoded}"/>'

def svg(body, w=512, h=512):
    return f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n'

DEFS = '<defs><radialGradient id="jade"><stop stop-color="#19534a"/><stop offset=".58" stop-color="#0b302e"/><stop offset="1" stop-color="#061b1d"/></radialGradient></defs>'
def background(w, h):
    return DEFS + f'<rect width="{w}" height="{h}" fill="{COLOR}"/><ellipse cx="{w*.5}" cy="{h*.43}" rx="{w*.78}" ry="{h*.55}" fill="url(#jade)"/>'

def export(source, destination, w, h, opaque=False):
    subprocess.run(['inkscape', str(source), '--export-type=png', f'--export-filename={destination}', f'--export-width={w}', f'--export-height={h}', '--export-png-color-mode=RGB_8' if opaque else '--export-png-color-mode=RGBA_8'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

def main():
    if not shutil.which('inkscape'):
        raise SystemExit('Inkscape is required only to regenerate exports. Finished PNG files are included.')
    STORE.mkdir(parents=True, exist_ok=True)
    (ROOT / 'icon.svg').write_text(svg(background(512, 512) + image('jade_seal_master.png', 44, 35, 424, 424)))
    (ASSETS / 'adaptive_foreground.svg').write_text(svg(image('jade_seal_master.png', 107, 107, 298, 298)))
    (ASSETS / 'adaptive_background.svg').write_text(svg(background(512, 512)))
    # A readable one-color silhouette is intentionally simpler than painted art.
    mono = '<g fill="#ffffff"><path d="M256 124 270 162 263 302H249L242 162Z M222 302Q256 286 290 302L284 318H263V362H249V318H228Z"/><path d="M228 155C135 171 114 280 166 344C188 373 220 385 248 386V367C188 358 151 315 153 260C154 217 180 185 217 177L202 195L241 180Z M280 155C373 171 395 280 342 344C321 372 294 384 269 386V367C327 353 359 310 357 260C356 216 331 185 295 177L310 195L271 180Z"/></g>'
    (ASSETS / 'adaptive_monochrome.svg').write_text(svg(mono))
    export(ROOT/'icon.svg', ASSETS/'launcher_192.png', 192, 192, True)
    export(ROOT/'icon.svg', STORE/'play_icon_512.png', 512, 512, True)
    for name in ['adaptive_foreground', 'adaptive_background', 'adaptive_monochrome']:
        export(ASSETS/(name+'.svg'), ASSETS/(name+'_432.png'), 432, 432, name=='adaptive_background')
    # Padded native splash symbol, within the Android circular icon safe region.
    (ASSETS/'boot_seal.svg').write_text(svg(image('jade_seal_master.png', 108, 108, 296, 296)))
    export(ASSETS/'boot_seal.svg', ASSETS/'boot_seal.png', 512, 512)
    (ASSETS/'title_lockup.svg').write_text(svg(image('jade_lockup_master.png', 0, 0, 1024, 1024), 1024, 1024))
    export(ASSETS/'title_lockup.svg', ASSETS/'title_lockup.png', 1024, 1024)
    w, h = 648, 1152
    rings = ''.join(f'<circle cx="324" cy="470" r="{r}" fill="none" stroke="#a5a06a" stroke-width=".7" opacity="{o}"/>' for r,o in [(202,.12),(214,.08),(302,.05)])
    mountains = '<path d="M0 1020 92 900 164 957 241 864 336 957 430 907 515 972 590 886 648 951V1152H0Z" fill="#0a2828"/><path d="M0 1080 160 990 283 1065 401 965 549 1051 648 998V1152H0Z" fill="#071f21"/>'
    (ASSETS/'boot_backdrop.svg').write_text(svg(background(w,h)+rings+mountains,w,h))
    export(ASSETS/'boot_backdrop.svg', ASSETS/'boot_backdrop.png', w,h,True)
    feature = background(1024,500)+ '<circle cx="512" cy="242" r="214" fill="none" stroke="#bb9957" stroke-width="1" opacity=".20"/>'+ image('jade_lockup_master.png',287,14,450,450)
    (STORE/'feature_graphic.svg').write_text(svg(feature,1024,500))
    export(STORE/'feature_graphic.svg',STORE/'feature_graphic_1024x500.png',1024,500,True)
    print('BRANDING_EXPORTS=PASS; ICON=512; FEATURE=1024x500; ADAPTIVE_SAFE=298/512')
if __name__ == '__main__': main()
