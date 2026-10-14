"""Build the redistributable CC0 art pack. Blender is a build tool, not a runtime dependency."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
import shutil
import subprocess
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[3]
CACHE = ROOT / '.porto-asset-cache'
OUT = ROOT / 'android-game/assets/realism'
MPFB_COMMIT = 'd0a32e57a7f915cb2f2b95410e2117648c7bbb7e'
SOURCES = {
    'human.zip': 'https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip',
    'mpfb.zip': f'https://github.com/makehumancommunity/mpfb2/archive/{MPFB_COMMIT}.zip',
    'tree.zip': 'https://opengameart.org/sites/default/files/tree_1.zip',
    'concept-car.glb': 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/edc7c9e67c639d230715049ee31f9a96a6babbbe/Models/CarConcept/glTF-Binary/CarConcept.glb',
    'car-license.md': 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/edc7c9e67c639d230715049ee31f9a96a6babbbe/Models/CarConcept/LICENSE.md',
    'bike.blend': 'https://opengameart.org/sites/default/files/bike.blend',
    'sfx.zip': 'https://opengameart.org/sites/default/files/sfx_100_v2.zip',
    'engine.wav': 'https://opengameart.org/sites/default/files/loop_0.wav',
    'music.ogg': 'https://opengameart.org/sites/default/files/wednesday_night.ogg',
}
KENNEY_PIN = '08f0c913f6783cc81f9f6105a7cdda8562b1c192'
for i, letter in enumerate('abcdefgh'):
    SOURCES[f'building_{i}.glb'] = (
        f'https://raw.githubusercontent.com/Hidencod/tge-assets/{KENNEY_PIN}/packs/city-kit-suburban/building-type-{letter}.glb'
    )

KAYKIT = 'https://raw.githubusercontent.com/GeorgeQLe/assets-kaykit-3d-characters/af08a62d3669370ec4636ae6314b38cdcd5dd759/assets/kaykit/character-animations-1.1/Animations/gltf/Rig_Medium/'
SOURCES.update({
    'commercial.zip': 'https://kenney.nl/media/pages/assets/city-kit-commercial/a742d900eb-1753115042/kenney_city-kit-commercial_2.1.zip',
    'skyboxes.zip': 'https://kenney.nl/media/pages/assets/skyboxes/6736ff5c10-1784123473/kenney_skyboxes.zip',
    'guns.zip': 'https://opengameart.org/sites/default/files/ultimate_gun_pack_by_quaternius.zip',
    'helicopter.zip': 'https://opengameart.org/sites/default/files/Heli_0.zip',
    'plane.blend': 'https://opengameart.org/sites/default/files/biplane-1.blend',
    'MovementBasic.glb': KAYKIT+'Rig_Medium_MovementBasic.glb',
    'General.glb': KAYKIT+'Rig_Medium_General.glb',
    'CombatRanged.glb': KAYKIT+'Rig_Medium_CombatRanged.glb',
})

MATERIALS = {
    'asphalt': 'asphalt_03', 'concrete': 'concrete_wall_006',
    'paving': 'pavement_02', 'grass': 'aerial_grass_rock',
    'metal': 'corrugated_iron', 'wood': 'wood_planks',
}


def fetch(item):
    name, url = item
    dest = CACHE / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists():
        for attempt in range(4):
            try:
                with urllib.request.urlopen(url, timeout=120) as response, dest.with_suffix('.tmp').open('wb') as output:
                    shutil.copyfileobj(response, output)
                dest.with_suffix('.tmp').replace(dest)
                break
            except Exception:
                if attempt == 3:
                    raise
                time.sleep(2 ** attempt)
    digest = hashlib.sha256(dest.read_bytes()).hexdigest()
    print(f'FETCHED {name} {dest.stat().st_size} {digest}', flush=True)
    return {'file': name, 'url': url, 'sha256': digest, 'license': ('GPL-3.0 build tool only' if name == 'mpfb.zip' else ('CC-BY-4.0' if name in ('concept-car.glb', 'car-license.md') else 'CC0-1.0'))}


def unzip(name, folder):
    target = CACHE / folder
    if not (target / '.complete').exists():
        target.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(CACHE / name) as archive:
            for member in archive.infolist():
                if not (target / member.filename).resolve().is_relative_to(target.resolve()):
                    raise ValueError('Unsafe archive member')
            archive.extractall(target)
        (target / '.complete').touch()
    return target


def prepare_style_assets():
    # Keep the relative texture paths provided by Kenney's GLB files.
    source = unzip('commercial.zip','commercial') / 'Models/GLB format'
    shutil.copytree(source,OUT/'models/town/shops',dirs_exist_ok=True)
    sky = unzip('skyboxes.zip','skyboxes')
    (OUT/'sky').mkdir(exist_ok=True)
    for name in ['day','morning','night']:
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(next(sky.rglob('skybox-'+name+'.png'))),'-vf','format=rgb24,scale=2048:1024:flags=lanczos','-pix_fmt','rgb24',str(OUT/'sky'/(name+'.png'))],check=True)
        if (OUT/'sky'/(name+'.png')).read_bytes()[25] != 2:
            raise RuntimeError('Sky texture must remain RGB after resizing: '+name)
    for archive in ['guns','helicopter']:
        unzip(archive+'.zip',archive)
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(CACHE/'engine.wav'),'-af','loudnorm=I=-18:TP=-2:LRA=7','-ac','1','-ar','22050','-c:a','libvorbis','-q:a','4',str(OUT/'audio/engine.ogg')],check=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for material, source in MATERIALS.items():
        for channel in ('diff', 'nor_gl', 'rough'):
            SOURCES[f'textures/{material}_{channel}.jpg'] = f'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/{source}/{source}_{channel}_2k.jpg'
    with ThreadPoolExecutor(max_workers=6) as pool:
        provenance = list(pool.map(fetch, SOURCES.items()))
    unzip('human.zip', 'human')
    mpfb = unzip('mpfb.zip', 'mpfb') / f'mpfb2-{MPFB_COMMIT}/src'
    (OUT / 'licenses').mkdir(exist_ok=True)
    shutil.copyfile(CACHE / 'car-license.md', OUT / 'licenses/CarConcept-LICENSE.md')
    sfx = unzip('sfx.zip', 'sfx')
    audio = OUT / 'audio'
    audio.mkdir(exist_ok=True)
    for name, suffix in {
        'step_1': 'footstep_01', 'step_2': 'footstep_02', 'grass': 'footstep_wet_01',
        'land': 'hit_01', 'impact': 'metal_hit_01', 'door': 'door_01',
        'reload': 'switch_01', 'ambient': 'loop_highway', 'wind': 'loop_ambient_02',
    }.items():
        source = next(sfx.rglob(f'*{suffix}.ogg'))
        shutil.copyfile(source, audio / f'{name}.ogg')
    for filename in ('engine.wav', 'music.ogg'):
        shutil.copyfile(CACHE / filename, audio / filename)
    shutil.copytree(CACHE / 'textures', OUT / 'textures', dirs_exist_ok=True)
    (OUT / 'models').mkdir(exist_ok=True)
    for i in range(8):
        shutil.copyfile(CACHE / f'building_{i}.glb', OUT / 'models' / f'building_{i}.glb')
    shutil.copyfile(next(unzip('tree.zip', 'tree').rglob('tree.glb')), OUT / 'models/tree.glb')
    prepare_style_assets()
    (OUT / 'sources.json').write_text(json.dumps(provenance, indent=2) + '\n')
    env = os.environ | {'PORTO_ASSET_CACHE': str(CACHE), 'PORTO_ASSET_OUTPUT': str(OUT), 'PORTO_MPFB': str(mpfb)}
    subprocess.run([os.environ.get('PORTO_BLENDER', 'blender'), '--background', '--factory-startup', '--python-exit-code', '1', '--python', str(Path(__file__).with_name('build_models.py'))], env=env, check=True)
    subprocess.run([os.environ.get('PORTO_BLENDER', 'blender'), '--background', '--factory-startup', '--python-exit-code', '1', '--python', str(Path(__file__).with_name('build_style.py'))], env=env, check=True)
    for name in ('person_0', 'person_1', 'person_2', 'person_3', 'car', 'bike', 'tree', 'helicopter', 'plane', *(f'gun_{i}' for i in range(4)), *(f'building_{i}' for i in range(8))):
        if not (OUT / 'models' / f'{name}.glb').is_file():
            raise RuntimeError(f'Missing model {name}')
    print('PORTO_ASSETS_OK', flush=True)


if __name__ == '__main__':
    main()
