import sys, importlib.util, numpy as np
from PIL import Image, ImageDraw, ImageFilter
src=open('/home/claude/build_v4.py').read().split('# 1) 视频')[0]
g={}; exec(src,g); key=g['key']
rgb=np.array(Image.open('/home/claude/island-me/design/xiaozi_standard_v4_front.png').convert('RGB'))
a=key(rgb); fg=Image.fromarray(a)
x0,y0,x1,y1=g['bbox'](a); print(x0,y0,x1,y1)
N=1024
# background: alien-shell gradient + soft glow + few stars
yy,xx=np.mgrid[0:N,0:N]/N
c0=np.array([0x6B,0x4F,0xB8]); c1=np.array([0x2E,0x1F,0x5C])
t=np.clip(yy*0.9+xx*0.1,0,1)[...,None]
bg=(c0*(1-t)+c1*t)
d=np.sqrt((xx-0.5)**2+(yy-0.52)**2); glow=np.clip(1-d/0.45,0,1)**2
bg=bg+glow[...,None]*np.array([90,70,140])*0.5
bg=Image.fromarray(np.clip(bg,0,255).astype(np.uint8)).convert('RGBA')
dr=ImageDraw.Draw(bg)
for (sx,sy,r) in [(150,170,7),(860,140,9),(900,330,5),(110,420,5),(800,90,4),(230,90,4)]:
    dr.ellipse((sx-r,sy-r,sx+r,sy+r),fill=(0xE9,0xDE,0xFF,230))
# crop: body full width, scale so body width ~ 92% and bottom bleeds off
body=fg.crop((x0,y0,x1+1,y1+1))
s=N*0.98/body.width
body=body.resize((round(body.width*s),round(body.height*s)),Image.LANCZOS)
top=int(N*0.10)
sh=Image.new('RGBA',(N,N),(0,0,0,0))
bg.alpha_composite(body,((N-body.width)//2,top))
bg.convert('RGB').save(sys.argv[1])
