# -*- coding: utf-8 -*-
"""
物件插畫庫：emoji → 扁平繪本風插畫（同 gen_art.py 的 STYLE），全 App 共用。
第 2 批＝扭蛋玩具、成就獎盃、使用者頭像；第 3 批題目物件之後往 ITEMS 追加即可。

產出：
  assets/images/items/<key>.webp       白底原圖（之後跑 tool/cutout.py 去背）
  lib/content/emoji_art_map.dart        emoji → asset 對照（EmojiArt 元件用）
  docs/style_proposal/items.html        審圖頁
🐧 一律對應吉祥物企企（assets/images/mascot/wave.webp），不另畫。

用法：python tool/gen_items.py [--force]
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_mascot as gm  # noqa: E402
import gen_style_samples as gs  # noqa: E402

OUT = os.path.join(gs.ROOT, "assets", "images", "items")
DART = os.path.join(gs.ROOT, "lib", "content", "emoji_art_map.dart")
STYLE = gm.STYLE
WHITE = ("single subject, centered, filling most of the frame, isolated on a plain pure "
         "white background")
MASCOT_EMOJI = {"🐧": "assets/images/mascot/wave.webp"}

# (emoji, key, 分組, 題材)
ITEMS = [
    # ---- 扭蛋：普通 ----
    ("🚗", "car", "玩具", "A cute red toy car with a happy face"),
    ("🚌", "bus", "玩具", "A cute yellow school bus seen from the side, long body with a row of passenger windows and two big wheels"),
    ("🚓", "police_car", "玩具", "A cute police car with a siren light on top"),
    ("🚒", "fire_truck", "玩具", "A cute red fire truck with a ladder"),
    ("🚜", "tractor", "玩具", "A cute green farm tractor with big back wheels"),
    ("⛵", "sailboat", "玩具", "A cute little sailboat with a white sail on a small wave"),
    ("🐶", "dog", "玩具", "A cute puppy sitting and wagging its tail"),
    ("🐱", "cat", "玩具", "A cute orange kitten sitting"),
    ("🐰", "rabbit", "玩具", "A cute white bunny with long ears"),
    ("🐸", "frog", "玩具", "A cute green frog sitting"),
    ("🐢", "turtle", "玩具", "A cute turtle with a patterned green shell"),
    ("⚽", "soccer_ball", "玩具", "A classic black and white soccer ball"),
    ("🪀", "yoyo", "玩具", "A classic round red and blue toy yo-yo seen from the side, hanging from a short string with a finger loop at the top"),
    ("🪁", "kite", "玩具", "A colorful diamond-shaped kite with a ribbon tail"),
    ("🧸", "teddy_bear", "玩具", "A cute brown teddy bear with a bow tie"),
    ("🎈", "balloon", "玩具", "A shiny red balloon with a curly string"),
    ("🎀", "ribbon", "玩具", "A big pink ribbon bow"),
    ("🐮", "cow", "玩具", "A cute black and white dairy cow"),
    ("🐷", "pig", "玩具", "A cute pink piglet"),
    ("🐔", "chicken", "玩具", "A cute white hen with a red comb"),
    ("🐵", "monkey", "玩具", "A cute little brown monkey"),
    ("🐠", "tropical_fish", "玩具", "A cute colorful striped tropical fish"),
    ("🐝", "bee", "玩具", "A cute round honey bee with little wings"),
    ("🐞", "ladybug", "玩具", "A cute red ladybug with black spots"),
    ("🦆", "duck", "玩具", "A cute yellow duck"),
    ("🐴", "horse", "玩具", "A cute brown pony"),
    ("🐑", "sheep", "玩具", "A cute fluffy white sheep"),
    ("🍎", "apple", "玩具", "A shiny red apple with a green leaf"),
    ("🍌", "banana", "玩具", "A ripe yellow banana"),
    ("🍓", "strawberry", "玩具", "A juicy red strawberry"),
    ("🍇", "grapes", "玩具", "A bunch of purple grapes"),
    ("🍉", "watermelon", "玩具", "A slice of red watermelon with seeds"),
    ("🍪", "cookie", "玩具", "A round chocolate chip cookie"),
    ("🍩", "donut", "玩具", "A pink frosted donut with sprinkles"),
    ("🌈", "rainbow", "玩具", "A bright rainbow arc with two fluffy clouds at its ends"),
    ("🌟", "glowing_star", "玩具", "A glowing golden star with sparkles around it"),
    ("🍄", "mushroom", "玩具", "A cute red mushroom with white spots"),
    # ---- 扭蛋：稀有 ----
    ("🚀", "rocket", "玩具", "A cute red and white rocket with a flame"),
    ("🚁", "helicopter", "玩具", "A cute blue helicopter"),
    ("🦊", "fox", "玩具", "A cute orange fox with a fluffy tail"),
    ("🐬", "dolphin", "玩具", "A cute blue dolphin jumping"),
    ("🦋", "butterfly", "玩具", "A colorful butterfly with patterned wings"),
    ("🦒", "giraffe", "玩具", "A cute giraffe with a long neck"),
    ("🐘", "elephant", "玩具", "A cute grey baby elephant"),
    ("🎠", "carousel", "玩具", "A colorful merry-go-round carousel"),
    ("🎡", "ferris_wheel", "玩具", "A colorful ferris wheel"),
    ("🦜", "parrot", "玩具", "A cute colorful parrot"),
    ("🦩", "flamingo", "玩具", "A cute pink flamingo standing on one leg"),
    ("🦚", "peacock", "玩具", "A cute peacock with its tail feathers fanned out"),
    ("🦛", "hippo", "玩具", "A cute purple-grey hippo"),
    ("🐊", "crocodile", "玩具", "A cute friendly green crocodile"),
    ("🦓", "zebra", "玩具", "A cute zebra with black and white stripes"),
    ("🦏", "rhino", "玩具", "A cute grey rhinoceros"),
    ("🎢", "roller_coaster", "玩具", "An amusement park roller coaster: a colorful track with hills and one loop, and a small red cart with riders' raised arms on the track"),
    ("🎸", "guitar", "玩具", "A cute red acoustic guitar"),
    # ---- 扭蛋：傳說 ----
    ("🦄", "unicorn", "玩具", "A magical white unicorn with a rainbow mane and golden horn, sparkles around"),
    ("🐉", "dragon", "玩具", "A cute friendly Chinese-style green dragon flying, with clearly visible bat-like wings, two small golden horns and a curly tail, sparkles around"),
    ("👑", "crown", "玩具", "A shiny golden crown with colorful jewels, sparkles around"),
    ("💎", "diamond", "玩具", "A big sparkling blue diamond gem, sparkles around"),
    ("🛸", "ufo", "玩具", "A cute flying saucer UFO with a glowing dome, sparkles around"),
    ("🦕", "brachiosaurus", "玩具", "A cute long-necked green dinosaur, sparkles around"),
    ("🦖", "t_rex", "玩具", "A cute friendly T-rex dinosaur, sparkles around"),
    ("👽", "alien", "玩具", "A cute friendly little green alien, sparkles around"),
    ("🤖", "robot", "玩具", "A cute friendly toy robot with an antenna, sparkles around"),
    # ---- 頭像（扭蛋池沒有的）----
    ("🐻", "bear", "頭像", "A cute brown bear cub face and body, sitting"),
    ("🦁", "lion", "頭像", "A cute lion cub with a fluffy mane"),
    ("🐯", "tiger", "頭像", "A cute tiger cub with orange stripes"),
    ("🐼", "panda", "頭像", "A cute giant panda cub sitting"),
    # ---- 成就獎盃（扭蛋池沒有的）----
    ("🧭", "compass", "成就", "A shiny golden explorer compass"),
    ("⭐", "star", "成就", "A big plump golden star"),
    ("🔥", "fire", "成就", "A cute friendly orange flame with a happy face"),
    ("🎮", "game_controller", "成就", "A cute colorful handheld game controller"),
    ("💠", "crystal", "成就", "A cluster of three sparkly light-blue crystal gems growing upward, plain smooth facets"),
    ("🤑", "gold_coins", "成就", "A pile of shiny gold coins with sparkles"),
    ("💯", "perfect_medal", "成就", "A shiny gold medal on a red ribbon with a big star in the middle"),
    ("📅", "calendar", "成就", "A cute desk calendar with a red ring and a heart sticker"),
    ("📚", "books", "成就", "A neat stack of three colorful books"),
]


def write_dart():
    lines = [f"  '{e}': 'assets/images/items/{k}.webp'," for e, k, _, _ in ITEMS]
    lines += [f"  '{e}': '{p}'," for e, p in MASCOT_EMOJI.items()]
    body = "\n".join(lines)
    dart = f"""// 由 tool/gen_items.py 產生，勿手改；新增物件請改 ITEMS 再重跑。
