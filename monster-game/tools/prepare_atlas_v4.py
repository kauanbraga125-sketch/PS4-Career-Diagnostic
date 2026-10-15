"""Measure PNG alpha into atlas rectangles; never modify generated pixels."""
from pathlib import Path
import numpy as np
from PIL import Image
import json
ART=Path(__file__).resolve().parents[1]/'assets/art'
def edges(alpha,count,axis):
    size=alpha.shape[axis];projection=(alpha>55).sum(axis=1-axis);result=[0]
    for i in range(1,count):
        target=size*i/count;lo=round(target-size*.1);hi=round(target+size*.1)
        blank=np.flatnonzero(projection[lo:hi]<3)+lo
        if len(blank):
            bands=np.split(blank,np.flatnonzero(np.diff(blank)>1)+1)
            band=min(bands,key=lambda b:abs(float(b.mean())-target))
            result.append(round(float(np.median(band))))
        else:result.append(lo+int(np.argmin(projection[lo:hi])))
    return result+[size]
def cells(file,cols,rows):
    im=Image.open(ART/file);assert im.mode=='RGBA'
    alpha=np.asarray(im.getchannel('A'));assert (alpha==0).mean()>.3
    ys=edges(alpha,rows,0);regions=[]
    for row in range(rows):
        band=alpha[ys[row]:ys[row+1]];xs=edges(band,cols,1)
        for col in range(cols):
            y,x=np.where(band[:,xs[col]:xs[col+1]]>55);assert len(x)>100
            regions.append([xs[col]+int(x.min()),ys[row]+int(y.min()),int(x.max()-x.min()+1),int(y.max()-y.min()+1)])
    return regions
result={'rigs':[]}
for name in ['woman','worker']:
    file=f'rig-civilian-{name}-v4.png';result['rigs'].append({'file':file,'parts':cells(file,3,3)})
for key,file,cols,rows in [('mouths','tunnel-mouths-v4.png',2,1),('vehicles','vehicles-v4.png',3,2),('ritual','ritual-v4.png',2,2),('vfx','vfx-v4.png',3,2)]:result[key]=cells(file,cols,rows)
(ART/'atlas-v4.json').write_text(json.dumps(result,indent=2)+'\n')
print('ATLAS_V4_OK: 18 human parts, 2 tunnel boundaries, 6 vehicles, 4 ritual props and 6 FX frames')
