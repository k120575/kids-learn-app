# -*- coding: utf-8 -*-
"""
美術風格提案樣稿：同一組題材 × 3 種畫風，讓 Kevin 並排比較後拍板。
每種風格出 7 張：吉祥物、4 個領域圖示、1 個題目物件（取代 emoji 的示範）、首頁背景。
共 21 張，gemini-2.5-flash-image 約 US$0.039/張 → 約 US$0.8。

產出到 docs/style_proposal/<風格>/，並生成 docs/style_proposal/index.html 對照頁。
吉祥物「小熊」只是佔位題材（讓三種風格畫同一個東西好比較），角色本身待 Kevin 決定。

金鑰讀自 tool/secrets.env（GEMINI_API_KEY=...）。
用法：python tool/gen_style_samples.py            # 只生缺的
      python tool/gen_style_samples.py --force    # 全部重生
      MODEL=gemini-3.1-flash-image-preview python tool/gen_style_samples.py
"""
import base64
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "style_proposal")
MODEL = os.environ.get("MODEL", "gemini-2.5-flash-image")
FORCE = "--force" in sys.argv

KEY = ""
with open(os.path.join(ROOT, "tool", "secrets.env"), encoding="utf-8") as f:
    for line in f:
        if line.strip().startswith("GEMINI_API_KEY"):
            KEY = line.split("=", 1)[1].strip()

NO_TEXT = "No text, no words, no letters, no numbers, no watermark."

# (id, 中文名, 一句說明, 風格 prompt, 物件用的背景描述)
STYLES = [
    ("clay", "黏土 3D",
     "軟Q立體、像捏出來的玩具；小朋友接受度最高，但和童樂簿同路線",
     "Soft 3D claymation plasticine style, handmade clay toy look, smooth matte clay "
     "texture with subtle fingerprints, pastel colors, rounded chunky shapes, soft studio "
     "lighting, gentle shadows, adorable and friendly.",
     "isolated on a plain pure white background"),
    ("watercolor", "繪本水彩",
     "溫暖手繪、像床邊故事書；有教育感、市面上少見，容易做出區隔",
     "Hand-painted children's picture book watercolor illustration, soft paper texture, "
     "gentle colored-pencil outlines, warm cozy palette, loose brush strokes, whimsical "
     "and heartwarming, like a classic bedtime storybook.",
     "isolated on a plain warm off-white paper background"),
    ("sticker", "扁平貼紙",
     "乾淨向量、粗白邊貼紙；最好維持一致、縮小也清楚，最接近現有 App 的感覺",
     "Flat vector sticker illustration, bold clean shapes, thick white sticker border "
     "around the subject, bright saturated cheerful colors, simple cel shading, minimal "
     "detail, kawaii, crisp edges, consistent line weight.",
     "isolated on a plain pure white background"),
]

MASCOT = ("A cute chubby little bear cub mascot character waving hello with one paw, big "
          "sparkly friendly eyes, rosy cheeks, wearing a small explorer backpack, full body, "
          "front three-quarter view, centered.")

# (檔名, 中文標籤, 題材)
ICONS = [
    ("icon_language", "語文", "An app icon of an open picture book with a speech bubble floating above it"),
    ("icon_math", "邏輯數學", "An app icon of a small wooden abacus with colorful beads stacked next to counting blocks"),
    ("icon_spatial", "空間", "An app icon of three colorful jigsaw puzzle pieces fitting together"),
    ("icon_music", "音樂", "An app icon of a small toy drum with drumsticks and two floating music notes"),
]

ITEM = ("item_apple", "題目物件（取代 🍎）",
        "A single shiny red apple with one green leaf, simple and instantly recognizable, centered")

BG = ("A wide gentle home-screen landscape for a preschool learning app: rolling green hills, "
      "a winding path, a few round trees, a tiny house in the distance, soft fluffy clouds in a "
      "light blue sky. Keep the center open and uncluttered for buttons. Wide 16:9 composition.")


