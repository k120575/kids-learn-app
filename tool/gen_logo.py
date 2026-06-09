# -*- coding: utf-8 -*-
"""
產生 App LOGO（吉祥物企企 + 呼應首頁的漸層圓角徽章），輸出：
  assets/icon/app_icon.png            1024x1024 完整徽章（legacy/iOS 用）
  assets/icon/app_icon_foreground.png 1024x1024 透明底、企企置中（Android adaptive 前景）
畫風與 lib/core/widgets/penguin.dart 一致（同配色）。
用法：python tool/gen_logo.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icon")

SZ = 1024

# 企企配色（與 penguin.dart 一致）
DARK = (46, 58, 89, 255)
WHITE = (253, 253, 255, 255)
BEAK = (255, 178, 62, 255)
FOOT = (255, 159, 46, 255)
CHEEK = (255, 179, 193, 255)
EYE = (43, 43, 51, 255)

# 漸層停點（與 home_background.dart 一致）：紫 → 藍 → 黃
G0 = (179, 157, 219)
G1 = (144, 202, 249)
G2 = (255, 249, 196)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        if t < 0.5:
            c = lerp(G0, G1, t / 0.5)
        else:
            c = lerp(G1, G2, (t - 0.5) / 0.5)
        for x in range(size):
            px[x, y] = c
    return img


def star(d, cx, cy, r, fill, points=5):
    pts = []
    for i in range(points * 2):
        rr = r if i % 2 == 0 else r * 0.45
        a = -math.pi / 2 + i * math.pi / points
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=fill)


def rot_paste(base, draw_fn, pivot, deg):
    """在透明層上畫，繞 pivot 旋轉後合成回 base。"""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    layer = layer.rotate(deg, center=pivot, resample=Image.BICUBIC)
    base.alpha_composite(layer)


def draw_penguin(base, ox, oy, s):
    """依 penguin.dart 比例在 base(RGBA) 上畫企企。(ox,oy)=繪圖框左上, s=框邊長。"""
    cx = ox + s / 2

    def Y(f):
        return oy + s * f

    def X(f):
        return ox + s * f

    d = ImageDraw.Draw(base)

    # 腳
    for sign in (-1, 1):
        fx = cx + sign * s * 0.15
        d.polygon([
            (fx - s * 0.13, Y(0.99)), (fx - s * 0.045, Y(0.88)),
            (fx + s * 0.045, Y(0.88)), (fx + s * 0.13, Y(0.99)),
        ], fill=FOOT)

    # 翅膀（深色、往外張、旋轉）
    for sign in (-1, 1):
        pivot = (cx + sign * s * 0.37, Y(0.5))

        def wing(dd, sign=sign):
            wx, wy = cx + sign * s * 0.37, Y(0.5)
            dd.rounded_rectangle(
                [wx - s * 0.11, wy - s * 0.26, wx + s * 0.11, wy + s * 0.26],
                radius=s * 0.11, fill=DARK)
        rot_paste(base, wing, pivot, -sign * 31)  # 0.55 rad ≈ 31.5°

    d = ImageDraw.Draw(base)

    # 深色身體（頭罩＋背）
    d.ellipse([cx - s * 0.4, Y(0.54) - s * 0.45, cx + s * 0.4, Y(0.54) + s * 0.45],
              fill=DARK)

    # 呆毛
    d.polygon([(cx - s * 0.02, Y(0.12)), (cx + s * 0.1, Y(0.035)),
               (cx + s * 0.05, Y(0.15))], fill=DARK)

    # 白臉＋肚子
    d.ellipse([cx - s * 0.32, Y(0.66) - s * 0.31, cx + s * 0.32, Y(0.66) + s * 0.31],
              fill=WHITE)  # 肚子
    for sign in (-1, 1):
        ex = cx + sign * s * 0.15
        d.ellipse([ex - s * 0.165, Y(0.42) - s * 0.165,
                   ex + s * 0.165, Y(0.42) + s * 0.165], fill=WHITE)  # 臉

    # 粉臉頰
    for sign in (-1, 1):
        px = cx + sign * s * 0.24
        d.ellipse([px - s * 0.07, Y(0.5) - s * 0.05,
                   px + s * 0.07, Y(0.5) + s * 0.05], fill=CHEEK)

    # 眼睛（大、亮）
    for sign in (-1, 1):
        ex = cx + sign * s * 0.145
        ey = Y(0.43)
        d.ellipse([ex - s * 0.09, ey - s * 0.105, ex + s * 0.09, ey + s * 0.105],
                  fill=EYE)
        d.ellipse([ex + s * 0.035 - s * 0.034, ey - s * 0.04 - s * 0.034,
                   ex + s * 0.035 + s * 0.034, ey - s * 0.04 + s * 0.034],
                  fill=WHITE)
        d.ellipse([ex - s * 0.035 - s * 0.016, ey + s * 0.03 - s * 0.016,
                   ex - s * 0.035 + s * 0.016, ey + s * 0.03 + s * 0.016],
                  fill=WHITE)

    # 嘴（橘色小三角）
    d.polygon([(cx - s * 0.05, Y(0.5)), (cx + s * 0.05, Y(0.5)), (cx, Y(0.58))],
              fill=BEAK)


def make_badge():
    """完整徽章：漸層圓角底 + 星星裝飾 + 企企。"""
    base = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    # 漸層 + 圓角遮罩
    grad = gradient(SZ).convert("RGBA")
    mask = Image.new("L", (SZ, SZ), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SZ - 1, SZ - 1],
                                           radius=int(SZ * 0.23), fill=255)
    base.paste(grad, (0, 0), mask)

    d = ImageDraw.Draw(base)
    # 裝飾星星 / 小圓點
    star(d, SZ * 0.80, SZ * 0.20, SZ * 0.07, (255, 255, 255, 210))
    star(d, SZ * 0.18, SZ * 0.18, SZ * 0.045, (255, 255, 255, 170))
    star(d, SZ * 0.86, SZ * 0.52, SZ * 0.035, (255, 255, 255, 150))
    d.ellipse([SZ * 0.12, SZ * 0.40, SZ * 0.12 + 26, SZ * 0.40 + 26],
              fill=(255, 255, 255, 130))

    # 企企（置中偏下，佔約 0.62 高）
    s = SZ * 0.62
    draw_penguin(base, (SZ - s) / 2, SZ * 0.20, s)
    return base


def make_foreground():
    """Android adaptive 前景：透明底、企企置中（留安全邊距，避免被圓形遮罩裁切）。"""
    base = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    s = SZ * 0.52
    draw_penguin(base, (SZ - s) / 2, SZ * 0.26, s)
    return base


def main():
    os.makedirs(OUT, exist_ok=True)
    make_badge().save(os.path.join(OUT, "app_icon.png"))
    make_foreground().save(os.path.join(OUT, "app_icon_foreground.png"))
    print("LOGO 產生完成 →", OUT)


if __name__ == "__main__":
    main()
