"""嘟嘟小店音效：全部用代码合成（不用素材，没有版权问题）。python3 scripts/sfx/make.py
风格：软、圆、像木琴/八音盒，音量不刺耳。"""
import numpy as np, wave, os
SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "../../IslandMe/Resources/Sfx")
def env(n, a=0.004, d=0.25):
    t = np.arange(n) / SR
    e = np.minimum(1, t / a) * np.exp(-t / d)
    return e
def bell(f, dur=0.45, d=0.18, bright=0.35):
    n = int(SR * dur); t = np.arange(n) / SR
    # 木琴/八音盒：基音 + 少量 4 倍、10 倍泛音（泛音衰减更快）
    s = np.sin(2*np.pi*f*t) * env(n, 0.002, d)
    s += bright * np.sin(2*np.pi*f*4.0*t) * env(n, 0.001, d*0.35)
    s += bright*0.4 * np.sin(2*np.pi*f*10.0*t) * env(n, 0.001, d*0.15)
    return s
def pop(f0=520, f1=260, dur=0.12):
    n = int(SR * dur); t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t / 0.025)
    ph = 2*np.pi*np.cumsum(f)/SR
    return np.sin(ph) * env(n, 0.001, 0.04)
def save(name, s, gain=0.55):
    s = s / (np.max(np.abs(s)) + 1e-9) * gain
    fade = int(SR*0.01); s[-fade:] *= np.linspace(1, 0, fade)
    d = (s * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes())
def mix(*parts):
    n = max(len(p) + o for p, o in parts); out = np.zeros(n)
    for p, o in parts: out[o:o+len(p)] += p
    return out
ms = lambda x: int(SR * x / 1000)
# 合成：一声「啵」+ 一个音，连击时音一级一级往上走（五声音阶，怎么连都好听）
PENTA = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]
base = 523.25  # C5
for k, semi in enumerate(PENTA):
    f = base * 2 ** (semi / 12)
    save(f"merge{k}", mix((pop(700, 300), 0), (bell(f, 0.5, 0.16), ms(18))), 0.5)
# 高级合成（6 级以上）：三个音的小琶音
f = base
save("merge_big", mix((pop(800, 300), 0), (bell(f*2**(4/12), 0.6, 0.2), ms(10)), (bell(f*2**(7/12), 0.6, 0.2), ms(80)), (bell(f*2, 0.9, 0.3), ms(150))), 0.55)
# 顶级 / 新发现：更长的闪光
save("discover", mix(*[(bell(base*2**(s/12), 0.9, 0.28, 0.5), ms(i*70)) for i, s in enumerate([7, 12, 16, 19, 24])]), 0.5)
# 产出器点一下：软软的「噗」
save("tap", pop(380, 180, 0.09), 0.35)
# 交单：两声硬币叮
save("coin", mix((bell(1318.5, 0.35, 0.10, 0.6), 0), (bell(1975.5, 0.5, 0.16, 0.6), ms(70))), 0.45)
# 放进厨具 / 开始做菜
save("cook", mix((pop(300, 160, 0.14), 0), (bell(659.25, 0.4, 0.12, 0.2), ms(30))), 0.45)
# 纸箱打开
save("box", mix((pop(240, 120, 0.15), 0), (bell(880, 0.35, 0.1, 0.3), ms(40))), 0.4)
# 2026-10-20 补齐
# 出锅：叮—叮（像烤箱好了）
save("cookdone", mix((bell(1046.5, 0.5, 0.18, 0.5), 0), (bell(1318.5, 0.7, 0.25, 0.5), ms(140))), 0.45)
# 装修完成：上行琶音 + 闪光尾巴
save("renovate", mix(*[(bell(base*2**(s/12), 1.0, 0.32, 0.45), ms(i*90)) for i, s in enumerate([0, 4, 7, 12, 16, 19, 24])]), 0.5)
# 领奖励：两个音往上
save("reward", mix((bell(783.99, 0.5, 0.16, 0.4), 0), (bell(1174.66, 0.7, 0.24, 0.4), ms(90))), 0.45)
# 按钮：很轻的「嗒」
save("button", pop(900, 600, 0.04), 0.25)
# 拖错了：低低的两声「啵～啵」往下走
save("boop", mix((pop(330, 220, 0.11), 0), (pop(260, 160, 0.12), ms(90))), 0.4)
# 翻卡：一阵风 + 一声叮
def swish(dur=0.22):
    n = int(SR*dur); x = np.random.default_rng(3).standard_normal(n); t = np.arange(n)/SR
    return x * np.sin(np.pi*t/dur)**2 * 0.6
save("flip", mix((swish(), 0), (bell(1567.98, 0.5, 0.15, 0.6), ms(170))), 0.4)
# 宝箱抖动：咔哒咔哒
save("rattle", mix(*[(pop(500 + 80*(i % 2), 300, 0.05), ms(i*70)) for i in range(5)]), 0.35)
print(sorted(os.listdir(OUT)))
