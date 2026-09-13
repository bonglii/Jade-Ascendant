#!/usr/bin/env python3
"""Regenerate original SVG branding and PNG exports. Requires Inkscape only.
Native vector artwork: jade jian, eight-sided seal, mountain terraces.
No copied third-party marks, external fonts, or embedded photographs.
"""
from pathlib import Path
import subprocess,shutil
ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/branding'
STORE=ROOT/'release/store'
CORE='''<g fill="none" stroke-linecap="round" stroke-linejoin="round">
<path d="M256 116 355 157 396 256 355 355 256 396 157 355 116 256 157 157Z" stroke="#d1ae63" stroke-width="5"/>
<circle cx="256" cy="256" r="124" stroke="#62baa3" stroke-width="2" opacity=".65"/>
<path d="M178 298Q220 222 202 190M334 298Q292 222 310 190" stroke="#5bc4a6" stroke-width="5"/>
<path d="M163 281Q202 281 225 239M349 281Q310 281 287 239" stroke="#c0e3bb" stroke-width="3"/>
<path d="M256 126 274 172 266 293 246 293 238 172Z" fill="#d9f5df" stroke="#63cdb1" stroke-width="4"/>
<path d="M256 137V285" stroke="#6ab3a0" stroke-width="3"/>
<path d="M224 298Q240 286 256 295Q272 286 288 298L283 311Q268 305 256 310Q244 305 229 311Z" fill="#e2c079" stroke="#d1ae63" stroke-width="3"/>
<path d="M250 311H262V345H250Z" fill="#295f55" stroke="#ddbd70" stroke-width="3"/>
<path d="M246 349 256 339 266 349 256 360Z" fill="#efd696" stroke="#d1ae63" stroke-width="2"/>
<path d="M256 360Q234 373 252 388M260 359Q277 374 265 390" stroke="#73ddbe" stroke-width="4"/>
<path d="M246 108 256 94 266 108 256 118Z" fill="#dbbc74" stroke="none"/>
</g>'''
DEFS='''<defs><radialGradient id="bg" cx=".5" cy=".38" r=".75"><stop stop-color="#174e42"/><stop offset="1" stop-color="#051b1b"/></radialGradient><linearGradient id="mist" x2="0" y2="1"><stop stop-color="#2b7460"/><stop offset="1" stop-color="#0a2926"/></linearGradient></defs>'''
BG='''<rect width="512" height="512" fill="url(#bg)"/><path d="M0 390 63 336 112 365 177 316 236 362 306 323 366 360 452 310 512 350V512H0Z" fill="#173d33" opacity=".65"/><path d="M0 441 126 402 204 435 332 398 423 431 512 399V512H0Z" fill="#0c2d29"/>'''
def svg(body,w=512,h=512): return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{DEFS}{body}</svg>\n'
def export(source,destination,width,height):
 subprocess.run(['inkscape',str(source),'--export-type=png',f'--export-filename={destination}',f'--export-width={width}',f'--export-height={height}', '--export-png-color-mode=RGB_8' if width==1024 else '--export-png-color-mode=RGBA_8'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
def main():
 if not shutil.which('inkscape'): raise SystemExit('Install Inkscape to regenerate; finished PNG files are already included.')
 ASSETS.mkdir(parents=True,exist_ok=True); STORE.mkdir(parents=True,exist_ok=True)
 main_icon=svg(BG+'<g transform="translate(-64 -64) scale(1.25)">'+CORE+'</g>')
 (ROOT/'icon.svg').write_text(main_icon)
 (ASSETS/'adaptive_foreground.svg').write_text(svg('<g transform="translate(20.48 20.48) scale(.92)">'+CORE+'</g>'))
 (ASSETS/'adaptive_background.svg').write_text(svg(BG))
 # Monochrome mask uses the same recognizable sword silhouette, no scenery.
 (ASSETS/'adaptive_monochrome.svg').write_text(svg('''<g fill="#ffffff"><path d="M256 126 274 172 266 293 246 293 238 172Z"/><path d="M224 298Q240 286 256 295Q272 286 288 298L283 311Q268 305 256 310Q244 305 229 311Z"/><path d="M250 310H262V348H250Z"/><path d="M246 349 256 339 266 349 256 360Z"/></g>'''))
 export(ROOT/'icon.svg',ASSETS/'launcher_192.png',192,192)
 export(ROOT/'icon.svg',STORE/'play_icon_512.png',512,512)
 for name in ['adaptive_foreground','adaptive_background','adaptive_monochrome']:
  export(ASSETS/(name+'.svg'),ASSETS/(name+'_432.png'),432,432)
 banner='''<rect width="1024" height="500" fill="#071f20"/><circle cx="237" cy="224" r="208" fill="#123e35"/><circle cx="237" cy="224" r="177" fill="none" stroke="#a99159" stroke-width="1" opacity=".5"/><path d="M0 400 105 312 199 386 313 315 418 382 578 313 718 398 865 285 1024 389V500H0Z" fill="#16463a"/><path d="M0 454 143 389 235 423 402 377 536 444 711 367 846 439 1024 374V500H0Z" fill="#0b302b"/><path d="M400 117H950M400 370H950" stroke="#b6a066" stroke-width="1" opacity=".7"/><g transform="translate(19 4) scale(.85)">'''+CORE+'''</g><g fill="#e9d296" font-family="DejaVu Serif,serif"><text x="434" y="218" font-size="72" letter-spacing="14">JADE</text><text x="434" y="294" font-size="51" letter-spacing="3">ASCENDANT</text></g><text x="438" y="342" fill="#a4c8b6" font-family="DejaVu Sans,sans-serif" font-size="16" letter-spacing="3">A PATH TO ASCENSION</text><path d="M938 31H993V85M31 31H86M31 31V85M31 416V469H86M938 469H993V416" stroke="#c8ae70" stroke-width="2" fill="none"/>'''
 (STORE/'feature_graphic.svg').write_text(svg(banner,1024,500))
 export(STORE/'feature_graphic.svg',STORE/'feature_graphic_1024x500.png',1024,500)
 print('Brand icon, adaptive layers, monochrome mask, and store feature graphic exported.')
if __name__=='__main__': main()
