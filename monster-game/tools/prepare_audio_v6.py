"""Prepare Kauan's supplied recordings as one coherent game sound palette.

HORDE_AUDIO_SOURCE points to the untouched MP3s; HORDE_AUDIO_BASE to v0.5 audio.
SFX use gated active RMS, light compression and peak limiting. Music uses LUFS.
No originals are overwritten; SOURCES-v6.json records the processing and hashes.
"""
import hashlib
import json
import os
import subprocess
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.ndimage import maximum_filter1d, gaussian_filter1d

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(os.environ['HORDE_AUDIO_SOURCE'])
BASE = Path(os.environ['HORDE_AUDIO_BASE'])
OUT = ROOT / 'assets/audio'
RATE = 44100
REPORT = []


def decode(path):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le', '-ac', '1', '-ar', str(RATE), '-'])
    return np.frombuffer(raw, np.float32).copy()


def encode(x, name):
    temporary = OUT / (name + '.staging.ogg')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', '-', '-c:a', 'libvorbis', '-q:a', '5', str(temporary)], input=x.astype(np.float32).tobytes(), check=True)
    assert temporary.stat().st_size > 1000
    temporary.replace(OUT / (name + '.ogg'))


def rms(x):
    frames = np.pad(x, (0, (-len(x)) % 441)).reshape(-1, 441)
    energy = np.sqrt(np.mean(frames * frames, axis=1))
    active = energy[energy > max(.0005, energy.max() * .10)]
    return float(np.sqrt(np.mean(active ** 2))) if len(active) else .0001


def fade(x, start=.006, end=.035):
    a, b = min(len(x), int(start * RATE)), min(len(x), int(end * RATE))
    x[:a] *= np.linspace(0, 1, a)
    x[-b:] *= np.linspace(1, 0, b)
    return x


