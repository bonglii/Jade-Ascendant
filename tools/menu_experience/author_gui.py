"""Finish native input and presentation QA in disposable author userdata (Linux)."""
from pathlib import Path
import argparse,json,os,subprocess,time,stat,tempfile
from PIL import Image,ImageGrab

ROOT=Path(__file__).resolve().parents[2]

def main():
 parser=argparse.ArgumentParser()
 for key in ['godot','xvfb','xdotool','output']:parser.add_argument('--'+key,required=True)
 parser.add_argument('--display',default=':99');parser.add_argument('--phase',choices=['baseline','final','guides','gestures','focused','pilot','combat'],default='final');args=parser.parse_args()
 out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=True)
 for exe in [args.godot,args.xvfb,args.xdotool]:
  p=Path(exe)
  if not os.access(p,os.X_OK):p.chmod(p.stat().st_mode|stat.S_IXUSR)
 env=os.environ.copy();env['DISPLAY']='localhost'+args.display
 env['XDG_DATA_HOME']=str(out/'userdata/jade_paid_v2_qa_gui')
 command_path=Path(tempfile.mkdtemp(prefix='jade_gui_commands_'))/'command.json'
 env['JADE_UI_COMMAND_FILE']=str(command_path);env['JADE_UI_CAPTURE_DIR']=str(out)
 command_path.write_text('{}')
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
  temp=command_path.with_suffix('.tmp');temp.write_text(json.dumps(data));temp.replace(command_path)
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
   game=subprocess.Popen([args.godot,'--path',str(ROOT),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--verbose','--script','res://tests/menu_experience_ui_probe.gd'],env=env,stdout=log,stderr=log)
  wait_for('PLAYER_CONTENT_UI_READY',100)
  window=native('search','--pid',game.pid,'--onlyvisible').splitlines()[0]
  native('windowmove',window,20,20,'windowfocus',window)
  scenes=['cultivate','hero','events','settings'] if args.phase=='baseline' else ['home','cultivate','hero','daily','achievements','pavilion','builds','events','trials','court','settings','mail','odyssey','treasury','realm']
  if args.phase in ['baseline','final']:
   for lang in ['en','id']:
    for width,height,tag in ([(360,640,'compact')] if args.phase=='baseline' else [(360,640,'compact'),(405,860,'tall')]):
     for scene in scenes:
      command(scene=scene,language=lang,width=width,height=height,unlocked=True)
      command(dismiss_guide=True,capture=scene+'_'+lang+'_'+tag)
  if args.phase in ['guides','gestures']:
   for lang in (['id'] if args.phase=='gestures' else ['en','id']):
    for width,height,tag in ([(360,640,'compact')] if args.phase=='gestures' else [(360,640,'compact'),(405,860,'tall')]):
     for key in ['events','pavilion','cultivate','settings','weekly','odyssey','purchase','timeline','preset','library']:
      command(scene='trials' if key=='weekly' else 'hero',language=lang,width=width,height=height,unlocked=True,seed_gear=True)
      command(dismiss_guide=True)
      state=command(guide=key,capture='guide_'+key+'_'+lang+'_'+tag)
      if args.phase=='gestures':
       candidates=[c for c in state['controls'] if c['under_scroll'] and c.get('scroll_name')=='ExperienceScroll' and c['physical'][1]>80 and c['physical'][1]+c['physical'][3]<height-40 and c['physical'][3]>20]
       scroll=next((s for s in state['scrolls'] if s['name']=='ExperienceScroll'),None)
       if candidates and scroll and scroll['maximum']>scroll['page']+5:
        c=candidates[0];rect_x,rect_y,rect_w,rect_h=c['physical'];start=[round(rect_x+rect_w/2),round(rect_y+rect_h/2)]
        if start[1]<height*.5:start[1]=round(min(rect_y+rect_h-6,height*.7))
        drag(window,start,[start[0],max(70,start[1]-110)])
        after=command(capture='swipe_'+key)
        moved=next(s for s in after['scrolls'] if s['name']=='ExperienceScroll')['position']
        assert moved>scroll['position'],(key,'no native scroll')
        assert after['scene']==state['scene'] and not after['option_popup_open']
        gestures.append({'test':key+'_FIRST_NATIVE_CARD_SWIPE','status':'PASS','before':scroll['position'],'after':moved})
       native('key','Escape');time.sleep(.1)
       closed=command(capture='back_'+key)
       assert not any(s['name']=='ExperienceScroll' for s in closed['scrolls']),key+' back did not close'
       gestures.append({'test':key+'_NATIVE_ESCAPE','status':'PASS'})
      else:command(close_guide=True)
  if args.phase=='focused':
   for lang in ['en','id']:
    for width,height,tag in [(360,640,'compact'),(405,860,'tall')]:
     for scene in ['home','hero','cultivate','events']:
      command(scene=scene,language=lang,width=width,height=height,unlocked=True)
      command(dismiss_guide=True,seed_target=scene=='home',insets=True,capture='focus_'+scene+'_'+lang+'_'+tag)
      if scene=='cultivate':command(scroll_bottom=True,capture='focus_cultivate_bottom_'+lang+'_'+tag)
     for popup in ['celestial_boss_hunt','jade_valley_pilgrimage','heavenly_ladder','celestial_treasure_hunt','path_of_five_elements','new_player_event','meditation','mailbox','celestial_treasury']:
      command(scene='home',language=lang,width=width,height=height,unlocked=True);command(dismiss_guide=True)
      command(popup=popup,insets=True,capture='popup_'+popup+'_'+lang+'_'+tag)
     command(scene='trials',language=lang,width=width,height=height,unlocked=True);command(dismiss_guide=True)
     command(scroll_bottom=True,capture='weekly_reward_'+lang+'_'+tag)
   for mode in [7,8]:
    command(scene='court',language='id',width=360,height=640,unlocked=True,training_mode=mode)
    command(setup=True,capture='training_setup_'+str(mode))
    command(start=True,contrast=True,capture='training_running_'+str(mode))
   command(scene='realm',language='id',width=360,height=640,dismiss_guide=True,capture='navigation_realm')
  if args.phase=='pilot':
   for lang in ['en','id']:
    for width,height,tag in [(360,640,'compact'),(405,860,'tall')]:
     for popup in ['new_player_event','meditation']:
      command(scene='home',language=lang,width=width,height=height,unlocked=True);command(dismiss_guide=True)
      state=command(popup=popup,insets=True,capture='return_'+popup+'_'+lang+'_'+tag)
      assert len(state['controls'])>3,(popup,'popup not visible')
   state=command(scene='home',language='id',width=360,height=640);command(dismiss_guide=True)
   state=command(capture='pilot_home')
   def click_control(info,predicate):
    c=next(c for c in info['controls'] if predicate(c))
    left,top,w,h=c['physical'];native('mousemove','--window',window,round(left+w/2),round(top+h/2),'mousedown',1,'sleep',.12,'mouseup',1);time.sleep(1.8)
   click_control(state,lambda c:c['name']=='SanctuaryJourney')
   state=command(capture='pilot_chapters')
   print('PILOT_CHAPTER_CONTROLS',[(c['name'],c['text']) for c in state['controls'] if c['text']],flush=True)
  if args.phase=='combat':
   state=command(scene='home',language='id',width=360,height=640);command(dismiss_guide=True)
   def click_control(info,predicate):
    c=next(c for c in info['controls'] if predicate(c))
    left,top,w,h=c['physical'];native('mousemove','--window',window,round(left+w/2),round(top+h/2),'mousedown',1,'sleep',.12,'mouseup',1);time.sleep(1.8)
   state=command(capture='session_home');click_control(state,lambda c:c['name']=='SanctuaryJourney')
   state=command(capture='session_chapters')
   if state['scene']=='MainMenu':
    click_control(state,lambda c:c['name']=='SanctuaryJourney');state=command(capture='session_chapters_retry')
   click_control(state,lambda c:'ENTER REALM' in c['text'] or 'MASUK REALM' in c['text'])
   state=command(capture='session_stages')
   click_control(state,lambda c:c['text']=='BEGIN TRIAL')
   state=command(capture='session_combat_start')
   assert state['scene_path'].startswith('res://scenes/game/') or state['combat'],state['scene_path']
   if state['paused']:
    time.sleep(.7);state=command(capture='session_onboarding')
    click_control(state,lambda c:c['name']=='TutorialSkipButton')
    state=command(capture='session_after_visible_skip');assert not state['paused']
   native('keydown','Right');time.sleep(1.4);native('keyup','Right');native('keydown','Down');time.sleep(1.4);native('keyup','Down')
   time.sleep(4)
   after=command(capture='session_combat_moving')
   assert state['combat']['position']!=after['combat']['position'],'native movement failed'
   gestures.append({'test':'NATIVE_HOME_REALM_STAGE_COMBAT_MOVEMENT','status':'PASS','combat_before':state['combat'],'combat_after':after['combat']})
   for mode in [7,8]:
    command(scene='court',language='id',width=360,height=640,unlocked=True,training_mode=mode)
    command(setup=True,capture='training_setup_'+str(mode))
    state=command(start=True,contrast=True,capture='training_running_'+str(mode))
    time.sleep(2);after=command(capture='training_live_'+str(mode));assert after['running']
   command(scene='hero',language='id',width=360,height=640);command(dismiss_guide=True)
   state=command(guide='preset',seed_gear=True,capture='preset_native_card')
   scroll=next(s for s in state['scrolls'] if s['name']=='ExperienceScroll')
   c=next(c for c in state['controls'] if c.get('scroll_name')=='ExperienceScroll' and c['physical'][1]>100 and c['physical'][1]<360 and c['physical'][3]>40)
   left,top,w,h=c['physical'];drag(window,[round(left+w/2),round(top+min(h-8,90))],[round(left+w/2),round(top+min(h-8,90)-100)])
   after=command(capture='preset_native_swipe');assert next(s for s in after['scrolls'] if s['name']=='ExperienceScroll')['position']>scroll['position']
   assert after['scene']==state['scene'];gestures.append({'test':'PRESET_FIRST_NATIVE_CARD_SWIPE','status':'PASS'})

  counter+=1;command_path.write_text(json.dumps({'id':'quit-'+str(counter),'quit':True}));game.wait(timeout=20)
  log=(out/'runtime.log').read_text(errors='replace')
  assert 'SCRIPT ERROR:' not in log and '\nERROR:' not in log
  (out/'RESULT.json').write_text(json.dumps({'scope':'NATIVE_X11_LINUX_NOT_PHONE','captures':captures,'gestures':gestures,'failures':0},indent=2))
  print('EXPERIENCE_GUI_PASS captures='+str(len(captures))+' gestures='+str(len(gestures)),flush=True)

 finally:
  if game is not None and game.poll() is None:game.terminate();game.wait(timeout=10)
  x.terminate();x.wait(timeout=10)
if __name__=='__main__':main()
