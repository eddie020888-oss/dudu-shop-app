#!/usr/bin/env python3
"""找最佳循环点：首尾最像的两帧之间截取，短交叉淡化；还是不像就做来回播放（boomerang）。
用法: bestloop.py src.mp4 dst.mp4  → 打印选用方式与差异"""
import sys, subprocess, numpy as np
src, dst = sys.argv[1], sys.argv[2]
raw = subprocess.check_output(['ffmpeg','-v','error','-i',src,'-vf','fps=24,scale=96:96,format=gray','-f','rawvideo','-'])
F = np.frombuffer(raw, np.uint8).reshape(-1, 96, 96).astype(np.float32)
n = len(F); best = (1e9, 0, n-1)
for i in range(0, min(36, n)):                 # 起点：前 1.5 秒
    for j in range(max(i + 60, n - 48), n):     # 终点：后 2 秒内，且至少 2.5 秒长
        d = np.abs(F[i] - F[j]).mean()
        if d < best[0]: best = (d, i, j)
d, i, j = best
enc = ['-an','-c:v','libx264','-crf','24','-preset','slow','-movflags','+faststart','-pix_fmt','yuv420p']
if d <= 7:
    t0, t1 = i/24, j/24; L = t1 - t0; X = 0.25
    fc = (f"[0:v]fps=24,scale=512:512,trim={t0:.4f}:{t1:.4f},setpts=PTS-STARTPTS,split[x][y];"
          f"[x]trim=start={X},setpts=PTS-STARTPTS[a];[y]trim=0:{X},setpts=PTS-STARTPTS[b];"
          f"[a][b]xfade=transition=fade:duration={X}:offset={L-2*X:.4f}[v]")
    mode = 'cut'
else:
    t0 = i/24
    fc = (f"[0:v]fps=24,scale=512:512,trim=start={t0:.4f},setpts=PTS-STARTPTS,split[x][y];"
          f"[y]reverse,trim=start=0.042,setpts=PTS-STARTPTS[r];[x][r]concat=n=2:v=1:a=0[v]")
    mode = 'boomerang'
subprocess.run(['ffmpeg','-v','error','-y','-i',src,'-filter_complex',fc,'-map','[v]']+enc+[dst], check=True)
print(f'{mode} diff={d:.1f} {i/24:.2f}-{j/24:.2f}s')
