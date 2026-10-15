"""Original playful horror music and effects; generated locally, no recordings."""
from pathlib import Path
import math,subprocess,wave
import numpy as np

OUT=Path(__file__).resolve().parents[1]/'assets/audio'
OUT.mkdir(parents=True,exist_ok=True)
RATE=22050
rng=np.random.default_rng(1483)

def note(midi,duration,volume=.25,voice='bell'):
    t=np.arange(round(duration*RATE))/RATE
    f=440*2**((midi-69)/12)
    if voice=='bell':signal=np.sin(2*np.pi*f*t)+.28*np.sin(2*np.pi*f*2*t)+.08*np.sin(2*np.pi*f*3*t)
    elif voice=='bass':signal=np.sin(2*np.pi*f*t)+.18*np.sin(2*np.pi*f*2*t)
    else:signal=np.sin(2*np.pi*f*t)*np.sin(np.minimum(t/.03,1)*np.pi/2)
    env=np.minimum(t/.012,1)*np.exp(-t*(6 if voice=='bell' else 2.5))
    env*=np.minimum(np.maximum(duration-t,0)/.035,1)
    return signal*env*volume

def store(name,samples,loop=False):
    samples=np.asarray(samples,dtype=float)
    peak=max(.95,float(np.abs(samples).max()))
    data=np.clip(samples/peak,-1,1)
    wav=OUT/(name+'.wav')
    with wave.open(str(wav),'wb') as stream:
        stream.setnchannels(1);stream.setsampwidth(2);stream.setframerate(RATE)
        stream.writeframes((data*32767).astype('<i2').tobytes())
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','4',str(OUT/(name+'.ogg'))],check=True)
    wav.unlink()

def music(name,bpm):
    beat=60/bpm;length=beat*64
    signal=np.zeros(round(length*RATE))
    melody=[72,75,79,78,75,72,70,67,72,75,79,82,79,75,74,70]
    roots=[48,44,46,43]
    for step in range(128):
        pos=round(step*beat*.5*RATE)
        tone=note(melody[(step//2+step//32)%len(melody)]+(12 if step%8==6 else 0),beat*.45,.17 if step%2==0 else .07)
        signal[pos:pos+len(tone)]+=tone[:len(signal)-pos]
    for step in range(64):
        pos=round(step*beat*RATE)
        bass=note(roots[(step//8)%4],beat*.8,.19,'bass')
        signal[pos:pos+len(bass)]+=bass[:len(signal)-pos]
        t=np.arange(round(.14*RATE))/RATE
        kick=np.sin(2*np.pi*(75*t-130*t*t))*np.exp(-t*35)*.16
        signal[pos:pos+len(kick)]+=kick[:len(signal)-pos]
        if step%2:
            noise=rng.normal(0,1,round(.10*RATE))*np.exp(-np.arange(round(.10*RATE))/RATE*55)*.065
            signal[pos:pos+len(noise)]+=noise[:len(signal)-pos]
    delay=round(beat*.75*RATE)
    signal[delay:]+=signal[:-delay]*.12
    fade=round(.025*RATE)
    signal[:fade]*=np.linspace(0,1,fade);signal[-fade:]*=np.linspace(1,0,fade)
    store(name,signal,True)

music('moon_menu',104);music('midnight_run',128)
for name,duration,start,end in [('jump',.22,280,850),('recruit',.28,150,550),('hit',.22,160,45),('land',.11,110,60),('smash',.25,130,40)]:
    t=np.arange(round(duration*RATE))/RATE
    phase=2*np.pi*(start*t+(end-start)*t*t/(2*duration))
    signal=(np.sin(phase)+.15*np.sin(phase*2))*np.sin(np.pi*t/duration)**1.2*.35
    if name in ('hit','smash','land'):signal+=rng.normal(0,.08,len(t))*np.exp(-t*28)
    store(name,signal)
for name,notes in [('coin',[84,91]),('buy',[72,79,84]),('perk',[60,67,75,84]),('guard',[79,84,91]),('finish',[67,63,60]),('challenge',[72,76,79,84])]:
    duration=.13 if name=='coin' else .16
    sound=np.concatenate([note(n,duration,.28) for n in notes])
    store(name,sound)
print('ORIGINAL_AUDIO_OK: two music loops and eleven effects')
