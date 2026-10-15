"""Measure generated alpha without changing raster pixels."""
from pathlib import Path
import numpy as np,json
from PIL import Image
ART=Path(__file__).resolve().parents[1]/'assets/art'
def cuts(alpha,n,axis):
    size=alpha.shape[axis];p=(alpha>55).sum(axis=1-axis);out=[0]
    for i in range(1,n):
        t=size*i/n;lo=round(t-size*.10);hi=round(t+size*.10)
        blank=np.flatnonzero(p[lo:hi]<3)+lo
        if len(blank):
            bands=np.split(blank,np.flatnonzero(np.diff(blank)>1)+1)
            band=min(bands,key=lambda b:abs(b.mean()-t));out.append(round(float(np.median(band))))
        else:out.append(lo+int(np.argmin(p[lo:hi])))
    return out+[size]
def cells(file,cols,rows,aligned=False):
    im=Image.open(ART/file);assert im.mode=='RGBA';a=np.asarray(im.getchannel('A'));assert (a==0).mean()>.25
    if aligned:
        w,h=im.size;assert w%cols==0 and h%rows==0
        return [[i*(w//cols),j*(h//rows),w//cols,h//rows] for j in range(rows) for i in range(cols)]
    ys=cuts(a,rows,0);result=[]
    for row in range(rows):
        band=a[ys[row]:ys[row+1]];xs=cuts(band,cols,1)
        for col in range(cols):
            y,x=np.where(band[:,xs[col]:xs[col+1]]>55);assert len(x)>50
            result.append([xs[col]+int(x.min()),ys[row]+int(y.min()),int(x.max()-x.min()+1),int(y.max()-y.min()+1)])
    return result
j={'police':cells('rig-police-v5.png',3,3),'souls':cells('soul-frames-v5.png',3,2,True),'pickups':cells('power-pickups-v5.png',3,2,True),'fire':cells('fire-frames-v5.png',3,2,True),'damage':cells('vehicles-damaged-v5.png',3,2),'wrecks':cells('vehicles-wrecks-v5.png',3,2)}
(ART/'atlas-v5.json').write_text(json.dumps(j,indent=2)+'\n')
print('ATLAS_V5_OK: police rig, 6 soul frames, 6 organic pickup frames, 6 fire frames, 6 damaged and 6 wrecked vehicles')
