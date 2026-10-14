"""Original threat synthesis and licensed creature clips, reproducible offline."""
from pathlib import Path
import io,json,subprocess,wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio'
SOURCES=Path('/workspace/scratch/135a4bd386fb/horde-audio-sources')
RATE=44100
rng=np.random.default_rng(1313)

def read(path):
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','1','-ar',str(RATE),'-'])
    return np.frombuffer(raw,dtype=np.float32).astype(np.float64)

def save(name,x):
    x=np.asarray(x,dtype=np.float64)
    peak=max(.001,float(np.abs(x).max()))
    x=x/peak*.70
    edge=min(441,int(len(x)/8))
    x[:edge]*=np.linspace(0,1,edge);x[-edge:]*=np.linspace(1,0,edge)
    stream=io.BytesIO()
    with wave.open(stream,'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes((np.clip(x,-1,1)*32767).astype('<i2').tobytes())
    subprocess.run(['ffmpeg','-v','error','-y','-i','pipe:0','-c:a','libvorbis','-q:a','4',str(OUT/(name+'.ogg'))],input=stream.getvalue(),check=True)

z=SOURCES/'zombies/zombies'
save('voice_zombie',read(z/'zombie-1.wav'))
save('voice_zombie_alt',read(z/'zombie-5.wav'))
save('death_zombie',read(z/'zombie-13.wav')[:RATE])
bone=SOURCES/'bones_rattle'
rattle=np.concatenate([read(bone/'0.ogg'),np.zeros(1200),read(bone/'2.ogg'),np.zeros(900),read(bone/'4.ogg')])
save('voice_skeleton',rattle)
save('death_skeleton',np.concatenate([rattle,read(bone/'6.ogg')]))
speech=read(SOURCES/'masked-voice.wav')
envelope=np.sqrt(np.convolve(speech*speech,np.ones(256)/256,'same')+1e-8)
whisper=rng.normal(0,1,len(speech))
whisper=np.convolve(whisper,[1,-.8],mode='same')*envelope
masked=speech*.30+whisper*.70
echo=np.zeros(len(masked)+11025);echo[:len(masked)]+=masked;echo[4500:4500+len(masked)]+=masked*.22
save('voice_masked',echo)
breath=read(SOURCES/'ghostbreath.flac')
save('death_masked',breath[:int(RATE*.9)])
save('city_scream',read(SOURCES/'high_pitch_scream.mp3')[:int(RATE*1.5)])
t=np.arange(int(RATE*.65))/RATE
buzz=(np.sin(2*np.pi*140*t)+.3*np.sin(2*np.pi*280*t))*(.55+.45*np.sin(2*np.pi*33*t))
save('voice_fly',buzz*np.sin(np.pi*t/.65)**.4)
save('death_fly',buzz*np.exp(-t*6)+rng.normal(0,.06,len(t))*np.exp(-t*8))
t=np.arange(int(RATE*.16))/RATE
save('gunshot',rng.normal(0,1,len(t))*np.exp(-t*35)+np.sin(2*np.pi*80*t)*np.exp(-t*30))
t=np.arange(int(RATE*.7))/RATE
save('explosion',np.convolve(rng.normal(0,1,len(t)),np.ones(12)/12,'same')*np.exp(-t*7)+np.sin(2*np.pi*(60*t-20*t*t))*np.exp(-t*5))
t=np.arange(int(RATE*.55))/RATE
save('tunnel',np.sin(2*np.pi*(210*t-100*t*t))*(1-t/.55)**2)
t=np.arange(RATE*8)/RATE
wind=np.convolve(rng.normal(0,1,len(t)),np.ones(120)/120,'same')*.3
sirens=np.sin(2*np.pi*np.cumsum(370+120*np.sin(t*2.1))/RATE)*.08*(.5+.5*np.sin(t*.5))
rotor=(np.sin(2*np.pi*85*t)+np.sin(2*np.pi*170*t)*.2)*(.5+.5*np.sin(t*2*np.pi*14))*.10
save('city_ambience',wind+sirens+rotor)

credits={
 'zombie':{'page':'https://opengameart.org/content/zombies-sound-pack','author':'artisticdude','license':'CC0','files':['zombie-1.wav','zombie-5.wav','zombie-13.wav']},
 'skeleton':{'page':'https://opengameart.org/content/bones-rattle','author':'congusbongus; adapted from blukotek','license':'CC0','files':['0.ogg','2.ogg','4.ogg','6.ogg']},
 'scream':{'page':'https://opengameart.org/content/high-pitch-scream-sounds2','author':'pauliuw','license':'CC0','files':['high_pitch_scream.mp3']},
 'breath':{'page':'https://opengameart.org/content/ghost-breath','author':'qubodup','license':'CC0','files':['ghostbreath.flac']},
 'original':'Masked ki-ki-ma-ma cue synthesized with FFmpeg/libflite then converted to a whispered effect; fly, gunshot, explosion, tunnel and city ambience synthesized for this project. No Minecraft or film audio was extracted.'
}
(OUT/'SOURCES-v3.json').write_text(json.dumps(credits,indent=2)+'\n')
print('THREAT_AUDIO_OK: licensed groans/bones/scream/breath and original threat cues')
