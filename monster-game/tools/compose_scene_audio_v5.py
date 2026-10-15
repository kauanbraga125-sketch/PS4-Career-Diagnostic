"""Licensed CC0 sources plus original foley, synthetic commands and metamorphosis."""
from pathlib import Path
import numpy as np,subprocess,json,hashlib,os
from scipy.signal import butter,sosfilt,resample_poly
PROJECT=Path(__file__).resolve().parents[1]
OUT=PROJECT/'assets/audio';SR=44100
SRC=Path(os.environ.get('HORDE_V5_AUDIO_SOURCE',str(PROJECT.parents[1]/'horde-audio-sources/v5')))
rng=np.random.default_rng(5014)
def read(p):
    return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ar',str(SR),'-ac','1','-f','f32le','pipe:1']),dtype='<f4').copy()
def save(n,a,loop=False):
    a=np.asarray(a,dtype=np.float32);a=np.nan_to_num(a);a*=.68/max(.001,float(np.max(np.abs(a))))
    fade=min(len(a)//8,int(SR*.014));a[:fade]*=np.linspace(0,1,fade);a[-fade:]*=np.linspace(1,0,fade)
    subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(SR),'-ac','1','-i','pipe:0','-c:a','libvorbis','-q:a','4',str(OUT/(n+'.ogg'))],input=a.tobytes(),check=True)
def filter(a,cut,mode='lowpass'):
    return sosfilt(butter(3,cut,mode,fs=SR,output='sos'),a)
def put(dst,part,at,gain=1):
    start=int(at*SR);n=min(len(part),len(dst)-start)
    if n>0:dst[start:start+n]+=part[:n]*gain
def stretch(a,factor):
    return np.interp(np.linspace(0,len(a)-1,int(len(a)*factor)),np.arange(len(a)),a)
crash=read(SRC/'crash.ogg')
for index,(name,length,pitch,hits) in enumerate([('moto',.95,.78,4),('car',1.25,1.0,6),('bus',1.65,1.4,9),('truck',1.8,1.55,5),('tank',1.7,1.8,7),('plane',2.0,1.1,10)]):
    t=np.arange(int(SR*length))/SR;a=np.zeros(len(t));base=stretch(crash,pitch)
    put(a,base,0,.9)
    for i in range(hits):
        at=.075+i*.045+float(rng.uniform(0,.025));n=int(SR*.25);u=np.arange(n)/SR
        freq=(930 if name in ['moto','plane'] else 390)+i*173
        glass=np.sin(2*np.pi*freq*u)*np.exp(-u*(24 if name!='tank' else 12))
        put(a,glass,at,.13)
    a+=np.sin(2*np.pi*(38 if name in ['bus','truck','tank'] else 78)*t)*np.exp(-t*5)*.28
    noise=filter(rng.normal(0,1,len(t)),1900 if name!='tank' else 900)*np.exp(-t*5)*.24
    a+=noise
    if name=='plane':a+=np.sin(2*np.pi*(190*t-35*t*t))*(1+np.sin(2*np.pi*17*t))*.13*np.exp(-t*2)
    save('smash_'+name,a)
save('metal_push',filter(crash[:int(SR*.2)],2500)*.6)
t=np.arange(int(SR*.34))/SR;save('glass_break',filter(rng.normal(0,1,len(t)),1500,'highpass')*np.exp(-t*16)+np.sin(2*np.pi*2700*t)*np.exp(-t*11)*.4)
save('civil_male',read(SRC/'male/aargh3.ogg'))
save('civil_worker',stretch(read(SRC/'male/aargh5.ogg'),1.14))
save('civil_female',read(SRC/'female/2.ogg'))
def speech(text,voice):
    return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-f','lavfi','-i',f"flite=text='{text}':voice={voice}",'-ar',str(SR),'-ac','1','-f','f32le','pipe:1']),dtype='<f4').copy()
