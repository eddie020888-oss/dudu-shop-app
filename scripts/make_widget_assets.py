#!/usr/bin/env python3
"""灵动岛/锁屏用的小图：把 Pets.xcassets 复制到 IslandMeWidget/WidgetPets.xcassets，
大图缩小（全身 324→168，配饰同比例）。Live Activity 里图太大会显示成灰块。
改了 Pets.xcassets 里的图就重跑一次：python3 scripts/make_widget_assets.py"""
import os, shutil, sys
from PIL import Image
src, dst = "Pets.xcassets", "IslandMeWidget/WidgetPets.xcassets"
F = 168 / 324
if os.path.exists(dst): shutil.rmtree(dst)
shutil.copytree(src, dst)
n = 0
for root, _, files in os.walk(dst):
    for f in files:
        if not f.lower().endswith(".png"): continue
        p = os.path.join(root, f)
        im = Image.open(p)
        w, h = im.size
        if max(w, h) <= 168: continue
        nw, nh = max(1, round(w * F)), max(1, round(h * F))
        im.resize((nw, nh), Image.LANCZOS).save(p, optimize=True)
        n += 1
print("resized", n)
