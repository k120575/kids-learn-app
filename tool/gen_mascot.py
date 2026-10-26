# -*- coding: utf-8 -*-
"""
吉祥物小企鵝（扁平繪本風，同 gen_art.py 的 STYLE）。
以參考圖做圖生圖，確保每張都是「同一隻」角色。

階段一（造型微調，給 Kevin 挑）：
  python tool/gen_mascot.py variants
  → 以 docs/style_proposal/compare/flat_penguin.webp 為底，出 B/C/D 三種微調
    （A = 原圖本身），產到 docs/style_proposal/mascot/，並生成 mascot.html。

階段二（定稿後出動作）：
  python tool/gen_mascot.py poses <A|B|C|D>
  → 以選定造型為參考，出 5 個動作到 assets/images/mascot/（白底，之後再去背）。

加 --force 全部重生。金鑰讀自 tool/secrets.env。
"""
import base64
import os
import sys
import time
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_style_samples as gs  # noqa: E402

ROOT = gs.ROOT
PROPOSAL = gs.OUT
VAR_DIR = os.path.join(PROPOSAL, "mascot")
POSE_DIR = os.path.join(ROOT, "assets", "images", "mascot")
BASE = os.path.join(PROPOSAL, "compare", "flat_penguin.webp")

STYLE = ("Flat children's storybook illustration style, simple rounded shapes, "
         "bright cheerful saturated colors, soft shadows, adorable kawaii, "
         "for a preschool learning app.")
KEEP = ("Keep it the exact same penguin character as the reference image: same face, eyes, "
        "colors, proportions and art style. Full body, centered, isolated on a plain pure "
        "white background. " + STYLE + " " + gs.NO_TEXT)

# (代號, 中文說明, 修改描述)
VARIANTS = [
    ("B", "改圍紅色圍巾、拿掉背包（冬天感、更簡潔）",
     "Same penguin, but remove the backpack and give it a cozy knitted red scarf instead. "
     "Waving hello with one flipper."),
    ("C", "戴黃色小探險帽＋背包（探索地圖主角感）",
     "Same penguin with its backpack, plus a small yellow explorer safari hat. "
     "Waving hello with one flipper."),
    ("D", "更圓更寶寶、手拿一支蠟筆（學習感）",
     "Same penguin but rounder and chubbier with baby proportions, no backpack, "
     "holding a big colorful crayon in one flipper and waving with the other."),
]

POSES = [
    ("wave", "揮手（打招呼）", "Waving hello happily with one flipper raised."),
    ("cheer", "歡呼（答對）", "Jumping with joy, both flippers raised high, eyes closed with a big open smile, a few sparkles around."),
    ("think", "思考（出題）", "Thinking pose, one flipper touching its chin, looking up curiously."),
    ("encourage", "加油（答錯）", "Gentle encouraging pose, one flipper making a little fist pump, warm kind smile."),
    ("sleep", "睡覺（休息提醒）", "Sleeping peacefully sitting down, eyes closed, wearing a tiny nightcap."),
]


def gen_ref(ref_path, prompt):
    """以參考圖 + 文字生圖；沿用 gen_style_samples 的重試與停損規則。"""
    import json
    import urllib.request
    with open(ref_path, "rb") as f:
        ref = base64.b64encode(f.read()).decode()
    mime = "image/webp" if ref_path.endswith(".webp") else "image/png"
    body = json.dumps({
        "contents": [{"parts": [
            {"inlineData": {"mimeType": mime, "data": ref}},
            {"text": "Generate an illustration based on this reference character. " + prompt},
        ]}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }).encode()
    url = (f"https://generativelanguage.googleapis.com/v1beta/models/"
           f"{gs.MODEL}:generateContent?key={gs.KEY}")
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


def run(jobs, ref, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    fail = []
    for name, prompt in jobs:
        final = os.path.join(out_dir, name + ".webp")
        if os.path.exists(final) and not gs.FORCE:
            print("skip", name)
            continue
        print("gen", name, "...")
        data = gen_ref(ref, prompt)
        if not data:
            print("  FAILED", name)
            fail.append(name)
            continue
        gs.save(data, final, "tile")
        print("  saved", final)
        time.sleep(2)  # 緩一下，降低限流
    print(f"完成，失敗 {len(fail)} {fail}")


def write_variants_html():
    cards = [("../compare/flat_penguin.webp", "A", "原版：亮藍＋探險背包")]
    cards += [(f"{c}.webp", c, zh) for c, zh, _ in VARIANTS]
    cells = "".join(
        f'<figure><img src="{src}" alt="造型 {c}"><figcaption><b>{c}</b>　{zh}</figcaption></figure>'
        for src, c, zh in cards)
    html = f"""<!doctype html>
<html lang="zh-Hant"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>小企鵝造型</title>
<style>
:root{{--bg:#fbf8f3;--fg:#2b2b2b;--muted:#6b6b6b;--card:#fff;--line:#e8e2d8}}
@media (prefers-color-scheme:dark){{:root{{--bg:#1d1c1a;--fg:#eee;--muted:#aaa;--card:#2a2926;--line:#3a3833}}}}
body{{margin:0;background:var(--bg);color:var(--fg);font-family:system-ui,"Noto Sans TC",sans-serif}}
main{{max-width:1100px;margin:0 auto;padding:24px 16px 64px}}
h1{{margin:0 0 4px}} .sub{{color:var(--muted);margin:0 0 24px}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:16px}}
figure{{margin:0;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:12px;text-align:center}}
figure img{{width:100%;height:auto;border-radius:10px;background:#fff}}
figcaption{{margin-top:8px;color:var(--muted)}} figcaption b{{color:var(--fg);font-size:20px}}
</style></head><body><main>
<h1>小企鵝造型：選一隻</h1>
<p class="sub">都以 A 為參考圖生成，臉和配色保持一致，只改配件與比例。</p>
<div class="grid">{cells}</div>
</main></body></html>"""
    with open(os.path.join(PROPOSAL, "mascot.html"), "w", encoding="utf-8") as f:
        f.write(html)


def main():
    if not gs.KEY:
        sys.exit("tool/secrets.env 沒有 GEMINI_API_KEY")
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if args[:1] == ["variants"]:
        run([(c, f"{desc} {KEEP}") for c, _, desc in VARIANTS], BASE, VAR_DIR)
        write_variants_html()
    elif args[:1] == ["poses"] and len(args) == 2 and args[1] in "ABCD":
        pick = args[1]
        ref = BASE if pick == "A" else os.path.join(VAR_DIR, pick + ".webp")
        run([(n, f"{desc} {KEEP}") for n, _, desc in POSES], ref, POSE_DIR)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
