"""逐帧追踪：眼睛中心（深色像素）、头顶（脑袋圆顶，不含卷毛）、身体中线和宽度。在缩小后的画面上量。"""
import numpy as np, os, json
from PIL import Image
from bake import FR, frames, shrink
def raw(a):
    mask=a.max(2)>50
    ws=mask.sum(1); rows=np.where(ws>0)[0]; bot=rows.max()
    wmax=ws.max()
    dome=int(np.argmax(ws>0.45*wmax))          # 第一行足够宽的地方 = 脑袋圆顶
    mid=(rows.min()+bot)//2; xs=np.where(mask[mid])[0]; cx=(xs.min()+xs.max())/2; wd=xs.max()-xs.min()
    from scipy import ndimage
    m=(a.max(2)<55)&(a.max(2)>3)
    m[:dome]=False; m[dome+int(0.3*512):]=False; m[:, :int(cx-0.25*512)]=False; m[:, int(cx+0.25*512):]=False
    lab,nc=ndimage.label(m); comps=[]
    for k in range(1,nc+1):
        ys,xs=np.where(lab==k)
        if len(ys)>250: comps.append((len(ys), ys.mean(), xs.mean()))
    ey=ex=np.nan; n=0
    best=None
    for i in range(len(comps)):
        for j in range(i+1,len(comps)):
            c1,c2=comps[i],comps[j]
            if abs(c1[1]-c2[1])<20 and 40<abs(c1[2]-c2[2])<130:
                sc=c1[0]+c2[0]
                if best is None or sc>best[0]: best=(sc,(c1[1]+c2[1])/2,(c1[2]+c2[2])/2)
    if best: n,ey,ex=best
    return dict(dome=dome,bot=int(bot),cx=float(cx),wd=float(wd),ey=float(ey),ex=float(ex),n=int(n))
def anchors():
    p='/home/claude/art/bake/anchors.json'
    if os.path.exists(p): return json.load(open(p))
    fs=frames(); A=[raw(np.array(shrink(Image.open(f'{FR}/{f}').convert('RGBA')))[:,:,:3]) for f in fs]
    ns=np.array([x['n'] for x in A]); good=ns>0
    for key in ['ey','ex']:
        v=np.array([x[key] for x in A]); idx=np.arange(len(v))
        v=np.interp(idx, idx[good], v[good])            # 眨眼帧用前后插值
        v=np.convolve(np.pad(v,2,mode='wrap'), np.ones(5)/5, mode='valid')  # 轻微平滑（循环）
        for x,val in zip(A,v): x[key]=float(val)
    for key in ['dome','cx','wd']:
        v=np.array([x[key] for x in A],float); v=np.convolve(np.pad(v,2,mode='wrap'), np.ones(5)/5, mode='valid')
        for x,val in zip(A,v): x[key]=float(val)
    json.dump(A,open(p,'w')); return A
if __name__=='__main__':
    A=anchors()
    for i in range(0,len(A),10): print(i,{k:round(v,1) for k,v in A[i].items()})