def gen_one(prompt):
    body = json.dumps({
        "contents": [{"parts": [{"text": "Generate an illustration. " + prompt}]}],
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
            elif e.code in (401, 402, 403):
                sys.exit(f"HTTP {e.code}：金鑰無效或額度用完，停止整批")
            else:
                break
        except Exception as e:
            print("    err", e)
            time.sleep(10)
    return None


def save(data, path, kind):
    im = Image.open(io.BytesIO(data)).convert("RGB")
    if kind == "bg":
        tw, th = 1280, 720
    else:
        tw, th = 512, 512
    scale = max(tw / im.width, th / im.height)
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    left, top = (im.width - tw) // 2, (im.height - th) // 2
    im.crop((left, top, left + tw, top + th)).save(path, "WEBP", quality=88)


def jobs():
    for sid, _, _, style, iso in STYLES:
        yield sid, "mascot", "tile", f"{MASCOT} {iso}. {style} {NO_TEXT}"
        for name, _, subj in ICONS:
            yield sid, name, "tile", f"{subj}, centered, {iso}. {style} {NO_TEXT}"
        yield sid, ITEM[0], "tile", f"{ITEM[2]}, {iso}. {style} {NO_TEXT}"
        yield sid, "home_bg", "bg", f"{BG} {style} {NO_TEXT}"


def write_html():
    tiles = [("mascot", "吉祥物（佔位：小熊）")] + [(n, l) for n, l, _ in ICONS] + [ITEM[:2]]
    rows = []
    for sid, zh, note, _, _ in STYLES:
        cells = "".join(
            f'<figure><img src="{sid}/{n}.webp" alt="{l}"><figcaption>{l}</figcaption></figure>'
            for n, l in tiles)
        rows.append(
            f'<section><h2>{zh}</h2><p class="note">{note}</p>'
            f'<div class="home"><img src="{sid}/home_bg.webp" alt="首頁背景">'
            f'<img class="m" src="{sid}/mascot.webp" alt=""></div>'
            f'<div class="grid">{cells}</div></section>')
    html = f"""<!doctype html>
<html lang="zh-Hant"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>美術風格提案</title>
<style>
:root{{--bg:#fbf8f3;--fg:#2b2b2b;--muted:#6b6b6b;--card:#fff;--line:#e8e2d8}}
@media (prefers-color-scheme:dark){{:root{{--bg:#1d1c1a;--fg:#eee;--muted:#aaa;--card:#2a2926;--line:#3a3833}}}}
body{{margin:0;background:var(--bg);color:var(--fg);font-family:system-ui,"Noto Sans TC",sans-serif}}
main{{max-width:1100px;margin:0 auto;padding:24px 16px 64px}}
h1{{margin:0 0 4px}} .sub{{color:var(--muted);margin:0 0 32px}}
section{{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:20px;margin-bottom:28px}}
h2{{margin:0}} .note{{color:var(--muted);margin:4px 0 16px}}
.home{{position:relative;border-radius:12px;overflow:hidden;margin-bottom:16px}}
.home img{{display:block;width:100%;height:auto}}
.home .m{{position:absolute;left:4%;bottom:4%;width:22%;height:auto;mix-blend-mode:multiply}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:12px}}
figure{{margin:0;text-align:center}} figure img{{width:100%;height:auto;border-radius:12px;background:#fff}}
figcaption{{font-size:14px;color:var(--muted);margin-top:6px}}
</style></head><body><main>
<h1>寶貝學習樂園｜美術風格提案</h1>
<p class="sub">同一組題材用三種畫風繪製（{MODEL}）。吉祥物小熊只是佔位，角色設定另外決定。</p>
{''.join(rows)}
</main></body></html>"""
    with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as f:
        f.write(html)


def main():
    if not KEY:
        sys.exit("tool/secrets.env 沒有 GEMINI_API_KEY")
    done, fail = 0, []
    for sid, name, kind, prompt in jobs():
        os.makedirs(os.path.join(OUT, sid), exist_ok=True)
        final = os.path.join(OUT, sid, name + ".webp")
        if os.path.exists(final) and not FORCE:
            print("skip", sid, name)
            continue
        print("gen", sid, name, "...")
        data = gen_one(prompt)
        if not data:
            print("  FAILED", sid, name)
            fail.append(f"{sid}/{name}")
            continue
        save(data, final, kind)
        print("  saved", final)
        done += 1
        time.sleep(2)  # 緩一下，降低限流
    write_html()
    print(f"完成：新生 {done}，失敗 {len(fail)} {fail}")


if __name__ == "__main__":
    main()
