# -*- coding: utf-8 -*-
"""
把生圖的白底去背成透明（就地覆寫 .webp；白底原圖先備份到 tool/art_raw/，已 gitignore，
之後要換規則重新去背就從那裡拿，不必重新生圖）。

rembg 會把主體內部的大片白色（企鵝的白臉、白肚子、卷軸紙面）判成半透明，所以：
1. rembg（isnet-general-use）算出 alpha，順便去掉地面軟陰影；
2. alpha > KEEP_ALPHA 視為主體、填實內部孔洞（OPEN_HOLES 名單除外），往內縮 EDGE 像素後一律不透明，
   只在最外圈保留 rembg 的柔邊（反鋸齒）。
3. 裁掉透明邊、置中補成正方形（四周留 MARGIN），讓每張主體都撐滿畫面，
   放進卡片時大小一致。

已去背的舊圖只想重裁：python tool/cutout.py --trim-only <目錄>...

用法：python tool/cutout.py assets/images/icons assets/images/mascot
已有透明度的圖會跳過（加 --force 重做）。需要：pip install "rembg[cpu]"
"""
import os
import sys

import numpy as np
from PIL import Image
from rembg import new_session, remove
from scipy import ndimage

FORCE = "--force" in sys.argv
TRIM_ONLY = "--trim-only" in sys.argv
KEEP_ALPHA = 25    # rembg alpha 高於此值算主體（白肚子約落在 40~150）
EDGE = 2           # 外圈保留柔邊的寬度（px）
# 中間本來就鏤空的物件：不填洞（否則圈圈、輪輻間會變白色實心）。
# 白肚子和鏤空背景在 rembg alpha、顏色上都分不出來，只能列名單。
OPEN_HOLES = {"roller_coaster", "ferris_wheel"}
MARGIN = 0.05      # 裁切後四周留白比例
SIZE = 512
RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_raw")


def has_alpha(im):
    return im.mode == "RGBA" and im.getchannel("A").getextrema()[0] < 255


def cutout(im, session, open_holes=False):
    alpha = np.asarray(remove(im.convert("RGB"), session=session).getchannel("A")).copy()
    solid = alpha > KEEP_ALPHA
    if not open_holes:
        solid = ndimage.binary_fill_holes(solid)
    alpha[ndimage.binary_erosion(solid, iterations=EDGE)] = 255
    out = im.convert("RGBA")
    out.putalpha(Image.fromarray(alpha))
    return trim(out)


def trim(im):
    box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if box:
        im = im.crop(box)
    side = round(max(im.size) / (1 - 2 * MARGIN))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    dirs = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not dirs:
        sys.exit(__doc__)
    session = None if TRIM_ONLY else new_session("isnet-general-use")
    for d in dirs:
        for name in sorted(os.listdir(d)):
            if not name.endswith(".webp"):
                continue
            path = os.path.join(d, name)
            im = Image.open(path)
            if TRIM_ONLY:
                trim(im.convert("RGBA")).save(path, "WEBP", quality=90)
                print("trim", path)
                continue
            if has_alpha(im) and not FORCE:
                print("skip", path)
                continue
            raw = os.path.join(RAW, os.path.basename(os.path.normpath(d)), name)
            if not os.path.exists(raw):
                os.makedirs(os.path.dirname(raw), exist_ok=True)
                im.save(raw, "WEBP", lossless=True)
            stem = os.path.splitext(name)[0]
            cutout(im, session, stem in OPEN_HOLES).save(path, "WEBP", quality=90)
            print("cut", path)


if __name__ == "__main__":
    main()
