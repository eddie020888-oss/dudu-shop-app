#!/usr/bin/env python3
"""从全身帧裁"脸"特写，给灵动岛小圆点（最小样式）用：取身体包围盒上部，做成正方形，108px。
用法: make_faces.py [frame ...]   不带参数 = 默认一组表情
输出: Pets.xcassets/purple_face_<frame>.imageset
"""
import sys, os, json
import numpy as np
from PIL import Image
A='/home/claude/island-me/Pets.xcassets'
names=sys.argv[1:] or ['idle','happy','laugh','shy','think','surprised','cry','angry','hungry','thirsty','dirty','yawn','blink','sleep','eat','coffee']
S=108
for n in names:
    src=f'{A}/purple_{n}.imageset/purple_{n}.png'
    if not os.path.exists(src): print('skip',n); continue
    im=Image.open(src).convert('RGBA'); a=np.array(im)[...,3]>40
    ys,xs=np.where(a); y0,y1,x0,x1=ys.min(),ys.max(),xs.min(),xs.max()
    h=y1-y0; w=x1-x0
    # 脸：从顶部开始取身高的 62%，宽取中间，做正方形
    side=int(max(h*0.62, w*0.78)); cx=(x0+x1)//2
    box=(cx-side//2, y0-int(side*0.04), cx+side//2, y0-int(side*0.04)+side)
    face=im.crop(box).resize((S,S),Image.LANCZOS)
    d=f'{A}/purple_face_{n}.imageset'; os.makedirs(d,exist_ok=True)
    face.save(f'{d}/purple_face_{n}.png',optimize=True)
    json.dump({"images":[{"filename":f"purple_face_{n}.png","idiom":"universal"}],"info":{"author":"xcode","version":1},"properties":{"template-rendering-intent":"original"}},open(f'{d}/Contents.json','w'),indent=2)
    print('face',n)
