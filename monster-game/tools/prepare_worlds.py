"""Read generated alpha gutters into runtime atlas regions without editing pixels."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ART=Path(__file__).resolve().parents[1]/'assets/art'

def edges(alpha,count,axis):
    size=alpha.shape[axis]
    projection=(alpha>45).sum(axis=1-axis)
    result=[0]
    for i in range(1,count):
        target=size*i/count;lo=round(target-size*.09);hi=round(target+size*.09)
        blank=np.flatnonzero(projection[lo:hi]<3)+lo
        if len(blank):
            bands=np.split(blank,np.flatnonzero(np.diff(blank)>1)+1)
            band=min(bands,key=lambda b:abs(float(b.mean())-target))
            result.append(round(float(np.median(band))))
        else: result.append(round(target))
    return result+[size]

def cells(file,cols,rows):
    image=Image.open(ART/file);assert image.mode=='RGBA'
    alpha=np.asarray(image.getchannel('A'));assert (alpha==0).mean()>.4
    ys=edges(alpha,rows,0);regions=[]
    for row in range(rows):
        band=alpha[ys[row]:ys[row+1]]
        xs=edges(band,cols,1)
        for col in range(cols):
            y,x=np.where(band[:,xs[col]:xs[col+1]]>45)
            assert len(x)>100,(file,row,col)
            regions.append([xs[col]+int(x.min()),ys[row]+int(y.min()),int(x.max()-x.min()+1),int(y.max()-y.min()+1)])
    return regions

data={'rigs':[],'worlds':[]}
for name in ['civilian','soldier']:
    file=f'rig-{name}.png'
    data['rigs'].append({'file':file,'parts':cells(file,3,3)})
for name in ['city','industrial','airport']:
    file=f'parallax-{name}.png'
    alpha=np.asarray(Image.open(ART/file).getchannel('A'))
    ys=edges(alpha,3,0);layers=[]
    for row in range(3):
        y,x=np.where(alpha[ys[row]:ys[row+1]]>45)
        layers.append([0,ys[row]+int(y.min()),alpha.shape[1],int(y.max()-y.min()+1)])
    data['worlds'].append({'file':file,'layers':layers})
data['vehicles']=cells('vehicles-v3.png',3,2)
data['props']=cells('props-v3.png',3,2)
# Measured silhouettes: the arch's lower right stone crosses the nominal cell
# edge. The crest ends at y=959; tighter runtime regions isolate both objects.
# These are atlas coordinates only, never changes to the source image pixels.
data['props'][3]=[4,516,536,473]
data['props'][4]=[540,543,472,417]
(ART/'world-layout.json').write_text(json.dumps(data,indent=2)+'\n')
print('WORLD_LAYOUT_OK: 18 NPC parts, 9 scenery layers, 6 vehicles and 6 props')
