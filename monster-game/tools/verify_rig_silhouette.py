"""Check rendered RGBA poses for detached body parts, not just bone coordinates."""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import label

folder = Path(sys.argv[1])
results = []
for image in sorted(folder.glob('*.png')):
    mask = np.asarray(Image.open(image).getchannel('A')) > 35
    components, _ = label(mask, np.ones((3, 3)))
    sizes = np.bincount(components.ravel())[1:]
    significant = sorted((int(size) for size in sizes if size >= 20), reverse=True)
    results.append({'name': image.name, 'components': significant, 'connected': len(significant) == 1})
assert len(results) == 24, f'Expected 24 rendered poses, got {len(results)}'
assert all(item['connected'] for item in results), results
(folder / 'connectivity.json').write_text(json.dumps(results, indent=2) + '\n')
print('ALPHA_CONNECTIVITY_OK: 24 complete poses form one connected visible silhouette')
