import sys
from PIL import Image
A='/home/claude/island-me/IslandMe/Resources/Assets.xcassets/'
OUT='/home/claude/art/out/'
SPOT={'lamp':(0.50,0.375,0.17,True),'cushion':(0.15,0.94,0.30,False),'blanket':(0.86,0.95,0.30,False),'tv':(0.25,0.78,0.40,True),'snack':(0.85,0.66,0.26,True),'window':(0.50,0.32,0.46,False),'telescope':(0.24,0.86,0.38,True),'lights':(0.16,0.15,0.26,False),'painting':(0.84,0.30,0.20,False),'nightstand':(0.86,0.64,0.22,True),'glowplant':(0.86,0.49,0.13,True),'slippers':(0.86,0.80,0.17,False),'clock':(0.22,0.25,0.15,False),'plush':(0.50,0.235,0.20,True),'floorlamp':(0.64,0.60,0.11,True),'beanbag':(0.84,0.95,0.30,True),'plant':(0.10,0.98,0.22,True),'chime':(0.85,0.22,0.12,False),'globe':(0.12,0.64,0.16,True),'lounger':(0.70,0.88,0.44,True),'books':(0.43,0.96,0.18,True),'pinboard':(0.50,0.32,0.40,False),'trophies':(0.15,0.33,0.22,False),'beanbag2':(0.46,0.90,0.26,True),'toybox':(0.90,0.99,0.24,True)}
ROOM={'bedroom':['lamp','cushion','blanket','lights','painting','nightstand','glowplant','slippers'],'living':['tv','snack','clock','plush','floorlamp','beanbag','plant'],'stars':['window','telescope','chime','globe','lounger','books'],'play':['pinboard','trophies','beanbag2','toybox']}
def room(r, v):
    import glob; bg=Image.open(glob.glob(A+f'nest_bg_{r}.imageset/nest_bg_{r}.*')[0]).convert('RGBA'); W=400; bg=bg.resize((W,int(W*1.5))); w,h=bg.size
    items=sorted(ROOM[r], key=lambda k: (-1+SPOT[k][1]) if (not SPOT[k][3] and SPOT[k][1]<0.5) else SPOT[k][1])
    for k in items:
        x,y,sw,bot=SPOT[k]
        try: im=Image.open(OUT+f'nest_{k}_v{v}.png') if v else Image.open(A+f'nest_{k}.imageset/nest_{k}.png')
        except Exception: continue
        im=im.convert('RGBA'); iw=w*sw; ih=iw*im.height/im.width; im=im.resize((int(iw),int(ih)))
        cy = h*y-ih/2 if bot else h*y
        bg.alpha_composite(im,(int(w*x-iw/2),int(cy-ih/2)))
    return bg
rs=sys.argv[1:] or ['bedroom','living','stars','play']
g=Image.new('RGB',(3*400*len(rs),600))
for i,r in enumerate(rs):
    for v in range(3): g.paste(room(r,v).convert('RGB'),((i*3+v)*400,0))
g.save('roomprev.jpg')
