# -*- coding: utf-8 -*-
"""
把彩色 emoji 字型 NotoColorEmoji subset 成「只留 emoji、拿掉 ASCII」。

背景：App 用 NotoColorEmoji 當全域字型 fallback（assets/fonts/NotoColorEmoji.ttf），
確保各裝置 emoji 顯示一致。但這支字型的 cmap 含 ASCII 0-9（給 1️⃣ 之類 keycap 用），
當它在 fallback 時，Flutter 會用它來畫一般數字 → 「3-4」變成寬間距的 emoji 數字。

解法：移除 0x20–0x7F（ASCII）字符，這樣它無法提供一般數字/英文，
那些字就回到正常文字字型；真正的 emoji（皆 > 0x7F，含 ZWJ/變異選擇子）全保留。
被拿掉的 keycap（如 7️⃣）會自動退回系統字型顯示，不受影響。

來源字型（OFL/Apache，可再散布）：
  https://github.com/googlefonts/noto-emoji/raw/main/fonts/NotoColorEmoji.ttf
（CBDT 點陣彩色版，Flutter/Skia 對 CBDT 支援最穩）

用法：
  python tool/subset_emoji_font.py [輸入.ttf] [輸出.ttf]
  預設就地處理 assets/fonts/NotoColorEmoji.ttf（idempotent，重跑無害）。
"""
import sys

from fontTools.ttLib import TTFont
from fontTools import subset

DEFAULT = "assets/fonts/NotoColorEmoji.ttf"


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    out = sys.argv[2] if len(sys.argv) > 2 else (src + ".subset.tmp")

    font = TTFont(src)
    codepoints = set()
    for table in font["cmap"].tables:
        codepoints.update(table.cmap.keys())
    # 保留所有非 ASCII 字符（emoji 都 > 0x7F；ZWJ 0x200D、變異選擇子 0xFE0F 也都保留）。
    keep = sorted(u for u in codepoints if not (0x20 <= u <= 0x7F))

    opts = subset.Options()
    opts.layout_features = ["*"]   # 保留 GSUB：emoji ZWJ 連字序列需要
    opts.name_IDs = ["*"]
    opts.glyph_names = True
    opts.notdef_outline = True
    opts.recalc_timestamp = False
    opts.drop_tables = []          # 不要丟表（保留 CBDT/CBLC 彩色點陣）

    ss = subset.Subsetter(options=opts)
    ss.populate(unicodes=keep)
    ss.subset(font)
    font.save(out)
    print(f"subset done: kept {len(keep)} codepoints -> {out}")


if __name__ == "__main__":
    main()
