"""把新配饰「戴」到待机视频上：逐帧跟着身体的伸缩（脚底固定）移动/缩放，烘焙成 purple_wear_<id>.mp4，
再从里面截出待机静帧 purple_wear_<id>.png 和灵动岛探头帧 purple_peekwear_<id>.png（和可灵出的那几件同一套做法）。"""
import sys, os, json, subprocess, numpy as np, shutil
from PIL import Image
SRC='/home/claude/island-me/IslandMe/Resources/Clips/purple_idle.mp4'
CLIPS='/home/claude/island-me/IslandMe/Resources/Clips'; PETS='/home/claude/island-me/Pets.xcassets'
ACC='/home/claude/art/out'; W='/home/claude/art/bake'
FR=f'{W}/frames'
PEEKDY={}
from spots import SPOTS as ORIG
try:
    from spots import PEEK
except ImportError:
    PEEK={}
def frames():
    if not os.path.isdir(FR):
        os.makedirs(FR); subprocess.run(['ffmpeg','-v','error','-i',SRC,f'{FR}/%04d.png'],check=True)
    return sorted(os.listdir(FR))
def measure(a):
    m=a.max(2)>50; ys=np.where(m.any(1))[0]; top,bot=ys.min(),ys.max()
    mid=(top+bot)//2; xs=np.where(m[mid])[0]
    return top,bot,(xs.min()+xs.max())/2,xs.max()-xs.min()
def place(id, spot, fa, ref, base):
    top,bot,cx,wd=fa; t0,b0,cx0,w0=ref
    sx=wd/w0; sy=(bot-top)/(b0-t0)
    acc=Image.open(f'{ACC}/acc_{id}.png').convert('RGBA')
    x,y,w,an=spot
    iw=512*w*sx; ih=iw*acc.height/acc.width
    # 参考帧里的锚点 → 本帧（脚底固定伸缩）
    X=cx+(512*x-cx0)*sx; Y=bot-(b0-512*y)*sy
    cy=Y-ih*(an-0.5)
    a2=acc.resize((max(1,round(iw)),max(1,round(ih))),Image.LANCZOS)
    base.alpha_composite(a2,(round(X-iw/2),round(cy-ih/2)))
    return base
def key(rgb):
    rgb=rgb.astype(np.float32); mx=rgb.max(axis=2); a=np.clip((mx-12)/36,0,1)
    u=rgb.copy(); m=a>0.02; u[m]=np.clip(rgb[m]/a[m][:,None],0,255)
    return np.dstack([u,a*255]).astype(np.uint8)
def imageset(name, im):
    d=f'{PETS}/{name}.imageset'; os.makedirs(d,exist_ok=True); im.save(f'{d}/{name}.png',optimize=True)
    json.dump({"images":[{"filename":f"{name}.png","idiom":"universal"}],"info":{"author":"xcode","version":1},"properties":{"template-rendering-intent":"original"}},open(f'{d}/Contents.json','w'),indent=2)
F=0.82; FX,FY=256,479      # 缩小系数、脚底点
def shrink(im):
    c=Image.new('RGBA',(512,512),(0,0,0,255)); s=im.resize((round(512*F),round(512*F)),Image.LANCZOS)
    c.paste(s,(round(FX-FX*F),round(FY-FY*F))); return c
def sspot(spot):
    x,y,w,an=spot; return (0.5+(x-0.5)*F, FY/512-(FY/512-y)*F, w*F, an)
SHELL='/home/claude/art/shell.png'
def peek(id, spot):
    base=Image.open(SHELL).convert('RGBA')
    x,y,w,an=spot; k=0.69
    X=293+(512*x-246)*k; Y=165+(512*y-181)*k
    acc=Image.open(f'{ACC}/acc_{id}.png').convert('RGBA'); iw=512*w*k; ih=iw*acc.height/acc.width
    ai=acc.resize((round(iw),round(ih)),Image.LANCZOS); pos=(round(X-iw/2),round(Y-ih*(an-0.5)-ih/2))
    if id in BEHIND:
        fur=np.array(base.convert('RGB')).max(2)>60; crown=np.where(fur[:, 200:380].any(1))[0].min()
        ai=occlude(id, ai, pos, base, crown)
    base.alpha_composite(ai,pos)
    kd=Image.fromarray(key(np.array(base.convert('RGB'))))
    return kd.crop((90,0,480,340)).resize((324,282),Image.LANCZOS)
