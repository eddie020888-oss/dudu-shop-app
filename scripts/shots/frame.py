"""把模拟器截图做成商店图：1320×2868（6.9 英寸），上面一句大字，下面圆角截图。
用法：python3 frame.py <截图目录> <输出目录>"""
import sys, os, glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1320, 2868
CJK = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
CAP = {
 "zh-Hans": {"1_island": ("它住在你的灵动岛里", "你走路、上班、睡觉，它跟着变"),
             "2_kitchen": ("拖一拖，合成一桌好菜", "接外卖、做菜，它躺着收钱"),
             "3_story": ("嘟嘟星在变暗", "一单一单，把它的家乡点亮"),
             "4_nest": ("给它布置一个窝", "每个位置都有好几种款式"),
             "5_store": ("给它挑一件小配饰", "戴上以后，灵动岛里也看得到"),
             "6_map": ("十四个地方，等你点亮", "每章一张门那边来的小票"),
             "7_hotspring": ("八个地方，一件件装修", "厨房、茶室、观星台……下雪了还有温泉"),
             "8_games": ("陪它玩一局", "六个小游戏，赢了掉贴纸")},
 "en": {"1_island": ("It lives in your Dynamic Island", "Walk, work, sleep — it changes with you"),
        "2_kitchen": ("Merge, cook, serve", "You cook. It lies there collecting coins."),
        "3_story": ("Planet Dudu is going dark", "Light its home back up, one order at a time"),
        "4_nest": ("Decorate its nest", "Every spot has several styles"),
        "5_store": ("Pick a little accessory", "See it in the Dynamic Island too"),
        "6_map": ("14 places to light up", "A door order from home every chapter"),
        "7_hotspring": ("Renovate 8 cozy places", "Kitchen, tea room, rooftop… and a hot spring"),
        "8_games": ("Play a round together", "Six mini games — win stickers")},
}

def grad():
    top, bot = (58, 40, 104), (27, 21, 48)
    g = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / H
        g.putpixel((0, y), tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)))
    return g.resize((W, H))

def fit(draw, text, font_path, size, maxw):
    while size > 30:
        f = ImageFont.truetype(font_path, size)
        if draw.textlength(text, font=f) <= maxw: return f
        size -= 4
    return ImageFont.truetype(font_path, size)

def island_crop(path):
    """从切到别的 App 的截图里找灵动岛：每行最长的一段黑，长于 250px 的那些行就是岛"""
    im = Image.open(path).convert("RGB"); w, h = im.size; px = im.load()
    rows = []
    for y in range(5, 260):
        # 只看穿过屏幕正中的那一段黑（岛），不算左右的时间和电量
        cx = w // 2
        def dark(x): r, g, b = px[x, y]; return r < 20 and g < 20 and b < 20
        if not dark(cx): continue
        a = cx; b2 = cx
        while a > 0 and dark(a - 1): a -= 1
        while b2 < w - 1 and dark(b2 + 1): b2 += 1
        if b2 - a > 250 and (a > 20 or b2 < w - 20): rows.append((y, a, b2))
    if not rows: return None
    y0, y1 = rows[0][0], rows[-1][0]
    x0 = min(r[1] for r in rows); x1 = max(r[2] for r in rows)
    return im.crop((x0, y0, x1 + 1, y1 + 1))

def make(src, lang, key, out, island=None):
    title, sub = CAP[lang][key]
    bg = grad(); d = ImageDraw.Draw(bg)
    # 柔光
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0)); gd = ImageDraw.Draw(glow)
    gd.ellipse((W * 0.15, 120, W * 0.85, 760), fill=(201, 167, 255, 70)); glow = glow.filter(ImageFilter.GaussianBlur(120))
    bg.paste(glow, (0, 0), glow)
    d = ImageDraw.Draw(bg)
    ft = fit(d, title, CJK, 108, W - 140); fs = fit(d, sub, CJK, 56, W - 160)
    d.text((W / 2, 250), title, font=ft, fill=(255, 255, 255), anchor="mm")
    d.text((W / 2, 380), sub, font=fs, fill=(205, 192, 240), anchor="mm")
    shot = Image.open(src).convert("RGB")
    sw = int(W * 0.80); sh = int(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    r = 70
    mask = Image.new("L", (sw, sh), 0); ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw, sh), r, fill=255)
    x, y = (W - sw) // 2, 500
    # 阴影 + 描边
    sh_img = Image.new("RGBA", (W, H), (0, 0, 0, 0)); sd = ImageDraw.Draw(sh_img)
    sd.rounded_rectangle((x - 10, y + 10, x + sw + 10, y + sh + 30), r + 10, fill=(0, 0, 0, 140))
    sh_img = sh_img.filter(ImageFilter.GaussianBlur(30)); bg.paste(sh_img, (0, 0), sh_img)
    bg.paste(shot, (x, y), mask)
    ImageDraw.Draw(bg).rounded_rectangle((x - 3, y - 3, x + sw + 3, y + sh + 3), r + 3, outline=(201, 167, 255), width=6)
    if island is not None:
        # 灵动岛放大浮在截图上方：一眼看到「它在岛里」
        iw = int(W * 0.86); ih = int(island.height * iw / island.width)
        isl = island.resize((iw, ih), Image.LANCZOS)
        m = Image.new("L", isl.size, 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, iw, ih), ih // 2, fill=255)
        ix, iy = (W - iw) // 2, 470
        gl = Image.new("RGBA", (W, H), (0, 0, 0, 0)); ImageDraw.Draw(gl).rounded_rectangle((ix - 20, iy - 10, ix + iw + 20, iy + ih + 30), ih // 2, fill=(201, 167, 255, 120))
        gl = gl.filter(ImageFilter.GaussianBlur(28)); bg.paste(gl, (0, 0), gl)
        bg.paste(isl, (ix, iy), m)
    bg.save(out, quality=95)

if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]; os.makedirs(dst, exist_ok=True)
    for lang in CAP:
        for key in CAP[lang]:
            if key == "1_island":
                p = os.path.join(src, f"{lang}_1_home.png"); ip = os.path.join(src, f"{lang}_7_island.png")
                if os.path.exists(p) and os.path.exists(ip):
                    isl = island_crop(ip)
                    if isl is not None and isl.width > 600:
                        make(p, lang, key, os.path.join(dst, f"{lang}_{key}.png"), island=isl); print("ok", lang, key)
                    else: print("island too small", lang, isl.size if isl else None)
                continue
            p = os.path.join(src, f"{lang}_{key}.png")
            if os.path.exists(p):
                make(p, lang, key, os.path.join(dst, f"{lang}_{key}.png")); print("ok", lang, key)
