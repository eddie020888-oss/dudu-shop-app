"""嘟嘟小店背景音乐：代码合成的循环小曲（八音盒 + 软钢琴 + 贝斯 + 沙锤），无版权问题。
python3 scripts/sfx/bgm.py  → IslandMe/Resources/Sfx/bgm_shop.m4a
风格：慵懒、温暖、像午后小店；88 BPM，F 大调，16 小节循环（首尾无缝）。"""
import numpy as np, os, subprocess, wave
from scipy.signal import fftconvolve

SR = 44100
BPM = 88
BEAT = 60 / BPM
BARS = 16
N = int(SR * BEAT * 4 * BARS)
R = np.random.default_rng(7)
OUT = os.path.join(os.path.dirname(__file__), "../../IslandMe/Resources/Sfx")

def hz(m): return 440 * 2 ** ((m - 69) / 12)
def env(n, a, d):
    t = np.arange(n) / SR
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / d)

mix = np.zeros(N + SR * 3)
def add(sig, t, gain):
    i = int(t * SR); mix[i:i + len(sig)] += sig * gain

def musicbox(m, dur=1.6):
    n = int(SR * dur); t = np.arange(n) / SR; f = hz(m)
    s = np.sin(2*np.pi*f*t) * env(n, 0.002, 0.55)
    s += 0.25 * np.sin(2*np.pi*f*3.0*t) * env(n, 0.001, 0.12)
    s += 0.10 * np.sin(2*np.pi*f*5.04*t) * env(n, 0.001, 0.05)
    return s
def epiano(m, dur=1.2):
    n = int(SR * dur); t = np.arange(n) / SR; f = hz(m)
    s = np.sin(2*np.pi*f*t + 0.8*np.sin(2*np.pi*f*t) * np.exp(-t/0.3)) * env(n, 0.004, 0.7)
    return s
def pad(ms, dur):
    n = int(SR * dur); t = np.arange(n) / SR
    s = sum(np.sin(2*np.pi*hz(m)*t*(1+d)) for m in ms for d in (-0.002, 0.002))
    a = np.minimum(1, t / 0.6) * np.minimum(1, (dur - t) / 0.6)
    return s * a
def bass(m, dur):
    n = int(SR * dur); t = np.arange(n) / SR; f = hz(m)
    return (np.sin(2*np.pi*f*t) + 0.2*np.sin(2*np.pi*2*f*t)) * env(n, 0.01, 0.5)
def shaker(dur=0.08):
    n = int(SR * dur); x = R.standard_normal(n)
    x = np.diff(np.concatenate([[0], x]))      # 偏高频
    return x * env(n, 0.003, 0.02)
def kick():
    n = int(SR * 0.25); t = np.arange(n) / SR
    f = 50 + 70 * np.exp(-t / 0.03)
    return np.sin(2*np.pi*np.cumsum(f)/SR) * env(n, 0.001, 0.09)

# 和弦（MIDI）：Fmaj7 Dm7 Bbmaj7 C7sus4 ×2，后半 Gm7 C7 Am7 Dm7 → Bbmaj7 C Fmaj7 Fmaj7
CH = [[53,57,60,64],[50,53,57,60],[46,50,53,57],[48,53,55,58],
      [53,57,60,64],[50,53,57,60],[46,50,53,57],[48,53,55,58],
      [55,58,62,65],[48,52,55,58],[57,60,64,67],[50,53,57,60],
      [46,50,53,57],[48,52,55,58],[53,57,60,64],[53,57,60,64]]
# 旋律（八音盒，每小节 8 个八分音符，0 = 休止），F 大调五声
MEL = [
 [72,0,69,0,72,74,0,0],[69,0,67,0,65,0,0,0],[65,0,67,69,0,67,0,0],[67,0,0,0,0,0,0,0],
 [72,0,69,0,72,74,76,0],[74,0,72,0,69,0,0,0],[65,67,69,0,72,0,69,0],[67,0,0,0,65,0,0,0],
 [74,0,72,0,70,0,69,0],[67,0,64,0,67,0,0,0],[69,0,72,0,76,0,74,72],[69,0,0,0,0,0,0,0],
 [70,0,69,0,65,0,62,0],[64,0,67,0,72,0,0,0],[69,0,0,0,67,0,65,0],[65,0,0,0,0,0,0,0],
]
swing = BEAT * 0.08
for b in range(BARS):
    t0 = b * 4 * BEAT
    ch = CH[b]
    add(pad([m + 12 for m in ch[1:]], 4 * BEAT + 0.3), t0, 0.035)
    add(bass(ch[0] - 12, 2 * BEAT), t0, 0.32)
    add(bass(ch[0] - 12 + (7 if b % 2 else 0), 2 * BEAT), t0 + 2 * BEAT, 0.26)
    # 软钢琴：分解和弦（第 1、2.5、3.5 拍）
    for k, beat in enumerate([0, 1.5, 2.5, 3.5]):
        add(epiano(ch[(k + 1) % 4] + 12, 1.0), t0 + beat * BEAT, 0.09)
    # 八音盒旋律（摇摆一点）
    for k, m in enumerate(MEL[b]):
        if m: add(musicbox(m + 12), t0 + k * BEAT / 2 + (swing if k % 2 else 0), 0.16)
    # 打击：很轻
    for k in range(8):
        add(shaker(), t0 + k * BEAT / 2 + (swing if k % 2 else 0), 0.035 if k % 2 else 0.02)
    for beat in (0, 2):
        add(kick(), t0 + beat * BEAT, 0.18)

# 混响：衰减噪声当冲激响应
ir_n = int(SR * 1.4)
ir = R.standard_normal(ir_n) * np.exp(-np.arange(ir_n) / SR / 0.35)
ir[0] = 0
wet = fftconvolve(mix, ir)[:len(mix)]
wet /= np.max(np.abs(wet)) + 1e-9
dry = mix / (np.max(np.abs(mix)) + 1e-9)
y = dry * 0.85 + wet * 0.22
# 无缝循环：把超出的尾巴叠回开头
loop = y[:N].copy()
tail = y[N:]
loop[:len(tail)] += tail
loop /= np.max(np.abs(loop)) + 1e-9
loop *= 0.7
wav = os.path.join(OUT, "_bgm.wav")
with wave.open(wav, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((loop * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "aac", "-b:a", "96k", os.path.join(OUT, "bgm_shop.m4a")], check=True)
os.remove(wav)
print("bgm", N / SR, "s")
