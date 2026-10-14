"""Measure transparent gutters and alpha bounds; never modify generated pixels."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parents[1] / 'assets/art'

def gutters(alpha, count, axis):
    length = alpha.shape[axis]
    projection = (alpha > 30).sum(axis=1-axis)
    edges = [0]
    for i in range(1, count):
        target = length*i/count
        lo, hi = round(target-length*.09), round(target+length*.09)
        blank = np.flatnonzero(projection[lo:hi] < 3)+lo
        if len(blank):
            runs = np.split(blank, np.flatnonzero(np.diff(blank)>1)+1)
            run = min(runs, key=lambda r: abs(float(r.mean())-target))
            edges.append(round(float(np.median(run))))
        else:
            edges.append(round(target))
    return edges+[length]

result = {'rigs': [], 'layers': []}
for name in ['zombie', 'skeleton', 'masked', 'fly']:
    im = Image.open(ART / f'rig-{name}.png')
    assert im.mode == 'RGBA'
    alpha = np.asarray(im.getchannel('A'))
    assert (alpha == 0).mean() > .5
    xs, ys = gutters(alpha, 3, 1), gutters(alpha, 3, 0)
    parts = []
    for row in range(3):
        for col in range(3):
            x0, x1, y0, y1 = xs[col], xs[col+1], ys[row], ys[row+1]
            y, x = np.where(alpha[y0:y1,x0:x1] > 30)
            assert len(x)>100, (name,row,col)
            bounds = [x0+int(x.min()),y0+int(y.min()),int(x.max()-x.min()+1),int(y.max()-y.min()+1)]
            parts.append(bounds)
    result['rigs'].append({'file': f'rig-{name}.png', 'parts': parts})

alpha = np.asarray(Image.open(ART/'parallax-v2.png').getchannel('A'))
edges = gutters(alpha,3,0)
for i in range(3):
    y0,y1 = edges[i:i+2]
    y,x = np.where(alpha[y0:y1] > 30)
    result['layers'].append([0,y0+int(y.min()),alpha.shape[1],int(y.max()-y.min()+1)])
(ART/'rig-layout.json').write_text(json.dumps(result,indent=2)+'\n')
print('RIG_LAYOUT_OK: 36 isolated parts and 3 transparent scenery layers')
