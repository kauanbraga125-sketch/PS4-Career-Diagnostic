"""Normalize licensed masked whisper; compose original soul/ritual reward cues."""
from pathlib import Path
import os,subprocess,json,hashlib
import numpy as np
PROJECT=Path(__file__).resolve().parents[1]
OUT=PROJECT/'assets/audio'
SOURCE=Path(os.environ.get('HORDE_AUDIO_SOURCE',str(PROJECT.parents[1]/'horde-audio-sources')))
SR=44100
rng=np.random.default_rng(4014)
def save(name,a):
    a=np.asarray(a,dtype=np.float32)
    peak=np.max(np.abs(a));a=a/max(peak,.001)*.7
    fade=min(int(SR*.015),len(a)//4)
    a[:fade]*=np.linspace(0,1,fade);a[-fade:]*=np.linspace(1,0,fade)
    subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(SR),'-ac','1','-i','pipe:0','-c:a','libvorbis','-q:a','4',str(OUT/(name+'.ogg'))],input=a.tobytes(),check=True)
def chime(notes,length):
    a=np.zeros(round(SR*length))
    for i,(frequency,at) in enumerate(notes):
        start=round(at*SR);t=np.arange(len(a)-start)/SR
        a[start:]+=(np.sin(2*np.pi*frequency*t)+.25*np.sin(2*np.pi*frequency*2*t))*np.exp(-t*7)*np.minimum(1,t*100)
    return a
save('soul_capture',chime([(523,0),(784,.065),(1046,.13)],.42))
save('level_up',chime([(262,0),(311,.13),(392,.26),(523,.39),(784,.54)],1.35))
save('ritual_fill',chime([(196,0),(262,.12),(392,.24),(523,.36)],.95))
raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(SOURCE/'jason-ki.mp3'),'-ar',str(SR),'-ac','1','-f','f32le','pipe:1'])
save('voice_masked_v4',np.frombuffer(raw,dtype='<f4'))
metadata={'voice_masked_v4':{'title':'Ki Ki Ki Ma Ma Ma','credit':'alexander / Orange Free Sounds','page':'https://orangefreesounds.com/ki-ki-ki-ma-ma-ma/','source':'https://www.orangefreesounds.com/wp-content/uploads/2019/01/Ki-ki-ki-ma-ma-ma.mp3','license':'CC BY 4.0 (as published by source)','license_url':'https://creativecommons.org/licenses/by/4.0/','changes':'converted to mono Ogg Vorbis, normalized peak 0.70 and short fades','source_sha256':hashlib.sha256((SOURCE/'jason-ki.mp3').read_bytes()).hexdigest()},'soul_capture':'original synthesis','level_up':'original synthesis','ritual_fill':'original synthesis'}
(OUT/'SOURCES-v4.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('PROGRESS_AUDIO_OK')
