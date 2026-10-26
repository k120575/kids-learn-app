# -*- coding: utf-8 -*-
"""
產生 App LOGO（吉祥物企企 + 呼應首頁的漸層圓角徽章），輸出：
  assets/icon/app_icon.png            1024x1024 完整徽章（legacy/iOS 用）
  assets/icon/app_icon_foreground.png 1024x1024 透明底、企企置中（Android adaptive 前景）
企企用 assets/images/mascot/wave.webp（去背插畫，與 App 內同一張），外加白色描邊
讓淺藍企鵝在藍色漸層上跳出來。
用法：python tool/gen_logo.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icon")

SZ = 1024

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


MASCOT = os.path.join(ROOT, "assets", "images", "mascot", "wave.webp")


def paste_mascot(base, ox, oy, s, outline=0.035):
    """把企企縮成 s×s 貼到 (ox,oy)，底下墊一圈白色描邊（寬 = s*outline）。"""
    pen = Image.open(MASCOT).convert("RGBA").resize((int(s), int(s)), Image.LANCZOS)
    r = max(1, int(s * outline))
    alpha = pen.getchannel("A").point(lambda a: 255 if a > 40 else 0)
    ring = alpha.filter(ImageFilter.MaxFilter(r * 2 + 1)).filter(ImageFilter.GaussianBlur(1.2))
    white = Image.new("RGBA", pen.size, (255, 255, 255, 255))
    white.putalpha(ring)
    base.alpha_composite(white, (int(ox), int(oy)))
    base.alpha_composite(pen, (int(ox), int(oy)))


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

    # 企企（插畫本身四周約留白 15%，所以框給大一點）
    s = SZ * 0.88
    paste_mascot(base, (SZ - s) / 2, SZ * 0.13, s)
    return base


def make_foreground():
    """Android adaptive 前景：透明底、企企置中（留安全邊距，避免被圓形遮罩裁切）。"""
    base = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    s = SZ * 0.72
    paste_mascot(base, (SZ - s) / 2, (SZ - s) / 2, s)
    return base


def main():
    os.makedirs(OUT, exist_ok=True)
    make_badge().save(os.path.join(OUT, "app_icon.png"))
    make_foreground().save(os.path.join(OUT, "app_icon_foreground.png"))
    print("LOGO 產生完成 →", OUT)


if __name__ == "__main__":
    main()