save('police_stop',filter(speech('Stop! Stop! Police!','kal16'),[220,3800],'bandpass'))
army=filter(speech('Contact! Move! Hold the line!','rms'),[420,2400],'bandpass');army+=rng.normal(0,.018,len(army));save('army_command',army)
heli=read(SRC/'helicopter.ogg');window=int(SR*3.8)
energies=[np.mean(heli[i:i+window]**2) for i in range(0,max(1,len(heli)-window),int(SR*.5))]
start=int(np.argmax(energies))*int(SR*.5);heli=heli[start:start+window]
fade=int(SR*.08);heli[:fade]=heli[:fade]*np.linspace(0,1,fade)+heli[-fade:]*np.linspace(1,0,fade)
save('helicopter_loop',heli)
save('plane_loop',read(SRC/'propeller.ogg'))
t=np.arange(int(SR*2))/SR;rumble=filter(rng.normal(0,1,len(t)),460)
save('engine_loop',(np.sin(2*np.pi*61*t)+.4*np.sin(2*np.pi*122*t))*(.65+.35*np.sin(2*np.pi*17*t))+rumble*.5)
save('fire_loop',filter(rng.normal(0,1,len(t)),[350,2600],'bandpass')*(.65+.35*np.sin(2*np.pi*7*t))+np.sin(2*np.pi*93*t)*.08)
for kind in ['fly','mask']:
    t=np.arange(int(SR*2.8))/SR;freq=110+np.clip(t/2.5,0,1)*(260 if kind=='fly' else 100)
    a=np.sin(2*np.pi*np.cumsum(freq)/SR)*.25+filter(rng.normal(0,1,len(t)),900)*.2
    a*=np.sin(np.minimum(t/2.8,1)*np.pi)**.55
    if kind=='fly':a+=np.sin(2*np.pi*145*t)*(1+np.sin(2*np.pi*39*t))*.10
    for i,f in enumerate([262,311,392,523]):
        at=1.5+i*.24;u=np.arange(int(SR*.6))/SR;put(a,np.sin(2*np.pi*f*u)*np.exp(-u*6),at,.5)
    save('transform_'+kind,a)
t=np.arange(int(SR*1.3))/SR;save('revive',np.sin(2*np.pi*(145*t+210*t*t))*np.sin(t/1.3*np.pi)+filter(rng.normal(0,1,len(t)),1100)*np.exp(-t*3)*.2)
metadata={'license':'CC0 for imported samples; original synthesis for added foley and flite commands','sources':[
{'files':['smash_moto','smash_car','smash_bus','smash_truck','smash_tank','smash_plane','metal_push'],'author':'qubodup','title':'Crash Collision','page':'https://opengameart.org/content/crash-collision','source':'https://opengameart.org/sites/default/files/qubodup-crash.ogg','license':'CC0','changes':'pitch/time layers, filtered foley, original tones and glass'} ,
{'files':['helicopter_loop'],'author':'WuxiaScrub','title':'Helicopter SFX','page':'https://opengameart.org/content/helicopter-sfx','source':'https://opengameart.org/sites/default/files/heli_0.ogg','license':'CC0','changes':'3.8-second loudest passage, loop crossfade and normalization'},
{'files':['plane_loop'],'author':'Mish7913','title':'Propeller (Cartoon) Loop','page':'https://opengameart.org/content/propeller-cartoon-loop','source':'https://opengameart.org/sites/default/files/propeller_cartoon_loop_0.ogg','license':'CC0','changes':'mono conversion and normalization'},
{'files':['civil_male','civil_worker'],'author':'JohnsonBrandEditing; adaptation by congusbongus','title':'human male scream multi, aargh3/aargh5 only','page':'https://opengameart.org/content/aargh-male-screams','original':'https://freesound.org/people/JohnsonBrandEditing/sounds/173944/','license':'CC0','changes':'mono, normalization; worker slowed'},
{'files':['civil_female'],'author':'tcrocker68; adaptation by congusbongus','title':'Girl_Scream.wav, female/2.ogg only','page':'https://opengameart.org/content/female-screams','original':'https://www.freesound.org/people/tcrocker68/sounds/235592/','license':'CC0','changes':'mono and normalization'}], 'original':['police_stop','army_command','glass_break','engine_loop','fire_loop','transform_fly','transform_mask','revive']}
for source in ['crash.ogg','helicopter.ogg','propeller.ogg','male.zip','female.zip']:metadata.setdefault('source_sha256',{})[source]=hashlib.sha256((SRC/source).read_bytes()).hexdigest()
(OUT/'SOURCES-v5.json').write_text(json.dumps(metadata,indent=2)+'\n')
(OUT/'NPC-LICENSES-v5.txt').write_text('Noite da Horda alpha 0.5: only male aargh3.ogg / aargh5.ogg (JohnsonBrandEditing) and female 2.ogg (tcrocker68) are used, all CC0. Other entries below are the original mixed-package documentation; those recordings are not included. See SOURCES-v5.json for changes and exact source hashes.\n\n'+(SRC/'male/aargh.txt').read_text()+'\n'+(SRC/'female/license.txt').read_text())
print('SCENE_AUDIO_V5_OK: 6 distinct vehicle crashes, rotor/engine/fire loops, licensed NPC cries, synthetic police/military commands, transformation and revive')
