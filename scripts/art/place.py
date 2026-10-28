from PIL import Image, ImageDraw
import glob
A='/home/claude/island-me/Pets.xcassets/'
OUT='/home/claude/art/out/'
def acc(id):
    try: return Image.open(OUT+f'acc_{id}.png').convert('RGBA')
    except: return Image.open(glob.glob(A+f'acc_{id}.imageset/*.png')[0]).convert('RGBA')
def base(mode):
    if mode=='video':
        b=Image.open('/home/claude/art/idle_v.png').convert('RGBA')
    elif mode=='still':
        b=Image.open(glob.glob(A+'purple_idle.imageset/*.png')[0]).convert('RGBA')
    else:
        b=Image.open(glob.glob(A+'purple_peek.imageset/*.png')[0]).convert('RGBA')
    S=360/max(b.size); b=b.resize((int(b.width*S),int(b.height*S)))
    bg=Image.new('RGBA',b.size,(30,24,40,255)); bg.alpha_composite(b); return bg
def render(mode, id, s):
    b=base(mode); w,h=b.size; ui=acc(id)
    iw=w*s[2]; ih=iw*ui.height/ui.width
    cx=w*s[0]; cy=h*s[1]-ih*(s[3]-0.5)
    a=ui.resize((max(1,int(iw)),max(1,int(ih))))
    b.alpha_composite(a,(int(cx-iw/2),int(cy-ih/2)))
    return b
def grid(items, path):
    tiles=[render(m,i,s) for m,i,s in items]
    W=sum(t.width for t in tiles[:6]); 
    cols=6; rows=(len(tiles)+cols-1)//cols; tw=max(t.width for t in tiles); th=max(t.height for t in tiles)
    g=Image.new('RGB',(cols*tw,rows*(th+16)),(0,0,0)); d=ImageDraw.Draw(g)
    for k,(t,(m,i,s)) in enumerate(zip(tiles,items)):
        x=(k%cols)*tw; y=(k//cols)*(th+16); g.paste(t.convert('RGB'),(x,y)); d.text((x+4,y+th),f'{m}:{i}',fill=(255,255,0))
    g.save(path)
