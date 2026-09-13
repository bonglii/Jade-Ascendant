#!/usr/bin/env python3
"""Compose Jade Ascendant's original synthesized score and effects.

Requires numpy/scipy and ffmpeg only for rebuilding; the game uses bundled Ogg
and WAV files. No samples, recordings, online services, or third-party songs.
"""
from pathlib import Path
import json
import subprocess
import tempfile
import wave
import numpy as np
from scipy.signal import lfilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio"
RATE = 24000
RNG = np.random.default_rng(20260908)
MANIFEST = []

def tone(midi, seconds, voice="pluck"):
    t = np.arange(int(seconds * RATE)) / RATE
    freq = 440 * 2 ** ((midi - 69) / 12)
    if voice == "flute":
        phase = 2 * np.pi * freq * t + 0.12 * np.sin(2 * np.pi * 5 * t)
        y = np.sin(phase) + 0.10 * np.sin(phase * 2) + 0.035 * np.sin(phase * 3)
        env = np.minimum(t / .13, 1) * np.minimum((seconds-t)/.25, 1)
        return y * np.clip(env, 0, 1) * .22
    y = sum(np.sin(2*np.pi*freq*k*t + k*.08) * np.exp(-t*(1.5+k*.7)) / k**1.45 for k in range(1, 9))
    return y * np.minimum(t/.005, 1) * np.minimum((seconds-t)/.04, 1) * .4

def drum(seconds=.5, high=False):
    t = np.arange(int(seconds * RATE)) / RATE
    if high:
        return lfilter([1,-.88], [1], RNG.normal(0, .12, len(t))) * np.exp(-t*38)
    phase = 2*np.pi*(52*t + 13*(1-np.exp(-t*20))/20)
    return np.sin(phase)*np.exp(-t*10)*.42 + RNG.normal(0,.02,len(t))*np.exp(-t*45)

def add_circular(track, sound, at, gain=1, pan=0):
    positions = (np.arange(len(sound)) + round(at*RATE)) % len(track)
    np.add.at(track[:,0], positions, sound*gain*np.sqrt((1-pan)/2))
    np.add.at(track[:,1], positions, sound*gain*np.sqrt((1+pan)/2))

def save(name, samples, music=False):
    OUT.mkdir(parents=True, exist_ok=True)
    samples = np.asarray(samples)
    peak = float(np.max(np.abs(samples)))
    samples = samples / max(peak, .01) * (.58 if music else .63)
    pcm = np.round(samples*32767).astype('<i2')
    target = OUT / (name + (".ogg" if music else ".wav"))
    with tempfile.TemporaryDirectory() as tmp:
        raw = Path(tmp) / "mix.wav"
        with wave.open(str(raw), 'wb') as stream:
            stream.setnchannels(2 if samples.ndim == 2 else 1)
            stream.setsampwidth(2)
            stream.setframerate(RATE)
            stream.writeframes(pcm.tobytes())
        if music:
            subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(raw),'-c:a','libvorbis','-q:a','5',str(target)], check=True)
        else:
            target.write_bytes(raw.read_bytes())
    MANIFEST.append({'file': target.relative_to(ROOT).as_posix(), 'seconds': len(samples)/RATE,
                     'channels': 2 if samples.ndim == 2 else 1, 'peak_dbfs': float(20*np.log10(np.max(np.abs(samples)))),
                     'origin': 'Original deterministic synthesis', 'loop': music})

def score(name, mode):
    length = 64
    track = np.zeros((length*RATE, 2), dtype=np.float64)
    pentatonic = [62,64,67,69,71,74,76,79]
    phrases = [[0,2,3,2,1,0,2,4], [3,4,5,4,2,3,1,0], [2,3,4,6,5,4,3,2], [3,2,1,0,2,1,0,0]]
    step = .5 if mode == 2 else 1.0
    for bar in range(16):
        phrase = phrases[(bar//2) % 4]
        root = [50,55,57,52][bar//4]
        add_circular(track, tone(root,3.8), bar*4, .38, -.18)
        add_circular(track, tone(root+7,3.5), bar*4+.7, .22, .35)
        for beat in range(int(4/step)):
            note = pentatonic[phrase[(bar*4+beat)%8]] + (0 if mode != 2 else -12)
            if mode == 0 and beat % 4 == 3:
                continue
            add_circular(track, tone(note, 2.5), bar*4+beat*step, .48 if mode == 0 else .38, (-.45 if beat%2 else .4))
        if bar % 4 in [1,2]:
            for index in range(2):
                note = pentatonic[phrase[(bar+index*3)%8]]
                add_circular(track, tone(note,1.7,'flute'),bar*4+.25+index*2,.48,-.05)
        if mode > 0:
            for beat in range(4):
                add_circular(track, drum(), bar*4+beat, .38 if mode == 1 else .75)
                if mode == 2 or beat%2 == 0:
                    add_circular(track, drum(.14,True),bar*4+beat+.5,.32,.2)
    # Circular early reflections preserve reverb across the loop boundary.
    dry = track.copy()
    for delay, gain in [(.137,.14),(.293,.11),(.487,.07),(.751,.04)]:
        track += np.roll(dry, round(delay*RATE), axis=0)[:,::-1] * gain
    save(name, track, True)

def effects():
    for name, midi, duration in [('ui',86,.09),('pickup',91,.16),('shield',79,.35),('claim',81,.4),('equip',74,.24)]:
        save(name,tone(midi,duration))
    for name, freq, seconds in [('sword',820,.16),('fire',340,.3),('thunder',150,.26),('chain',580,.11),('hit',240,.10),('hurt',120,.24),('death',430,.32)]:
        t=np.arange(round(seconds*RATE))/RATE
        noise=lfilter([.2,.25,.3,.25], [1], RNG.normal(0,.6,len(t)))
        y=(noise*.4+np.sin(2*np.pi*freq*t*np.exp(-t*3))*.26)*np.sin(np.pi*t/seconds)**2*np.exp(-t*4)
        save(name,y)
    for name, notes in [('level',[62,67,71,74]),('victory',[62,67,69,74,79]),('defeat',[67,64,62,50]),('boss_defeat',[50,57,62,69,74])]:
        track=np.zeros((int(2.8*RATE),2))
        for index, note in enumerate(notes):
            # Tail reaches silence, no circular wrap for stingers.
            sound=tone(note,1.5)
            at=round(index*.22*RATE)
            track[at:at+len(sound),:]+=sound[:,None]*.36
        save(name,track)

if __name__ == '__main__':
    for name, mode in [('celestial_gate',0),('verdant_journey',1),('sovereign_ritual',2)]:
        score(name,mode)
    effects()
    (OUT/'audio_manifest.json').write_text(json.dumps(MANIFEST,indent=2)+'\n')
    print(f'Generated {len(MANIFEST)} original audio assets in {OUT}')
