import sys, numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0,'/home/claude/island-me/scripts/art')
import importlib; cut=importlib.import_module('cut')
sheet, path = sys.argv[1], sys.argv[2]
im=Image.open(path).convert('RGBA'); W,H=im.size
for q,(name,mx) in enumerate(cut.MAP[sheet]):
    x0=(q%2)*W//2; y0=(q//2)*H//2
    sub=np.array(im.crop((x0,y0,x0+W//2,y0+H//2)))
    solid=sub[:,:,3]>20
    lab,n=ndimage.label(ndimage.binary_dilation(solid,iterations=3))
    h,w=solid.shape
    sizes=ndimage.sum(solid,lab,range(1,n+1)); big=sizes.max()
    for k in range(1,n+1):
        ys,xs=np.where(lab==k)
        touches= ys.min()<=1 or xs.min()<=1 or ys.max()>=h-2 or xs.max()>=w-2
        if touches and sizes[k-1] < 0.15*big: sub[lab==k]=0
    c=Image.fromarray(sub); a=c.split()[3].point(lambda v:255 if v>20 else 0); c=c.crop(a.getbbox()); c.thumbnail((mx,mx),Image.LANCZOS)
    pad=max(2,int(max(c.size)*0.03)); c2=Image.new('RGBA',(c.width+2*pad,c.height+2*pad),(0,0,0,0)); c2.paste(c,(pad,pad))
    c2.save(f'/home/claude/art/out/{name}.png')
