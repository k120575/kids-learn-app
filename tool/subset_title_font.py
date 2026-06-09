# -*- coding: utf-8 -*-
"""
重新 subset 標題字型 TitleFont（assets/fonts/title-gensen.otf）。

背景：完整 GenSenRounded2 TC（源泉圓體2，繁中）約 15MB 太大，App 只用來顯示
首頁標題與各關卡 / 地圖標題，所以 subset 成「只含 App 內出現過的中文字」。

何時要重跑：新增了任何會用 TitleFont 顯示的文字（地圖標題、站點名、遊戲名、
首頁標題…），且新字不在現有 subset 內時——否則會顯示成豆腐框 □。

用法：
  1. 下載完整字型（OFL 免費）：
       https://github.com/ButTaiwan/gensen-font  → release 的 GenSenRounded2TC-otf.zip
     解壓取出需要的字重。
  2. 兩個字重各跑一次（H 給首頁大標題，M 給頂列小標題）：
       python tool/subset_title_font.py <GenSenRounded2TC-H.otf> assets/fonts/title-gensen.otf
       python tool/subset_title_font.py <GenSenRounded2TC-M.otf> assets/fonts/title-gensen-m.otf

腳本會掃描 lib/ 下所有 .dart 內出現的中文字，subset 後輸出到指定檔。
為什麼要兩個字重：Heavy 在小字級下密筆畫字（樂/歡/園）內部會糊，小標題要用 Medium。
"""
import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def collect_cjk() -> str:
    chars = set()
    for path in glob.glob(os.path.join(ROOT, "lib", "**", "*.dart"), recursive=True):
        with open(path, encoding="utf-8") as fh:
            for ch in fh.read():
                if "一" <= ch <= "鿿" or "㐀" <= ch <= "䶿":
                    chars.add(ch)
    return "".join(sorted(chars))


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(
            "用法：python tool/subset_title_font.py <完整字型.otf> "
            "[輸出路徑，預設 assets/fonts/title-gensen.otf]"
        )
    full_font = sys.argv[1]
    if not os.path.isfile(full_font):
        sys.exit(f"找不到完整字型：{full_font}")
    out = (
        sys.argv[2]
        if len(sys.argv) > 2
        else os.path.join(ROOT, "assets", "fonts", "title-gensen.otf")
    )

    chars = collect_cjk()
    charset_file = os.path.join(ROOT, "tool", "_title_charset.txt")
    with open(charset_file, "w", encoding="utf-8") as f:
        f.write(chars)
    print(f"收集到 {len(chars)} 個中文字 → {charset_file}")

    subprocess.run(
        [
            sys.executable, "-m", "fontTools.subset", full_font,
            f"--text-file={charset_file}",
            f"--output-file={out}",
            "--layout-features=*",
        ],
        check=True,
    )
    size_kb = round(os.path.getsize(out) / 1024, 1)
    print(f"完成 → {out}（{size_kb} KB，{len(chars)} 字）")


if __name__ == "__main__":
    main()
