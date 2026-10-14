"""Read alpha bounds for runtime AtlasTexture regions; never alter artwork."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
art=ROOT/'assets/art'
output={}
for name,cols,rows in [('creatures',6,4),('items',4,3)]:
    image=Image.open(art/(name+'.png'))
    assert image.mode=='RGBA',f'{name} needs actual alpha'
    alpha=np.asarray(image.getchannel('A'))
    row_edges=[round(i*image.height/rows) for i in range(rows+1)]
    if name=='items':
        # Generated sheets can have uneven row gutters. Locate their actual
        # transparent bands so a neighbour's crystal tip never enters a shoe.
        projection=(alpha>36).sum(axis=1)
        for i in range(1,rows):
            target=image.height*i/rows
            lo=max(0,round(target-image.height*.08))
            hi=min(image.height,round(target+image.height*.08))
            blank=np.where(projection[lo:hi]<3)[0]+lo
            if len(blank):row_edges[i]=round(float(np.median(blank)))
    cells=[]
    for row in range(rows):
        cells.append([])
        for column in range(cols):
            x0=round(column*image.width/cols);x1=round((column+1)*image.width/cols)
            y0=row_edges[row];y1=row_edges[row+1]
            yy,xx=np.where(alpha[y0:y1,x0:x1]>36)
            assert len(xx)>100,f'Empty sprite {name} {row} {column}'
            bounds=[max(0,int(xx.min())-2),max(0,int(yy.min())-2),min(x1-x0,int(xx.max())+3),min(y1-y0,int(yy.max())+3)]
            cells[-1].append((x0,y0,bounds))
    if name=='creatures':
        sprites=[]
        for row in cells:
            x0=min(c[2][0] for c in row);y0=min(c[2][1] for c in row)
            x1=max(c[2][2] for c in row);y1=max(c[2][3] for c in row)
            baseline=max(c[2][3] for c in row[:5])-y0
            sprites.append({'frames':[[x+x0,y+y0,x1-x0,y1-y0] for x,y,b in row],'baseline':baseline/(y1-y0)})
        output[name]=sprites
    else:
        output[name]=[[x+b[0],y+b[1],b[2]-b[0],b[3]-b[1]] for row in cells for x,y,b in row]
(art/'layout.json').write_text(json.dumps(output,indent=2)+'\n')
print('ART_LAYOUT_OK: 24 character poses, 12 item and obstacle sprites')
