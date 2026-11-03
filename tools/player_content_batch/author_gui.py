"""Finish native input and presentation QA in disposable author userdata (Linux)."""
from pathlib import Path
import argparse,json,os,subprocess,time,stat
from PIL import Image,ImageGrab

ROOT=Path(__file__).resolve().parents[2]

def main():
 parser=argparse.ArgumentParser()
 for key in ['godot','xvfb','xdotool','output']:parser.add_argument('--'+key,required=True)
 parser.add_argument('--display',default=':99');parser.add_argument('--phase',choices=['all','compare','menus','settings','library'],default='all');args=parser.parse_args()
 out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=True)
 for exe in [args.godot,args.xvfb,args.xdotool]:
  p=Path(exe)
  if not os.access(p,os.X_OK):p.chmod(p.stat().st_mode|stat.S_IXUSR)
 env=os.environ.copy();env['DISPLAY']='localhost'+args.display
 env['XDG_DATA_HOME']=str(out/'userdata/jade_paid_v2_qa_gui')
 env['JADE_UI_COMMAND_FILE']=str(out/'command.json');env['JADE_UI_CAPTURE_DIR']=str(out)
 (out/'command.json').write_text('{}')
 xlog=(out/'xvfb.log').open('w');x=subprocess.Popen([args.xvfb,args.display,'-screen','0','1100x1400x24','-listen','tcp','-ac'],env=env,stdout=xlog,stderr=xlog)
 game=None;captures=[];gestures=[];counter=0
 def native(*parts):
  p=subprocess.run([args.xdotool]+list(map(str,parts)),env=env,capture_output=True,text=True,timeout=20)
  if p.returncode:raise RuntimeError(p.stderr)
  return p.stdout
 def wait_for(token,timeout=70):
  deadline=time.monotonic()+timeout
  while time.monotonic()<deadline:
   log=(out/'runtime.log').read_text(errors='replace') if (out/'runtime.log').exists() else ''
   if 'SCRIPT ERROR:' in log or '\nERROR:' in log:raise RuntimeError(log[-3500:])
   if token in log:return
   if game is not None and game.poll() is not None:raise RuntimeError('Game exited '+str(game.returncode))
   time.sleep(.1)
  raise TimeoutError(token)
 def command(**data):
  nonlocal counter
  counter+=1;data['id']='final-'+str(counter)
  temp=out/'command.tmp';temp.write_text(json.dumps(data));temp.replace(out/'command.json')
  wait_for('UI_COMMAND_DONE '+data['id'])
  if 'capture' not in data:return {}
  name=data['capture'];path=out/(name+'.png');im=Image.open(path);im.load()
  info=json.loads(path.with_suffix('.json').read_text())
  size=tuple(int(v) for v in info['root_size'].strip('()').split(','))
  assert im.size==size,(name,im.size,size)
  captures.append({'name':name,'size':im.size,'bytes':path.stat().st_size})
  print('CAPTURE_PASS',name,flush=True);return info
 def drag(window,start,end):
  parts=['mousemove','--window',window,*start,'mousedown',1,'sleep',.05]
  for i in range(1,9):
   point=[round(start[j]+(end[j]-start[j])*i/8) for j in range(2)]
   parts+=['mousemove','--window',window,*point,'sleep',.035]
  native(*(parts+['mouseup',1]));time.sleep(.3)
 try:
  for _ in range(40):
   if subprocess.run([args.xdotool,'getdisplaygeometry'],env=env,capture_output=True).returncode==0:break
   time.sleep(.1)
  with (out/'runtime.log').open('w') as log:
   game=subprocess.Popen([args.godot,'--path',str(ROOT),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','res://tests/player_content_ui_probe.gd'],env=env,stdout=log,stderr=log)
  wait_for('PLAYER_CONTENT_UI_READY',100)
  window=native('search','--pid',game.pid,'--onlyvisible').splitlines()[0]
  native('windowmove',window,20,20,'windowfocus',window)
  if args.phase=='all':
   before=command(scene='court',language='id',width=360,height=640,setup=True,capture='native_swipe_before')
   control=next(c for c in before['controls'] if c['under_scroll'])
   x0,y0,w,h=control['physical'];start=[round(x0+w/2),round(y0+h/2)]
   drag(window,start,[start[0],start[1]-105])
   after=command(capture='native_swipe_after')
   assert after['scrolls'][0]['position']>before['scrolls'][0]['position']
   assert not after['option_popup_open'] and after['setup_open'] and not after['running'] and not after['joystick_input']
   assert after['art_index']==before['art_index'] and after['mode']==before['mode']
   ImageGrab.grab(xdisplay=env['DISPLAY']).save(out/'native_swipe_os.png')
   gestures.append({'test':'FIRST_REAL_OPTIONBUTTON_SWIPE','status':'PASS','before':before['scrolls'],'after':after['scrolls'],'accidental_action':False})
   native('key','Escape');time.sleep(.2)
   closed=command(capture='setup_back')
   assert not closed['setup_open'] and closed['scene']==after['scene']
   for choice,key,expected in [('boon','boon','none'),('art','arts',{'spirit_sword':'balanced'})]:
    command(scene='court',language='id',width=360,height=640,choice=choice,capture='native_'+choice+'_before')
    native('key','Escape');time.sleep(.2);state=command(capture='native_'+choice+'_back')
    assert not state['paused'] and state['scene']=='TrainingGround' and state['run_paths'][key]==expected
    gestures.append({'test':choice.upper()+'_NATIVE_BACK','status':'PASS'})
  if args.phase in ['all','compare']:
   command(scene='home',language='id',width=360,height=640);command(dismiss_guide=True)
   state=command(compare=True,capture='compare_native_before')
   for name,expected in [('CompareA',0),('CompareB',1)]:
    rect=next(c['physical'] for c in state['controls'] if c['name']==name)
    native('mousemove','--window',window,round(rect[0]+rect[2]/2),round(rect[1]+rect[3]/2),'click',1,'sleep',.2)
    popup_state=command(capture='native_'+name.lower()+'_popup')
    popup=next(p for p in popup_state['popups'] if p['owner']==name)
    scale=360/648 if popup['embedded'] else 1
    origin=[v*scale for v in popup['position']];size=[v*scale for v in popup['size']]
    if not popup['embedded']:origin=[v-20 for v in origin]
    native('mousemove','--window',window,round(origin[0]+size[0]/2),round(origin[1]+size[1]*(expected+.5)/popup['count']),'click',1)
    time.sleep(.2);state=command(capture='native_'+name.lower())
    assert state['compare_a' if name=='CompareA' else 'compare_b']==expected
    gestures.append({'test':name+'_NATIVE_SELECTION','status':'PASS','index':expected})
  for lang in ['en','id']:
   for width,height,tag in [(360,640,'compact'),(405,860,'tall')]:
    key=lang+'_'+tag
    if args.phase=='library':
     for mode in ['SKILLS','EQUIPMENT']:
      command(scene='builds',library_mode=mode,language=lang,width=width,height=height,capture=mode.lower()+'_'+key)
     command(scene='builds',library_mode='SKILLS',language=lang,width=width,height=height,scroll_bottom=True,capture='skills_bottom_'+key)
     command(scene='builds',library_mode='SKILLS',language=lang,width=width,height=height,skill_detail='yin_yang_blades',capture='skill_detail_'+key)
     command(scene='builds',language=lang,width=width,height=height,equipment_detail='void_piercer_spear',capture='equipment_detail_'+key)
     continue
    if args.phase=='settings':
     state=command(scene='settings',language=lang,width=width,height=height,scroll_to='quiet_player_vfx',capture='quiet_setting_'+key)
     if key=='en_compact':
      rect=next(c['physical'] for c in state['controls'] if c['name']=='quiet_player_vfx')
      assert 0<=rect[1] and rect[1]+rect[3]<=height,('setting outside capture',rect)
      native('mousemove','--window',window,round(rect[0]+rect[2]/2),round(rect[1]+rect[3]/2),'click',1);time.sleep(.2)
      toggled=command(capture='quiet_toggle_on');assert toggled['quiet_vfx']!=state['quiet_vfx']
      native('click',1);time.sleep(.2);restored=command(capture='quiet_toggle_restored');assert restored['quiet_vfx']==state['quiet_vfx']
      gestures.append({'test':'QUIET_VFX_NATIVE_TOGGLE_AND_RESTORE','status':'PASS'})
     continue
    for mode in ['BUILDS','EQUIPMENT','SKILLS','CHRONICLES']:
     command(scene='builds',library_mode=mode,language=lang,width=width,height=height,capture=mode.lower()+'_'+key)
    command(scene='builds',language=lang,width=width,height=height,scroll_bottom=True,capture='builds_bottom_'+key)
    command(scene='settings',language=lang,width=width,height=height,scroll_to='quiet_player_vfx',capture='quiet_setting_'+key)
    command(scene='daily',language=lang,width=width,height=height,capture='daily_'+key)
    command(scene='pavilion',language=lang,width=width,height=height,unlocked=True);command(dismiss_guide=True,capture='pavilion_'+key)
    command(scene='home',language=lang,width=width,height=height,force_guide=True,capture='home_guide_'+key)
    command(dismiss_guide=True,journal_page='drills',capture='technique_records_'+key)
  result={'status':'PASS','scope':'NATIVE_X11_MESA_EMULATED_TOUCH_NOT_ANDROID','phase':args.phase,'captures':captures,'gestures':gestures,'reused':'Prior 82-render matrix and 251 runtime checks retained separately; not rerun here.'}
  (out/'GUI_RESULT.json').write_text(json.dumps(result,indent=2))
  print('AUTHOR_GUI_PASS captures='+str(len(captures)),flush=True)
  (out/'command.json').write_text(json.dumps({'id':'quit','quit':True}));game.wait(timeout=15)
 finally:
  if game is not None and game.poll() is None:game.terminate();game.wait(timeout=10)
  x.terminate();x.wait(timeout=10)
if __name__=='__main__':main()