def loop_join(x, seconds=4):
    # Equal-power overlap avoids a repeating click or a sudden buzz restart.
    n = min(int(.12 * RATE), len(x) // 5)
    middle = x[n:-n]
    mix = np.linspace(0, 1, n)
    seam = x[-n:] * np.cos(mix * np.pi / 2) + x[:n] * np.sin(mix * np.pi / 2)
    cycle = np.concatenate([middle, seam])
    count = max(2, int(seconds * RATE / len(cycle)) + 1)
    return np.tile(cycle, count)


def prepare(path, name, voice=False, loop=False):
    x = decode(path)
    if len(x) == 0:
        raise ValueError(f'Empty audio: {path}')
    cutoff = 145 if voice else (65 if 'car' in name or 'engine' in name else 95)
    x = signal.sosfilt(signal.butter(2, cutoff, 'highpass', fs=RATE, output='sos'), x)
    x = signal.sosfilt(signal.butter(2, 10500 if voice else 12500, 'lowpass', fs=RATE, output='sos'), x)
    if path.suffix == '.mp3' and not loop:
        idx = np.flatnonzero(np.abs(x) > max(.0012, np.max(np.abs(x)) * .018))
        if len(idx):
            x = x[max(0, idx[0] - 441):min(len(x), idx[-1] + 1764)]
    # A gentle upward tilt opens muffled voices without creating a piercing tone.
    if voice:
        presence = signal.sosfilt(signal.butter(1, 1500, 'highpass', fs=RATE, output='sos'), x)
        x += presence * .12
    envelope = np.sqrt(gaussian_filter1d(x * x, RATE * .012) + 1e-10)
    threshold = max(.012, rms(x) * 1.3)
    gain = np.minimum(1, (threshold / np.maximum(envelope, threshold)) ** .38)
    x *= gain
    target = -20 if loop else (-18.5 if voice else -20)
    x *= 10 ** (target / 20) / rms(x)
    # Smooth look-ahead peak limiter, preserving attack and avoiding hard clipping.
    peak = maximum_filter1d(np.abs(x), size=441)
    gain = np.minimum(1, .82 / np.maximum(peak, .82))
    x *= gain
    if loop:
        x = loop_join(x)
    else:
        x = fade(x)
    encode(x, name)
    decoded = decode(OUT / (name + '.ogg'))
    REPORT.append({'output': name + '.ogg', 'source': path.name, 'source_sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'duration': round(len(decoded) / RATE, 3), 'active_rms_db': round(20 * np.log10(rms(decoded)), 2), 'peak_db': round(20 * np.log10(max(.00001, np.abs(decoded).max())), 2), 'loop': loop, 'voice': voice})


for path in sorted(BASE.glob('*.ogg')):
    if path.stem in ('moon_menu', 'midnight_run'):
        continue
    name = path.stem
    prepare(path, name, voice=any(s in name for s in ('voice_', 'death_', 'civil_', 'police_', 'army_', 'scream')), loop=name.endswith('_loop') or name == 'city_ambience')

def supplied(pattern, name, **kwargs):
    files = sorted(SOURCE.glob(pattern))
    assert len(files) == 1, (pattern, files)
    prepare(files[0], name, **kwargs)

supplied('Transformation_sound*.mp3', 'transform_fly')
supplied('A_car*#1*.mp3', 'car_approach_1')
supplied('A_car*#2*.mp3', 'car_approach_2')
supplied('A_quiet*.mp3', 'car_crash')
supplied('Two_short*.mp3', 'car_horn')
for i in range(1, 5):
    supplied(f'A_frightened*#{i}*.mp3', f'civil_new_{i}', voice=True)
    supplied(f'A_short,*#{i}*.mp3', f'zombie_chuckle_{i}', voice=True)
supplied('One_short_zombie*.mp3', 'death_zombie', voice=True)
supplied('One_short,*triumphan*.mp3', 'voice_fly', voice=True)
supplied('Seamless*.mp3', 'fly_wings_loop', loop=True)

# Soft simmer for the independently animated liquid in the ritual.
rng = np.random.default_rng(61014)
t = np.arange(RATE * 6) / RATE
x = signal.sosfilt(signal.butter(2, [180, 1600], 'bandpass', fs=RATE, output='sos'), rng.normal(0, .035, len(t)))
for start in rng.uniform(0, 5.7, 44):
    n = int(RATE * rng.uniform(.06, .18)); at = int(start * RATE)
    bt = np.arange(n) / RATE
    bubble = np.sin(2 * np.pi * (rng.uniform(290, 720) * bt + 650 * bt ** 2)) * np.sin(np.linspace(0, np.pi, n)) ** 2 * .12
    x[at:at + n] += bubble[:len(x[at:at + n])]
temp = SOURCE / 'ritual_simmer.wav'
subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','1','-i','-',str(temp)],input=x.astype(np.float32).tobytes(),check=True)
prepare(temp, 'cauldron_loop', loop=True)

for source, name in [('mischief_under_moonlight.mp3', 'music_menu_v6'), ('clockwork_ghoul_s_dash.mp3', 'music_early_v6'), ('midnight_sprint.mp3', 'music_late_v6')]:
    path = SOURCE / source
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(path),'-af','loudnorm=I=-20:TP=-2:LRA=8','-ar',str(RATE),'-ac','2','-c:a','libvorbis','-q:a','5',str(OUT / (name + '.ogg'))],check=True)
    REPORT.append({'output':name+'.ogg','source':source,'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'integrated_loudness_target':-20,'true_peak_target':-2})

record = {'version':'0.6.0','source':'Recordings supplied by Kauan; existing credited samples retained. Ritual simmer synthesized for the project.','processing':'Mono SFX, common high/low-pass palette, gentle envelope compression, gated RMS normalization, look-ahead peak limiting, fades; overlapping loop seams. Stereo music normalized to -20 LUFS; runtime crossfades and voice ducking.','files':REPORT}
(OUT / 'SOURCES-v6.json').write_text(json.dumps(record, ensure_ascii=False, indent=2, default=float))
print('AUDIO_V6_OK', len(REPORT), 'processed assets; supplied MP3s: 19; no hard clipping')
