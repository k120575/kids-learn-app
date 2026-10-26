# -*- coding: utf-8 -*-
"""
第 1 批「門面」：關卡入口圖示 + 首頁年齡/獎勵按鈕（扁平繪本風，同 gen_art.py 的 STYLE）。
取代 registry.dart 的 GameDef.emoji 等；跨年齡同玩法共用一張（GAME_ICON 對照）。

白底單一主體，之後去背再放進各領域色卡片。年齡選擇用吉祥物小企鵝的成長階段
（以 assets/images/mascot/wave.webp 為參考圖，保持同一角色）。

產出到 assets/images/icons/，並生成 docs/style_proposal/icons.html 審圖頁。
用法：python tool/gen_game_icons.py [--force]
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_mascot as gm  # noqa: E402
import gen_style_samples as gs  # noqa: E402

OUT = os.path.join(gs.ROOT, "assets", "images", "icons")
STYLE = gm.STYLE
WHITE = ("single subject, centered, filling most of the frame, isolated on a plain pure "
         "white background")

# GameDef.id → 圖示鍵（同玩法跨年齡共用）
GAME_ICON = {
    "listen_point": "listen_point", "listen_point_45": "listen_point",
    "sound_hunt": "sound_hunt",
    "read_aloud_34": "read_aloud", "read_aloud_45": "read_aloud",
    "count_tap": "count_tap",
    "color_sort": "color_sort",
    "advanced_sort": "advanced_sort", "advanced_sort_45": "advanced_sort",
    "shape_match": "shape_match",
    "house_puzzle": "puzzle", "puzzle_56": "puzzle",
    "maze": "maze", "maze_hard": "maze",
    "instrument_pick": "instrument", "instrument_45": "instrument",
    "tempo_34": "tempo",
    "pitch_hilo_34": "pitch_hilo",
    "find_same_34": "find_same",
    "whats_missing_34": "whats_missing",
    "next_in_row_34": "next_in_row",
    "arithmetic": "arithmetic", "arithmetic_56": "arithmetic",
    "compare": "compare", "compare_56": "compare",
    "block_copy_45": "block_copy",
    "tangram_45": "tangram",
    "memory": "memory", "memory_56": "memory",
    "spot_diff": "spot_diff",
    "pattern": "pattern", "pattern_56": "pattern",
    "odd_one_out": "odd_one_out", "odd_one_out_56": "odd_one_out",
    "opposites": "opposites",
    "hanzi_read": "hanzi", "hanzi_56": "hanzi",
    "zhuyin_onset": "zhuyin", "zhuyin_56": "zhuyin",
    "dynamics_45": "dynamics",
    "duration_45": "duration",
    "measure_56": "measure",
    "multiply_56": "multiply",
    "symmetry_56": "symmetry",
    "rotate_match_56": "rotate_match",
    "sound_memory_56": "sound_memory",
    "tuning_56": "tuning",
    "direction_56": "direction",
    "sudoku_56": "sudoku",
}

# (圖示鍵, 中文, 領域, 題材)
ICONS = [
    # 語文
    ("listen_point", "聽音指圖", "語文", "A big friendly cartoon ear next to a small picture card of a cat, with soft sound waves"),
    ("sound_hunt", "聲音尋寶", "語文", "A small treasure chest bursting open with musical sound waves and sparkles coming out"),
    ("read_aloud", "跟我念", "語文", "A cute open mouth speech bubble beside a small microphone"),
    ("odd_one_out", "找不同類", "語文", "A wicker basket holding three red apples and one blue toy car sticking out"),
    ("opposites", "反義詞", "語文", "A big elephant and a tiny mouse standing face to face, smiling"),
    ("hanzi", "認國字", "語文", "A Chinese calligraphy ink brush resting on a rolled paper scroll with an ink stone"),
    ("zhuyin", "注音", "語文", "A stack of three colorful wooden toy blocks with blank faces next to a small ringing bell"),
    ("measure", "量詞高手", "語文", "A cardboard box, a stack of books and a bunch of bananas lined up neatly"),
    # 邏輯數學
    ("count_tap", "數數點點", "邏輯數學", "Five round colorful candies in a row with a little pointing finger tapping one"),
    ("color_sort", "顏色分類", "邏輯數學", "Three small buckets in red, yellow and blue, each holding balls of the same color"),
    ("advanced_sort", "進階分類", "邏輯數學", "Colorful shapes (circles, triangles, squares) sorted into a three-compartment tray"),
    ("arithmetic", "加減法", "邏輯數學", "Two small groups of strawberries joined by a big chunky plus shape made of candy"),
    ("compare", "比大小", "邏輯數學", "A cute balance scale with a big watermelon on one side and a small cherry on the other"),
    ("multiply", "乘法魔法", "邏輯數學", "A magic wand sparkling above a perfectly aligned grid of 3 rows by 3 columns of identical golden stars, evenly spaced like a multiplication array"),
    # 空間
    ("shape_match", "形狀配對", "空間", "A wooden shape sorter board with circle, triangle and square holes and matching pieces"),
    ("puzzle", "拼圖", "空間", "Four colorful jigsaw puzzle pieces almost fitted together with one piece floating in"),
    ("maze", "走迷宮", "空間", "A small round maze seen from above with a cute mouse at the entrance and cheese at the center"),
    ("block_copy", "積木照樣蓋", "空間", "Two identical small towers of colorful toy building blocks side by side"),
    ("tangram", "拼出圖形", "空間", "Colorful tangram pieces arranged into the shape of a little house"),
    ("symmetry", "對稱鏡像", "空間", "A colorful butterfly with perfectly symmetrical wings"),
    ("rotate_match", "轉轉看", "空間", "A colorful toy block shape with a curved circular arrow spinning around it"),
    # 音樂
    ("instrument", "樂器配對", "音樂", "A small trumpet, a tambourine and a little drum grouped together"),
    ("tempo", "快快慢慢", "音樂", "A running bunny and a slow smiling turtle side by side"),
    ("pitch_hilo", "高高低低", "音樂", "A little bird high on a branch and a frog low on a lily pad, with musical notes"),
    ("dynamics", "大聲小聲", "音樂", "A roaring cute lion cub next to a tiny whispering mouse"),
    ("duration", "音的長短", "音樂", "A long ribbon-like musical note next to a short bouncy musical note"),
    ("sound_memory", "音波記憶", "音樂", "Colorful glowing sound wave lines coming out of a small speaker, with a light bulb"),
    ("tuning", "這首對嗎", "音樂", "A small toy xylophone with a mallet and a sparkle on one bar"),
    ("direction", "音往哪裡走", "音樂", "A staircase of colorful musical notes stepping upward, with a little bird hopping up the steps"),
    # 動腦
    ("find_same", "找一樣", "動腦", "Two identical cute ladybugs side by side with a magnifying glass"),
    ("whats_missing", "什麼不見了", "動腦", "A shy little monkey covering its eyes with its hands"),
    ("next_in_row", "接下去", "動腦", "A chunky cute toy train seen from the side, large in the frame, engine plus three carriages colored red, blue, red in a repeating pattern, with big round wheels"),
    ("memory", "記憶翻牌", "動腦", "Three playing cards, two face down with a star back and one flipped showing a cute strawberry"),
    ("spot_diff", "找不同", "動腦", "A magnifying glass over two small side-by-side pictures of a flower"),
    ("pattern", "找規律", "動腦", "A big clear row of five cute fruits in an alternating AB pattern: red apple, yellow banana, red apple, yellow banana, red apple, all the same size, filling the frame width"),
    ("sudoku", "數獨小將", "動腦", "A small 4-by-4 grid board filled with cute colorful fruit pieces"),
    # 首頁獎勵按鈕
    ("gacha", "扭蛋機", "首頁", "A cute colorful capsule toy vending machine with round capsules inside"),
    ("collection", "收藏室", "首頁", "A cozy little toy shelf with a teddy bear, a ball and a toy rocket"),
    ("trophy", "獎盃櫃", "首頁", "A shiny golden trophy cup with a star on top"),
]

# 年齡選擇：吉祥物小企鵝的成長階段（用參考圖保持同一隻）
AGES = [
    ("age3_4", "3-4 歲", "The same penguin as a tiny baby just hatching out of a cracked egg shell, "
     "only its head and flippers poking out, no backpack."),
    ("age4_5", "4-5 歲", "The same penguin as a small young chick, sitting and smiling, "
     "slightly fluffy, no backpack."),
    ("age5_6", "5-6 歲", "The same penguin, grown a bit, standing proudly with its explorer "
     "backpack and a tiny graduation-style star badge."),
]


def write_html():
    groups = {}
    for key, zh, dom, _ in ICONS:
        groups.setdefault(dom, []).append((key, zh))
    groups["年齡選擇"] = [(k, zh) for k, zh, _ in AGES]
    sections = []
    for dom, items in groups.items():
        cells = "".join(
            f'<figure><img src="../../assets/images/icons/{k}.webp" alt="{zh}">'
            f'<figcaption>{zh}</figcaption></figure>' for k, zh in items)
        sections.append(f'<section><h2>{dom}</h2><div class="grid">{cells}</div></section>')
    html = f"""<!doctype html>