REF=30
# 戴在头「后面」的：头箍类。头顶往下这一截以下、和身体重叠的部分藏到头后面（只露出头顶一小段箍和鹿角）
BEHIND = {'hat_antlers': 0.035}
def occlude(id, accimg, pos, base, crown):
    """把 accimg（贴在 pos）里落在身体上、且低于 crown 线的像素藏掉"""
    if id not in BEHIND: return accimg
    import numpy as _np
    from scipy import ndimage as _nd
    a = _np.array(accimg).astype(float); h, w = a.shape[:2]; x0, y0 = pos
    b = _np.array(base.convert('RGB')).astype(float)
    body = _np.zeros((h, w), bool)
    ys0, xs0 = max(0, -y0), max(0, -x0)
    ys1, xs1 = min(h, b.shape[0] - y0), min(w, b.shape[1] - x0)
    if ys1 > ys0 and xs1 > xs0:
        reg = b[y0 + ys0:y0 + ys1, x0 + xs0:x0 + xs1]
        r, g, bb = reg[..., 0], reg[..., 1], reg[..., 2]
        body[ys0:ys1, xs0:xs1] = (reg.max(2) > 60) & (bb > g)   # 紫色毛（不含黑底）
    rows = _np.arange(h)[:, None] + y0
    hide = body & (rows > crown + BEHIND[id] * 512)
    soft = _nd.gaussian_filter(hide.astype(float), 1.2)
    a[..., 3] *= (1 - soft)
    return Image.fromarray(a.astype(_np.uint8))

def place2(id, spot, A, k, base):
    """按类别跟踪：帽子跟头顶、眼镜和脖子上的跟眼睛，大小跟身体宽度"""
    a, r = A[k], A[REF]
    s = a['wd'] / r['wd']
    x, y, w, an = spot
    X0, Y0 = 512 * x, 512 * y
    if id.startswith('hat'):
        X = a['cx'] + (X0 - r['cx']) * s; Y = a['dome'] + (Y0 - r['dome']) * s
    else:
        X = a['cx'] + (X0 - r['cx']) * s; Y = a['ey'] + (Y0 - r['ey']) * s
    acc = Image.open(f'{ACC}/acc_{id}.png').convert('RGBA')
    iw = 512 * w * s; ih = iw * acc.height / acc.width
    cy = Y - ih * (an - 0.5)
    ai = acc.resize((max(1, round(iw)), max(1, round(ih))), Image.LANCZOS); pos = (round(X - iw / 2), round(cy - ih / 2))
    ai = occlude(id, ai, pos, base, a['dome'])
    base.alpha_composite(ai, pos)
    return base
def bake(id, spot, preview_only=False, pick_frame=None):
    from track import anchors
    spot=sspot(spot); A=anchors()
    fs=frames()
    out=f'{W}/{id}'; shutil.rmtree(out,ignore_errors=True); os.makedirs(out)
    pick=None
    rng = [pick_frame if pick_frame is not None else REF] if preview_only else range(len(fs))
    for k in rng:
        rgb=shrink(Image.open(f'{FR}/{fs[k]}').convert('RGBA'))
        im=place2(id,spot,A,k,rgb)
        if preview_only: return im
        im.convert('RGB').save(f'{out}/{k:04d}.png')
        if k==29 or (preview_only and k==0): pick=im
    if preview_only: return pick
    subprocess.run(['ffmpeg','-v','error','-y','-framerate','24','-i',f'{out}/%04d.png','-c:v','libx264','-crf','24','-pix_fmt','yuv420p','-an','-movflags','+faststart',f'{CLIPS}/purple_wear_{id}.mp4'],check=True)
    # 静帧：第一帧抠黑底缩到 324
    st=Image.fromarray(key(np.array(pick.convert('RGB')))).resize((324,324),Image.LANCZOS); imageset(f'purple_wear_{id}',st)
    ps=PEEK.get(id, ORIG[id]); ps=(ps[0], ps[1]+PEEKDY.get(id, 0), ps[2], ps[3])
    pk=peek(id, ps); imageset(f'purple_peekwear_{id}',pk)
    shutil.rmtree(out)
    return st, pk
