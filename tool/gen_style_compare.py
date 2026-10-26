# -*- coding: utf-8 -*-
"""
風格二選一對照：現有關卡的扁平繪本風（gen_art.py 的 STYLE）vs 黏土 3D。
補畫：扁平風的小企鵝、蘋果、語文/音樂圖示，以及黏土風的小企鵝（共 5 張）。
黏土的蘋果/圖示沿用 gen_style_samples.py 已產出的圖。

產出到 docs/style_proposal/compare/，並生成 docs/style_proposal/compare.html。
用法：python tool/gen_style_compare.py [--force]
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_style_samples import FORCE, MODEL, NO_TEXT, OUT, STYLES, gen_one, save  # noqa: E402

# 與 tool/gen_art.py 相同的風格描述，確保跟現有關卡圖一致
FLAT = ("Flat children's storybook illustration style, simple rounded shapes, "
        "bright cheerful saturated colors, soft shadows, adorable kawaii, "
        "for a preschool learning app.")
FLAT_FRAME = ("Set the single subject inside a glossy circular medallion badge "
              "with a thin white rim and a soft {bg} background, centered, fills the circle.")
CLAY = STYLES[0][3]
WHITE = "isolated on a plain pure white background"

PENGUIN = ("A cute chubby little baby penguin mascot character waving hello with one flipper, "
           "big sparkly friendly eyes, rosy cheeks, small orange beak and feet, wearing a small "
           "explorer backpack, full body, front three-quarter view, centered")

JOBS = [
    ("flat_penguin", f"{PENGUIN}, {WHITE}. {FLAT} {NO_TEXT}"),
    ("flat_apple", "A single shiny red apple with one green leaf, simple and instantly "
                   f"recognizable, centered, {WHITE}. {FLAT} {NO_TEXT}"),
    ("flat_icon_language", "An open picture book with a speech bubble floating above it. "
                           f"{FLAT_FRAME.format(bg='mint green')} {FLAT} {NO_TEXT}"),
    ("flat_icon_music", "A small toy drum with drumsticks and two floating music notes. "
                        f"{FLAT_FRAME.format(bg='lavender purple')} {FLAT} {NO_TEXT}"),
    ("clay_penguin", f"{PENGUIN}, {WHITE}. {CLAY} {NO_TEXT}"),
]

ROWS = [
    ("扁平繪本（沿用現有關卡風）",
     [("compare/flat_penguin", "小企鵝"), ("compare/flat_apple", "蘋果"),
      ("compare/flat_icon_language", "語文"), ("compare/flat_icon_music", "音樂")],
     "../../assets/images/park_bg.png", "現有遊樂園背景"),
    ("黏土 3D",
     [("compare/clay_penguin", "小企鵝"), ("clay/item_apple", "蘋果"),
      ("clay/icon_language", "語文"), ("clay/icon_music", "音樂")],
     "clay/home_bg.webp", "黏土樣稿背景"),
]

EXISTING = ["storyhouse", "ferris", "castle", "planet_music", "magic_spell"]


def write_html():
    sections = []
    for title, tiles, bg, bg_label in ROWS:
        cells = "".join(
            f'<figure><img src="{p if "." in p.rsplit("/", 1)[-1] else p + ".webp"}" alt="{l}">'
            f'<figcaption>{l}</figcaption></figure>' for p, l in tiles)
        sections.append(
            f'<section><h2>{title}</h2><div class="grid">{cells}</div>'
            f'<figure class="bg"><img src="{bg}" alt="{bg_label}">'
            f'<figcaption>{bg_label}</figcaption></figure></section>')
    existing = "".join(
        f'<figure><img src="../../assets/images/{n}.png" alt="{n}"></figure>' for n in EXISTING)
    html = f"""<!doctype html>
<html lang="zh-Hant"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>風格二選一</title>
<style>
:root{{--bg:#fbf8f3;--fg:#2b2b2b;--muted:#6b6b6b;--card:#fff;--line:#e8e2d8}}
@media (prefers-color-scheme:dark){{:root{{--bg:#1d1c1a;--fg:#eee;--muted:#aaa;--card:#2a2926;--line:#3a3833}}}}
body{{margin:0;background:var(--bg);color:var(--fg);font-family:system-ui,"Noto Sans TC",sans-serif}}
main{{max-width:1100px;margin:0 auto;padding:24px 16px 64px}}
h1{{margin:0 0 4px}} .sub{{color:var(--muted);margin:0 0 28px}}
section{{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:20px;margin-bottom:24px}}
h2{{margin:0 0 14px}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px}}
figure{{margin:0;text-align:center}} figure img{{width:100%;height:auto;border-radius:12px;background:#fff}}
figcaption{{font-size:14px;color:var(--muted);margin-top:6px}}
.bg{{margin-top:14px}}
</style></head><body><main>
<h1>寶貝學習樂園｜扁平繪本 vs 黏土 3D</h1>
<p class="sub">同樣的題材（小企鵝、蘋果、語文、音樂）用兩種風格並排。（{MODEL}）</p>
{''.join(sections)}
<section><h2>參考：現有關卡圖</h2><div class="grid">{existing}</div></section>
</main></body></html>"""
    with open(os.path.join(OUT, "compare.html"), "w", encoding="utf-8") as f:
        f.write(html)


def main():
    os.makedirs(os.path.join(OUT, "compare"), exist_ok=True)
    fail = []
    for name, prompt in JOBS:
        final = os.path.join(OUT, "compare", name + ".webp")
        if os.path.exists(final) and not FORCE:
            print("skip", name)
            continue
        print("gen", name, "...")
        data = gen_one(prompt)
        if not data:
            print("  FAILED", name)
            fail.append(name)
            continue
        save(data, final, "tile")
        print("  saved", final)
        time.sleep(2)  # 緩一下，降低限流
    write_html()
    print(f"完成，失敗 {len(fail)} {fail}")


if __name__ == "__main__":
    main()