<html lang="zh-Hant"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>第 1 批圖示</title>
<style>
:root{{--bg:#fbf8f3;--fg:#2b2b2b;--muted:#6b6b6b;--card:#fff;--line:#e8e2d8}}
@media (prefers-color-scheme:dark){{:root{{--bg:#1d1c1a;--fg:#eee;--muted:#aaa;--card:#2a2926;--line:#3a3833}}}}
body{{margin:0;background:var(--bg);color:var(--fg);font-family:system-ui,"Noto Sans TC",sans-serif}}
main{{max-width:1100px;margin:0 auto;padding:24px 16px 64px}}
h1{{margin:0 0 4px}} .sub{{color:var(--muted);margin:0 0 24px}}
section{{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:20px;margin-bottom:20px}}
h2{{margin:0 0 14px}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:12px}}
figure{{margin:0;text-align:center}} figure img{{width:100%;height:auto;border-radius:12px;background:#fff}}
figcaption{{font-size:14px;color:var(--muted);margin-top:6px}}
</style></head><body><main>
<h1>第 1 批：關卡與首頁圖示</h1>
<p class="sub">白底原圖；接進 App 前會去背，放進各領域色卡片。</p>
{''.join(sections)}
</main></body></html>"""
    with open(os.path.join(gs.OUT, "icons.html"), "w", encoding="utf-8") as f:
        f.write(html)


def main():
    if not gs.KEY:
        sys.exit("tool/secrets.env 沒有 GEMINI_API_KEY")
    os.makedirs(OUT, exist_ok=True)
    fail = []
    for key, _, _, subj in ICONS:
        final = os.path.join(OUT, key + ".webp")
        if os.path.exists(final) and not gs.FORCE:
            print("skip", key)
            continue
        print("gen", key, "...")
        data = gs.gen_one(f"{subj}, {WHITE}. {STYLE} {gs.NO_TEXT}")
        if not data:
            print("  FAILED", key)
            fail.append(key)
            continue
        gs.save(data, final, "tile")
        print("  saved", final)
        time.sleep(2)  # 緩一下，降低限流
    ref = os.path.join(gs.ROOT, "assets", "images", "mascot", "wave.webp")
    for key, _, desc in AGES:
        final = os.path.join(OUT, key + ".webp")
        if os.path.exists(final) and not gs.FORCE:
            print("skip", key)
            continue
        print("gen", key, "...")
        data = gm.gen_ref(ref, f"{desc} {gm.KEEP}")
        if not data:
            print("  FAILED", key)
            fail.append(key)
            continue
        gs.save(data, final, "tile")
        print("  saved", final)
        time.sleep(2)
    write_html()
    print(f"完成，失敗 {len(fail)} {fail}")


if __name__ == "__main__":
    main()
