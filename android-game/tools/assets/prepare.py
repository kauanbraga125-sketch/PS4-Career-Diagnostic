"""Build the redistributable CC0 art pack. Blender is a build tool, not a runtime dependency."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
import shutil
import subprocess
import tarfile
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
    'car.zip': 'https://opengameart.org/sites/default/files/StreetCar.zip',
    'bike.blend': 'https://opengameart.org/sites/default/files/bike.blend',
    'sfx.zip': 'https://opengameart.org/sites/default/files/sfx_100_v2.zip',
    'engine.wav': 'https://opengameart.org/sites/default/files/loop_0.wav',
    'music.ogg': 'https://opengameart.org/sites/default/files/wednesday_night.ogg',
}
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
    return {'file': name, 'url': url, 'sha256': digest, 'license': 'GPL-3.0 build tool only' if name == 'mpfb.zip' else 'CC0-1.0'}


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


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for material, source in MATERIALS.items():
        for channel in ('diff', 'nor_gl', 'rough'):
            SOURCES[f'textures/{material}_{channel}.jpg'] = f'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/{source}/{source}_{channel}_2k.jpg'
    with ThreadPoolExecutor(max_workers=6) as pool:
        provenance = list(pool.map(fetch, SOURCES.items()))
    unzip('human.zip', 'human')
    mpfb = unzip('mpfb.zip', 'mpfb') / f'mpfb2-{MPFB_COMMIT}/src'
    car = unzip('car.zip', 'car-package')
    car_out = CACHE / 'car'
    car_out.mkdir(exist_ok=True)
    package = next(car.rglob('*.unitypackage'))
    with tarfile.open(package) as archive:
        members = {member.name: member for member in archive.getmembers() if member.isfile()}
        for name in members:
            if name.endswith('/pathname'):
                filename = Path(archive.extractfile(name).read().decode().strip()).name
                if Path(filename).suffix.lower() in ('.fbx', '.png', '.jpg'):
                    asset = name.rsplit('/', 1)[0] + '/asset'
                    (car_out / filename).write_bytes(archive.extractfile(asset).read())
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
    (OUT / 'sources.json').write_text(json.dumps(provenance, indent=2) + '\n')
    env = os.environ | {'PORTO_ASSET_CACHE': str(CACHE), 'PORTO_ASSET_OUTPUT': str(OUT), 'PORTO_MPFB': str(mpfb)}
    subprocess.run([os.environ.get('PORTO_BLENDER', 'blender'), '--background', '--factory-startup', '--python-exit-code', '1', '--python', str(Path(__file__).with_name('build_models.py'))], env=env, check=True)
    for name in ('person_0', 'person_1', 'person_2', 'person_3', 'car', 'bike'):
        if not (OUT / 'models' / f'{name}.glb').is_file():
            raise RuntimeError(f'Missing model {name}')
    print('PORTO_ASSETS_OK', flush=True)


if __name__ == '__main__':
    main()
