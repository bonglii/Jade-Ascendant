"""Validate exported assets, including content rather than file existence alone."""
from pathlib import Path
from PIL import Image
repo=Path(__file__).resolve().parents[1]
for rel,size,mode in [('release/store/play_icon_512.png',(512,512),'RGB'),('release/store/feature_graphic_1024x500.png',(1024,500),'RGB'),('assets/branding/adaptive_foreground_432.png',(432,432),'RGBA'),('assets/branding/boot_seal.png',(512,512),'RGBA')]:
    im=Image.open(repo/rel)
    assert im.size==size and im.mode==mode,(rel,im.size,im.mode)
    assert len(im.getcolors(1000000) or [])>1000,rel+' must contain rendered artwork'
    if mode=='RGBA':
        low,high=im.getchannel('A').getextrema()
        assert low==0 and high>=250,rel+' transparent padding/solid artwork'
        box=im.getbbox()
        assert box and min(box[:2])>0 and box[2]<size[0] and box[3]<size[1],rel+' needs safe padding'
    print('ASSET_QA=PASS',rel,size,mode)
