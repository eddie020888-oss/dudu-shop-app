#!/usr/bin/env python3
"""v4 新小紫一次性入库：视频循环 → Clips；动作帧/表情帧 → Pets.xcassets（抠底、统一尺寸、底对齐）；探头帧；删掉旧设计残留。"""
import os, glob, json, shutil, subprocess
import numpy as np
from PIL import Image
from scipy import ndimage

V = '/home/claude/pet-video/v4'
APP = '/home/claude/island-me'
CLIPS = f'{APP}/IslandMe/Resources/Clips'
ASSETS = f'{APP}/Pets.xcassets'
TMP = f'{V}/build'; os.makedirs(TMP, exist_ok=True); os.makedirs(f'{V}/loop', exist_ok=True)
S = 324; M = int(S * 0.04)

# 动作 → 用哪段原视频
CLIP_SRC = {'idle': 'idle', 'sleep': 'sleep2', 'eat': 'eat5', 'phone': 'phone', 'work': 'work', 'type': 'type',
            'music': 'music3', 'dance': 'dance', 'call': 'call', 'walk': 'walk', 'drive': 'drive', 'coffee': 'coffee',
            'read': 'read', 'movie': 'movie', 'charge': 'charge', 'wash': 'wash', 'gym': 'gym', 'wake': 'wake',
            'run': 'run', 'uke': 'uke'}
# 表情 → 选中的静帧
EXPR = {'idle': 'idle1', 'blink': 'blink1', 'happy': 'happy1', 'laugh': 'laugh3',
        'surprised': 'surprised1', 'shy': 'shy2', 'think': 'think2', 'angry': 'angry4', 'cry': 'cry4',
        'hungry': 'hungry1', 'thirsty': 'thirsty3', 'dirty': 'dirty2', 'party': 'party2'}

def loop(src, dst):
    """找首尾最像的两帧做循环点（scripts/bestloop.py），衔接处几乎看不出来"""
    out = subprocess.check_output(['python3', '/home/claude/bestloop.py', src, dst]).decode().strip()
    print(os.path.basename(dst), out)

def key(rgb):
    """背景 = 与边框中位色相近、且连到边框的区域；边缘做软过渡并反预乘去色边。"""
    rgb = rgb.astype(np.float32)
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(border, axis=0)
    dist = np.linalg.norm(rgb - bg, axis=2)
    lab, _ = ndimage.label(dist < 40)
    edge_labels = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgm = np.isin(lab, list(edge_labels))
    a = np.ones(dist.shape, np.float32)
    a[bgm] = np.clip((dist[bgm] - 10) / 30, 0, 1)
    a = ndimage.gaussian_filter(a, 0.6)
    m = a > 0.02
    out = rgb.copy()
    out[m] = np.clip((rgb[m] - (1 - a[m])[:, None] * bg) / a[m][:, None], 0, 255)
    # 第二遍：去掉连着背景的浅灰/白色地面和投影（低饱和、亮），牙齿眼白在身体里面不受影响
    mx = out.max(axis=2); mn = out.min(axis=2)
    floor = (mn > 150) & (mx - mn < 30) & (a > 0.1)
    lab3, n3 = ndimage.label(floor)
    if n3:
        transparent = ndimage.binary_dilation(a < 0.1, iterations=2)
        touch = set(np.unique(lab3[transparent & floor])) - {0}
        H = a.shape[0]
        touch = {t for t in touch if np.where(lab3 == t)[0].min() > H * 0.6}   # 只去下方的地面/投影，头顶泡泡保留
        a = np.where(np.isin(lab3, list(touch)), 0, a)
        a = ndimage.gaussian_filter(a, 0.5)
    # 去掉和主体不相连的小碎块（彩纸除外：只去面积很小的）
    body = a > 0.5
    lab2, n = ndimage.label(body)
    if n > 1:
        sizes = ndimage.sum(body, lab2, range(1, n + 1))
        keep = np.isin(lab2, [i + 1 for i, s in enumerate(sizes) if s >= max(60, sizes.max() * 0.002)])
        a = np.where(body & ~keep, 0, a)
    return np.dstack([out, a * 255]).astype(np.uint8)

def bbox(a):
    m = a[..., 3] > 60; ys, xs = np.where(m)
    return xs.min(), ys.min(), xs.max(), ys.max()

