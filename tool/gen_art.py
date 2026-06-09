# -*- coding: utf-8 -*-
"""
用 Gemini 圖像模型（Nano Banana, gemini-2.5-flash-image）產生「探索地圖」的
童書插畫資產：10 張關卡入口圖（圓形徽章）+ 2 張場景背景。
產完用 ffmpeg 縮圖壓縮到 App 適用大小，存到 assets/images/。

金鑰讀自 tool/secrets.env（GEMINI_API_KEY=...）。
用法：python tool/gen_art.py            # 只生缺的
      python tool/gen_art.py --force    # 全部重生
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "images")
RAW = os.path.join(OUT, "raw")
FFMPEG = os.environ.get(
    "FFMPEG", r"C:\src\ffmpeg\ffmpeg-8.1.1-essentials_build\bin\ffmpeg.exe")
MODEL = "gemini-2.5-flash-image"
FORCE = "--force" in sys.argv

KEY = ""
with open(os.path.join(ROOT, "tool", "secrets.env"), encoding="utf-8") as f:
    for line in f:
        if line.strip().startswith("GEMINI_API_KEY"):
            KEY = line.split("=", 1)[1].strip()

STYLE = ("Flat children's storybook illustration style, simple rounded shapes, "
         "bright cheerful saturated colors, soft shadows, adorable kawaii, "
         "for a preschool learning app. No text, no words, no letters, no numbers.")

TILE_FRAME = ("Set the single subject inside a glossy circular medallion badge "
              "with a thin white rim and a soft {bg} background, centered, fills the circle. ")

# (name, kind, prompt)  kind: 'tile' (512x512) 或 'bg' (1280x720 cover)
ASSETS = [
    # ---- 遊樂園 ----
    ("storyhouse", "tile",
     "A cute cozy storybook house with a warm glowing window and a big open book in front. "
     + TILE_FRAME.format(bg="mint green")),
    ("ferris", "tile",
     "A colorful cheerful ferris wheel with rainbow cabins. "
     + TILE_FRAME.format(bg="sky blue")),
    ("castle", "tile",
     "A cute toy building-block castle with colorful turrets and flags. "
     + TILE_FRAME.format(bg="warm peach")),
    ("circus", "tile",
     "A cute red and white striped circus big-top tent with little flags on top. "
     + TILE_FRAME.format(bg="lavender")),
    ("mirror", "tile",
     "A whimsical carnival funhouse entrance with a smiling face and curvy mirrors, playful. "
     + TILE_FRAME.format(bg="soft yellow")),
    # ---- 太空（星球）----
    ("planet_word", "tile",
     "A cute friendly planet hugging an open book with a little speech bubble, language theme. "
     + TILE_FRAME.format(bg="deep indigo with tiny stars")),
    ("planet_math", "tile",
     "A cute planet stacked with colorful counting blocks and a glowing plus sign, math theme. "
     + TILE_FRAME.format(bg="deep blue with tiny stars")),
    ("planet_block", "tile",
     "A cute planet built from colorful 3D building cubes, spatial blocks theme. "
     + TILE_FRAME.format(bg="dark teal with tiny stars")),
    ("planet_music", "tile",
     "A cute planet with happy musical notes floating around it, music theme. "
     + TILE_FRAME.format(bg="deep purple with tiny stars")),
    ("planet_puzzle", "tile",
     "A mysterious cute planet with a glowing ring and a floating jigsaw puzzle piece, puzzle theme. "
     + TILE_FRAME.format(bg="midnight blue with tiny stars")),
    # ---- 魔法學院 ----
    ("magic_spell", "tile",
     "A cute open magic spellbook with glowing swirly runes and a sparkly star-tipped wand resting on it, language spell theme. "
     + TILE_FRAME.format(bg="soft amethyst purple with tiny sparkles")),
    ("magic_alchemy", "tile",
     "A cute alchemy station with rounded bubbling potion bottles of colorful glowing liquid and floating sparkles, numbers theme. "
     + TILE_FRAME.format(bg="warm amber gold with tiny sparkles")),
    ("magic_circle", "tile",
     "A cute glowing magic summoning circle with neat geometric rune patterns and small floating crystal gems, spatial theme. "
     + TILE_FRAME.format(bg="twilight blue with tiny sparkles")),
    ("magic_sound", "tile",
     "A cute enchanted golden horn with glowing musical notes and gentle sound-wave sparkles swirling around, music theme. "
     + TILE_FRAME.format(bg="deep violet with tiny sparkles")),
    ("magic_tower", "tile",
     "A cute whimsical wizard tower with a tall pointed star-topped roof and a warm glowing round window and a little golden key floating beside it, wisdom theme. "
     + TILE_FRAME.format(bg="dusky indigo with tiny sparkles")),
    # ---- 背景場景 ----
    ("park_bg", "bg",
     "A wide panoramic cheerful amusement park landscape for children. Bright blue sky with "
     "fluffy white clouds and a smiling sun, a distant colorful ferris wheel and striped circus "
     "tents on rolling green grassy hills, a few balloons. Keep the central area open, calm and "
     "uncluttered. Wide 16:9 composition, dreamy and inviting. " + STYLE),
    ("space_bg", "bg",
     "A wide dreamy outer-space scene for children. Deep blue to purple gradient starry sky, "
     "many small twinkling stars, a few distant cute colorful planets, a ringed planet, a soft "
     "crescent moon and a tiny rocket near the edges. Keep the central area open and calm. "
     "Wide 16:9 composition, magical and gentle. " + STYLE),
    ("magic_bg", "bg",
     "A wide dreamy magical wizard academy scene for children. A whimsical castle with rounded "
     "towers and tall pointed star-topped roofs on a gentle hill at twilight. A purple-to-warm-gold "
     "sky with a soft crescent moon, a few twinkling stars, floating glowing lanterns and sparkles. "
     "Keep the central area open, calm and uncluttered. Wide 16:9 composition, cozy, gentle and "
     "magical. " + STYLE),
]


def gen_one(prompt):
    body = json.dumps({
        "contents": [{"parts": [{"text": "Generate an illustration. " + prompt + " " + STYLE}]}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }).encode()
    url = (f"https://generativelanguage.googleapis.com/v1beta/models/"
           f"{MODEL}:generateContent?key={KEY}")
    for attempt in range(6):
        try:
            req = urllib.request.Request(
                url, data=body, headers={"Content-Type": "application/json"})
            r = json.load(urllib.request.urlopen(req, timeout=240))
            for p in r["candidates"][0]["content"]["parts"]:
                if "inlineData" in p:
                    return base64.b64decode(p["inlineData"]["data"])
            print("    no image part, retrying")
        except urllib.error.HTTPError as e:
            print(f"    attempt {attempt} HTTP {e.code}: {e.read().decode()[:90]}")
            if e.code in (429, 500, 503):
                time.sleep(18)
            else:
                break
        except Exception as e:
            print("    err", e)
            time.sleep(10)
    return None


def main():
    os.makedirs(RAW, exist_ok=True)
    done, fail = 0, []
    for name, kind, prompt in ASSETS:
        final = os.path.join(OUT, name + ".png")
        if os.path.exists(final) and not FORCE:
            print("skip", name)
            continue
        print("gen", name, "...")
        data = gen_one(prompt)
        if not data:
            print("  FAILED", name)
            fail.append(name)
            continue
        rawp = os.path.join(RAW, name + ".png")
        open(rawp, "wb").write(data)
        # 縮圖 / 裁切
        if kind == "bg":
            vf = "scale=1280:-1,crop=1280:720"
        else:
            vf = "scale=512:512:force_original_aspect_ratio=increase,crop=512:512"
        subprocess.run([FFMPEG, "-y", "-i", rawp, "-vf", vf, final],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("  saved", final, os.path.getsize(final), "bytes")
        done += 1
        time.sleep(2)  # 緩一下，降低限流
    print(f"完成：新生 {done}，失敗 {len(fail)} {fail}")


if __name__ == "__main__":
    main()
