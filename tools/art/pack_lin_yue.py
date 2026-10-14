from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image,ImageOps
from scipy import ndimage
OUT=Path('assets/character/player/polish_20261014');C=96;BASE=82;G=8
records=[]
def isolate(name,cols,rows):
 a=np.array(Image.open(OUT/'sources'/name).convert('RGBA'));labs,n=ndimage.label(a[:,:,3]>120);sizes=np.bincount(labs.ravel());ids=[int(i) for i in np.flatnonzero(sizes>700) if i];boxes=ndimage.find_objects(labs);cells={}
 for i in ids:
  y,x=boxes[i-1];key=(min(rows-1,int((y.start+y.stop)/2/a.shape[0]*rows)),min(cols-1,int((x.start+x.stop)/2/a.shape[1]*cols)));assert key not in cells;cells[key]=i
 assert len(cells)==cols*rows,(name,len(cells))
 main=np.where(np.isin(labs,ids),labs,0);near=ndimage.distance_transform_edt(main==0,return_distances=False,return_indices=True);owners=main[tuple(near)];result=[]
 for row in range(rows):
  for col in range(cols):
   i=cells[row,col];mask=(owners==i)&(a[:,:,3]>3)&ndimage.binary_dilation(labs==i,iterations=5);ys,xs=np.where(mask);x0,x1,y0,y1=xs.min(),xs.max()+1,ys.min(),ys.max()+1;tile=a[y0:y1,x0:x1].copy();tile[:,:,3]=np.where(mask[y0:y1,x0:x1],tile[:,:,3],0);result.append(Image.fromarray(tile))
 return result
def anchor(tile,direction):
 a=np.array(tile);h,w=a.shape[:2];r,g,b=[a[:,:,i].astype(float) for i in range(3)];skin=(r>140)&(g>90)&(b>60)&(r>g*1.1)&(r>b*1.2)&(a[:,:,3]>120);skin[:int(h*.15)]=False;skin[int(h*.43):]=False;ys,xs=np.where(skin)
 if direction!='up' and len(xs)>20:return float(np.median(xs))-(8 if direction=='right' else 0)
 ys,xs=np.where(a[:int(h*.32),:,3]>120);return float(np.median(xs))
def frame(tile,direction,scale):
 ax=anchor(tile,'right' if direction=='left' else direction);tile=tile.resize((max(1,round(tile.width*scale)),max(1,round(tile.height*scale))),Image.Resampling.LANCZOS);x=round(48-ax*scale);y=BASE-tile.height;assert x>=G and x+tile.width<=C-G and y>=G,(x,y,tile.size);out=Image.new('RGBA',(C,C));out.alpha_composite(tile,(x,y));return ImageOps.mirror(out) if direction=='left' else out
def pack(groups,name):
 atlas=Image.new('RGBA',(8*C,len(groups)*C))
 for row,(direction,frames,scale) in enumerate(groups):
  for col,tile in enumerate(frames):
   f=frame(tile,direction,scale);atlas.alpha_composite(f,(col*C,row*C));records.append(dict(atlas=name,row=row,column=col,bounds=list(f.getbbox()),scale=scale))
 atlas.save(OUT/name)
walk=isolate('walk_all.png',4,6);side=isolate('walk_side.png',4,2);other=isolate('idle_hurt_death.png',8,4);wg=[];ig=[]
for direction,source,row in [('down',walk[8:16],0),('left',side,1),('right',side,1),('up',walk[16:24],2)]:
 ws=min(74/max(t.height for t in source),62/max(t.width for t in source));wg.append((direction,source,ws));idle=other[row*8:row*8+8];scale=min(74/max(t.height for t in idle[:4]),62/max(t.width for t in idle));ig.append((direction,idle,scale))
pack(wg,'walk.png');pack(ig,'idle_hurt.png');pack([('down',other[24:],ig[0][2])],'death.png')
lines=['[gd_resource type="SpriteFrames" format=3 uid="uid://0l5fufomktj0"]','']
for i,name in enumerate(['walk','idle_hurt','death'],1):lines.append(f'[ext_resource type="Texture2D" path="res://{OUT}/{name}.png" id="{i}"]')
anims=[];serial=0
for row,direction in enumerate(['down','left','right','up']):
 for name,ext,cols,loop,speed in [('idle',2,[0,1,0,1,0,2,3,0],True,1),('walk',1,list(range(8)),True,8),('hurt',2,[4,5,6,7],False,20),('death',3,list(range(8)),False,10)]:
  frames=[]
  for k,col in enumerate(cols):
   serial+=1;ref=f'AtlasTexture_{serial}';y=0 if ext==3 else row*C;lines.extend(['',f'[sub_resource type="AtlasTexture" id="{ref}"]',f'atlas = ExtResource("{ext}")',f'region = Rect2({col*C}, {y}, {C}, {C})','filter_clip = true']);dur=[.8,.8,.8,.8,.8,.1,.1,.3][k] if name=='idle' else 1;frames.append('{"duration": '+str(dur)+', "texture": SubResource("'+ref+'")}')
  anims.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(loop).lower()+', "name": &"'+name+'_'+direction+'", "speed": '+str(speed)+'}')
lines.extend(['','[resource]','animations = ['+',\n'.join(anims)+']','']);Path('assets/character/player/player_lin_yue_idle_walk_spriteframes.tres').write_text('\n'.join(lines));(OUT/'packing.json').write_text(json.dumps(dict(cell_size=C,feet_baseline=BASE,gutter=G,frames=records,source_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (OUT/'sources').glob('*.png')}),indent=2)+'\n');print('LIN_YUE_PACK_PASS',len(records))
