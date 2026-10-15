"""Process all 60 supplied originals without changing them. Exact event map is authoritative."""
from pathlib import Path
import os,re,json,hashlib,subprocess,concurrent.futures
ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path(os.environ['HORDE_AUDIO_SOURCE'])
text=(SOURCE/'LEIA_ME_MAPA_COMPLETO_DOS_AUDIOS.txt').read_text(encoding='utf-8-sig').split('INDICE ALFABETICO')[0]
entries=[];group=None
for line in text.splitlines():
 m=re.match(r'\[([A-Z]+_\d+)\]',line)
 if m:group=m.group(1)
 m=re.search(r'VARIANTE (\d+) \| (.+?\.mp3) \|',line)
 if m:
  entries.append({'event':group,'variant':int(m[1]),'source':m[2],'output':f'v7_{group.lower()}_{int(m[1])}.ogg'})
assert len(entries)==60 and len({e['source'] for e in entries})==60
OUT=ROOT/'assets/audio/v7';OUT.mkdir(exist_ok=True)
loops={'MOV_01','MOV_04','RIT_01','VEI_01','AMB_00','AMB_01','AMB_02','AMB_03','AMB_04'}
def process(e):
 src=SOURCE/e['source'];out=OUT/e['output'];loop=e['event'] in loops
 target=-27 if e['event'].startswith('AMB') else (-25 if loop else -21)
 filters=f'highpass=f=65,lowpass=f=11500,acompressor=threshold=0.18:ratio=2:attack=6:release=90,loudnorm=I={target}:TP=-3:LRA=7'
 # Tiny edge fades remove codec boundary clicks while retaining the original attack.
 duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(src)]))
 if loop:
  # Rotate an equal-power overlap to make the end and start adjacent samples.
  filters+=f',asplit=3[a][b][c];[a]atrim=start=0:end=0.10,asetpts=PTS-STARTPTS[head];[b]atrim=start=0.10:end={duration-.10},asetpts=PTS-STARTPTS[mid];[c]atrim=start={duration-.10},asetpts=PTS-STARTPTS[tail];[tail][head]acrossfade=d=0.10:c1=qsin:c2=qsin[seam];[mid][seam]concat=n=2:v=0:a=1'
  filters+=',alimiter=limit=0.70:level=0'
  cmd=['ffmpeg','-v','error','-y','-i',str(src),'-filter_complex',filters]
 else:
  filters+=f',afade=t=in:d=0.003,afade=t=out:st={max(0,duration-.035)}:d=0.035'
  filters+=',alimiter=limit=0.70:level=0'
  cmd=['ffmpeg','-v','error','-y','-i',str(src),'-af',filters]
 subprocess.run(cmd+['-ar','44100','-ac','1','-c:a','libvorbis','-q:a','4',str(out)],check=True)
 check=subprocess.run(['ffmpeg','-hide_banner','-i',str(out),'-af','astats=metadata=0:reset=0','-f','null','-'],capture_output=True,text=True,check=True).stderr
 peaks=re.findall(r'Peak level dB: ([\-\d.]+)',check);peak=float(peaks[-1]);assert peak<-.5,(out,peak)
 return dict(e,source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),loop=loop,peak_db=peak,target_lufs=target,classification_confirmed=e['event'] not in ['AMB_01','AMB_02','AMB_03'])
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:report=list(pool.map(process,entries))
manifest={'version':'0.7.0','processing':'65Hz highpass, 11.5kHz lowpass, gentle compression, loudness normalization and -3dB true peak target; boundary fades/crossfades; originals untouched.','unassigned_events':['AMB_01','AMB_02','AMB_03'],'review_note':'Provisional scenario labels require auditory confirmation. These files are processed and retained, but no guessed scenario assignment is enabled. Generic urban and confirmed tunnel groups are used; existing sound beds retained elsewhere.','files':report}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print('AUDIO_V7_OK',len(report),'files; peak maximum',max(x['peak_db'] for x in report))
