from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image,ImageOps
from scipy import ndimage
SOURCE=Path('assets/character/player/polish_20261014');OUT=Path('assets/ui/liveops/odyssey/pawn_v2');OUT.mkdir(parents=True,exist_ok=True);C=192;BASE=164;G=16
records=[]
def isolate(name,cols,rows):
 a=np.array(Image.open(SOURCE/'sources'/name).convert('RGBA'));labs,n=ndimage.label(a[:,:,3]>120);sizes=np.bincount(labs.ravel());ids=[int(i) for i in np.flatnonzero(sizes>700) if i];boxes=ndimage.find_objects(labs);cells={}
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
 ax=anchor(tile,'right' if direction=='left' else direction);tile=tile.resize((max(1,round(tile.width*scale)),max(1,round(tile.height*scale))),Image.Resampling.LANCZOS);x=round(C/2-ax*scale);y=BASE-tile.height;assert x>=G and x+tile.width<=C-G and y>=G,(x,y,tile.size);out=Image.new('RGBA',(C,C));out.alpha_composite(tile,(x,y));return ImageOps.mirror(out) if direction=='left' else out
def pack(groups,name):
 atlas=Image.new('RGBA',(8*C,len(groups)*C))
 for row,(direction,frames,scale) in enumerate(groups):
  for col,tile in enumerate(frames):
   f=frame(tile,direction,scale);atlas.alpha_composite(f,(col*C,row*C));records.append(dict(atlas=name,row=row,column=col,bounds=list(f.getbbox()),scale=scale))
 atlas.save(OUT/name)

walk=isolate('walk_all.png',4,6);side=isolate('walk_side.png',4,2);other=isolate('idle_hurt_death.png',8,4);walk_groups=[];idle_groups=[]
for direction,source,row in [('down',walk[8:16],0),('left',side,1),('right',side,1),('up',walk[16:24],2)]:
 ws=min(148/max(t.height for t in source),124/max(t.width for t in source));walk_groups.append((direction,source,ws))
 idle=other[row*8:row*8+4];scale=min(148/max(t.height for t in idle),124/max(t.width for t in idle));idle_groups.append((direction,idle,scale))
pack(walk_groups,'walk.png');pack(idle_groups,'idle.png')
lines=['[gd_resource type="SpriteFrames" format=3]','']
for i,name in enumerate(['walk','idle'],1):lines.append(f'[ext_resource type="Texture2D" path="res://{OUT}/{name}.png" id="{i}"]')
anims=[];serial=0
for row,direction in enumerate(['down','left','right','up']):
 for name,ext,cols,speed in [('idle',2,[0,1,0,1,0,2,3,0],1),('walk',1,list(range(8)),8)]:
  frames=[]
  for k,col in enumerate(cols):
   serial+=1;ref=f'AtlasTexture_{serial}';lines.extend(['',f'[sub_resource type="AtlasTexture" id="{ref}"]',f'atlas = ExtResource("{ext}")',f'region = Rect2({col*C}, {row*C}, {C}, {C})','filter_clip = true']);dur=[.8,.8,.8,.8,.8,.1,.1,.3][k] if name=='idle' else 1;frames.append('{"duration": '+str(dur)+', "texture": SubResource("'+ref+'") }')
  anims.append('{"frames": ['+', '.join(frames)+'], "loop": true, "name": &"'+name+'_'+direction+'", "speed": '+str(speed)+'}')
lines.extend(['','[resource]','animations = ['+',\n'.join(anims)+']','']);(OUT/'lin_yue_board.tres').write_text('\n'.join(lines));(OUT/'packing.json').write_text(json.dumps(dict(cell_size=C,feet_baseline=BASE,gutter=G,frames=records,source_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (SOURCE/'sources').glob('*.png')}),indent=2)+'\n');print('ODYSSEY_PAWN_PACK_PASS',len(records))