def write(name, im):
    d = f'{ASSETS}/purple_{name}.imageset'; os.makedirs(d, exist_ok=True)
    for f in glob.glob(f'{d}/*.png'): os.remove(f)
    im.save(f'{d}/purple_{name}.png', optimize=True)
    json.dump({"images": [{"filename": f"purple_{name}.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1},
               "properties": {"template-rendering-intent": "original"}}, open(f'{d}/Contents.json', 'w'), indent=2)

def place(a, ref_h, sitting=True):
    """裁到主体，按 idle 的身高比例缩放（躺着/带道具的按宽度兜底），底对齐放进 324 画布。"""
    x0, y0, x1, y1 = bbox(a)
    im = Image.fromarray(a).crop((x0, y0, x1 + 1, y1 + 1))
    target = (S - 2 * M) * 0.92
    s = target / ref_h if sitting else target / ref_h
    w2, h2 = round(im.width * s), round(im.height * s)
    k = min(1, (S - M) / h2, (S - M) / w2); w2, h2 = round(w2 * k), round(h2 * k)
    im = im.resize((w2, h2), Image.LANCZOS)
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0)); out.paste(im, ((S - w2) // 2, S - M - h2), im)
    return out

# 1) 视频
for pose, src in CLIP_SRC.items():
    dst = f'{V}/loop/purple_{pose}.mp4'
    loop(f'{V}/{src}.mp4', dst)
    shutil.copy(dst, f'{CLIPS}/purple_{pose}.mp4')
for old in ['ball', 'study', 'paint']:
    p = f'{CLIPS}/purple_{old}.mp4'
    if os.path.exists(p): os.remove(p)
for extra in ['happy', 'shell']:
    loop(f'{V}/{extra}.mp4', f'{V}/loop/purple_{extra}.mp4'); shutil.copy(f'{V}/loop/purple_{extra}.mp4', f'{CLIPS}/purple_{extra}.mp4')

# 2) 表情静帧（先做 idle 拿参考身高）
keyed = {}
for name, src in EXPR.items():
    rgb = np.array(Image.open(f'{V}/expr/{src}.png').convert('RGB').resize((768, 768), Image.LANCZOS))
    keyed[name] = key(rgb)
x0, y0, x1, y1 = bbox(keyed['idle']); REF_H = y1 - y0 + 1
for name, a in keyed.items():
    write(name, place(a, REF_H))

# 3) 动作静帧：从原视频 1.0s 取一帧（全黑底）
fr = {}
for pose, src in CLIP_SRC.items():
    if pose == 'idle': continue
    p = f'{TMP}/{pose}.png'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', '1.0', '-i', f'{V}/{src}.mp4', '-frames:v', '1', '-vf', 'scale=768:768', p], check=True)
    fr[pose] = key(np.array(Image.open(p).convert('RGB')))
# 视频里的身高比例与静帧不同 → 用 idle 视频帧做该组的参考
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', '1.0', '-i', f'{V}/idle.mp4', '-frames:v', '1', '-vf', 'scale=768:768', f'{TMP}/idlev.png'], check=True)
iv = key(np.array(Image.open(f'{TMP}/idlev.png').convert('RGB'))); x0, y0, x1, y1 = bbox(iv); REF_HV = y1 - y0 + 1
for pose, a in fr.items():
    write(pose, place(a, REF_HV))
write('bath', place(fr['wash'], REF_HV))
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', '2.5', '-i', f'{V}/wake.mp4', '-frames:v', '1', '-vf', 'scale=768:768', f'{TMP}/yawn.png'], check=True)
write('yawn', place(key(np.array(Image.open(f'{TMP}/yawn.png').convert('RGB'))), REF_HV))

# 4) 探头帧：头 + 小手搭边（取上 58%），宽 324
def peek(a, name):
    x0, y0, x1, y1 = bbox(a); h = y1 - y0 + 1; yc = y0 + int(h * 0.58)
    m = a[y0:yc, :, 3] > 60; xs = np.where(m.any(axis=0))[0]
    im = Image.fromarray(a).crop((xs.min(), y0, xs.max() + 1, yc))
    im = im.resize((S, round(im.height * S / im.width)), Image.LANCZOS); write(name, im)
for old in glob.glob(f'{ASSETS}/purple_peek*.imageset'): shutil.rmtree(old)
peek(keyed['idle'], 'peek'); peek(keyed['blink'], 'peek_sleep')

# 5) 删除没有重做的旧设计资产（避免新旧混用）
keep = set(f'purple_{k}' for k in list(EXPR) + list(CLIP_SRC) + ['bath', 'yawn', 'peek', 'peek_sleep'])
for d in glob.glob(f'{ASSETS}/purple_*.imageset'):
    n = os.path.basename(d)[:-9]
    if n.startswith('purple_face_'): continue
    if n not in keep: shutil.rmtree(d); print('removed', n)
shutil.copy(f'{ASSETS}/purple_face_blink.imageset/purple_face_blink.png', f'{ASSETS}/purple_face_sleep.imageset/purple_face_sleep.png') if os.path.exists(f'{ASSETS}/purple_face_blink.imageset') else None
print('done', len(keep))
