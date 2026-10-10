"""After the initial import, enforce GPU compression and mipmaps for 3D art.

Code-created city materials are not detected by the editor's 3D importer.
Without this pass those 2K textures would stay uncompressed without mipmaps.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1] / 'assets/realism'
count = 0
for path in root.rglob('*.import'):
    text = path.read_text()
    if 'importer="texture"' not in text:
        continue
    values = {'compress/mode': '2', 'mipmaps/generate': 'true', 'detect_3d/compress_to': '0'}
    if '_nor_gl.' in path.name or '_normal.' in path.name:
        values['compress/normal_map'] = '1'
    for key, value in values.items():
        pattern = rf'^{re.escape(key)}=.*$'
        if not re.search(pattern, text, flags=re.MULTILINE):
            raise RuntimeError(f'Missing import option {key}: {path}')
        text = re.sub(pattern, f'{key}={value}', text, flags=re.MULTILINE)
    path.write_text(text)
    count += 1
if count < 30:
    raise RuntimeError(f'Expected all character/city textures to be imported, found {count}')
print(f'PORTO_TEXTURE_IMPORTS_CONFIGURED {count}')