/// emoji → 扁平繪本風插畫（去背 webp）。沒有對應圖的 emoji 由 EmojiArt 退回顯示字元。
library;

const Map<String, String> kEmojiArt = <String, String>{{
{body}
}};
"""
    with open(DART, "w", encoding="utf-8") as f:
        f.write(dart)


def write_html():
    groups = {}
    for e, k, g, _ in ITEMS:
        groups.setdefault(g, []).append((e, k))
    sections = []
    for g, items in groups.items():
        cells = "".join(
            f'<figure><img src="../../assets/images/items/{k}.webp" alt="{e}">'
            f'<figcaption>{e} {k}</figcaption></figure>' for e, k in items)
        sections.append(f'<section><h2>{g}（{len(items)}）</h2><div class="grid">{cells}</div></section>')
    html = f"""<!doctype html>
<html lang="zh-Hant"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>物件插畫</title>
<style>
:root{{--bg:#fbf8f3;--fg:#2b2b2b;--muted:#6b6b6b;--card:#fff;--line:#e8e2d8}}
@media (prefers-color-scheme:dark){{:root{{--bg:#1d1c1a;--fg:#eee;--muted:#aaa;--card:#2a2926;--line:#3a3833}}}}
body{{margin:0;background:var(--bg);color:var(--fg);font-family:system-ui,"Noto Sans TC",sans-serif}}
main{{max-width:1100px;margin:0 auto;padding:24px 16px 64px}}
h1{{margin:0 0 4px}} .sub{{color:var(--muted);margin:0 0 24px}}
section{{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:20px;margin-bottom:20px}}
h2{{margin:0 0 14px}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(120px,1fr));gap:12px}}
figure{{margin:0;text-align:center}} figure img{{width:100%;height:auto;border-radius:12px;background:#fff}}
figcaption{{font-size:13px;color:var(--muted);margin-top:6px}}
</style></head><body><main>
<h1>物件插畫（第 2 批：玩具／頭像／成就）</h1>
<p class="sub">🐧 一律用企企本人，不在此列。</p>
{''.join(sections)}
</main></body></html>"""
    with open(os.path.join(gs.OUT, "items.html"), "w", encoding="utf-8") as f:
        f.write(html)


def main():
    if not gs.KEY:
        sys.exit("tool/secrets.env 沒有 GEMINI_API_KEY")
    keys = [k for _, k, _, _ in ITEMS]
    emojis = [e for e, _, _, _ in ITEMS]
    assert len(set(keys)) == len(keys) and len(set(emojis)) == len(emojis), "key/emoji 重複"
    os.makedirs(OUT, exist_ok=True)
    fail = []
    for _, key, _, subj in ITEMS:
        final = os.path.join(OUT, key + ".webp")
        if os.path.exists(final) and not gs.FORCE:
            continue
        print("gen", key, "...", flush=True)
        data = gs.gen_one(f"{subj}, {WHITE}. {STYLE} {gs.NO_TEXT}")
        if not data:
            print("  FAILED", key)
            fail.append(key)
            continue
        gs.save(data, final, "tile")
        time.sleep(2)  # 緩一下，降低限流
    write_dart()
    write_html()
    print(f"完成，失敗 {len(fail)} {fail}")


if __name__ == "__main__":
    main()
