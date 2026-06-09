# -*- coding: utf-8 -*-
"""
產生 App 背景音樂（輕快歡樂、無歌詞、適合幼兒）。
純 Python 標準庫合成「木琴主旋律 + 彈跳貝斯 + 鼓組(大鼓/拍手/hi-hat)」的
大調流行兒歌循環，存成 WAV，再用 ffmpeg 轉成可無縫循環的 mp3。

風格：C 大調、120 BPM、I–V–vi–IV 經典歡樂和聲、有節奏組 → 活潑不單調。
輸出：assets/music/bgm.mp3

用法：python tool/gen_bgm.py
需要 ffmpeg（環境變數 FFMPEG 或預設路徑）。
"""
import math
import os
import random
import struct
import subprocess
import wave

random.seed(7)  # 固定種子 → 每次產生相同結果（hi-hat 噪音可重現）

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "music")
WAV = os.path.join(OUT_DIR, "_bgm.wav")
MP3 = os.path.join(OUT_DIR, "bgm.mp3")
FFMPEG = os.environ.get(
    "FFMPEG",
    r"C:\src\ffmpeg\ffmpeg-8.1.1-essentials_build\bin\ffmpeg.exe",
)

SR = 44100
BPM = 120
BEAT = 60.0 / BPM          # 0.5s
BAR = BEAT * 4
BARS = 16
TOTAL = BAR * BARS         # 32 秒（A 段 + 對比 B 段，較不重複）


def note(name):
    """音名 → 頻率（A4=440）。"""
    table = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    return 440.0 * (2 ** ((table[name[0]] + (int(name[-1]) - 4) * 12 - 9) / 12.0))


# A 段 I–V–vi–IV ×2 + B 段 vi–IV–I–V 對比，每小節一個和弦（共 16 小節）
CHORDS = [
    "C", "G", "Am", "F", "C", "G", "F", "G",        # A 段
    "Am", "F", "C", "G", "Am", "F", "G", "G",        # B 段（對比）
]
CHORD_NOTES = {
    "C": ["C", "E", "G"], "G": ["G", "B", "D"],
    "Am": ["A", "C", "E"], "F": ["F", "A", "C"],
}
ROOT_OCT = {"C": "C2", "G": "G2", "Am": "A2", "F": "F2"}
FIFTH = {"C": "G2", "G": "D3", "Am": "E3", "F": "C3"}

# 木琴主旋律：(音名, 拍長)；每小節 4 拍，活潑跳音
MELODY = [
    [("E5", 1), ("G5", 1), ("E5", 0.5), ("G5", 0.5), ("C5", 1)],     # C
    [("D5", 1), ("G5", 1), ("B4", 0.5), ("D5", 0.5), ("G4", 1)],     # G
    [("C5", 1), ("E5", 1), ("A4", 0.5), ("C5", 0.5), ("E5", 1)],     # Am
    [("F5", 1), ("A4", 1), ("C5", 1), ("A4", 1)],                    # F
    [("E5", 0.5), ("F5", 0.5), ("G5", 1), ("E5", 1), ("C5", 1)],     # C
    [("D5", 1), ("B4", 1), ("G4", 0.5), ("B4", 0.5), ("D5", 1)],     # G
    [("A4", 1), ("C5", 1), ("F5", 0.5), ("C5", 0.5), ("A4", 1)],     # F
    [("G4", 1), ("B4", 1), ("D5", 2)],                               # G (A 段收尾)
    # ---- B 段（較高音域、對比樂句）----
    [("E5", 1), ("A4", 1), ("C5", 0.5), ("E5", 0.5), ("A4", 1)],     # Am
    [("F5", 1), ("C5", 1), ("A4", 0.5), ("C5", 0.5), ("F5", 1)],     # F
    [("G5", 1), ("E5", 1), ("C5", 0.5), ("E5", 0.5), ("G5", 1)],     # C
    [("D5", 1), ("B4", 1), ("G4", 0.5), ("B4", 0.5), ("D5", 1)],     # G
    [("C5", 0.5), ("E5", 0.5), ("A5", 1), ("E5", 1), ("C5", 1)],     # Am
    [("F5", 1), ("A4", 1), ("C5", 1), ("A4", 1)],                    # F
    [("B4", 1), ("D5", 1), ("G4", 0.5), ("B4", 0.5), ("D5", 1)],     # G
    [("G4", 1), ("D5", 1), ("G5", 2)],                               # G (全曲收尾)
]


def add(buf, start, samples):
    n = len(buf)
    for k, s in enumerate(samples):
        i = start + k
        if i >= n:
            break
        buf[i] += s


def marimba(freq, dur):
    """木琴音色：基音 + 第二/第四泛音，極快起音 + 指數衰減（撥奏感）。"""
    n = int(dur * SR)
    out = [0.0] * n
    for k in range(n):
        t = k / SR
        env = (t / 0.004) if t < 0.004 else math.exp(-5.5 * t)
        s = math.sin(2 * math.pi * freq * t)
        s += 0.5 * math.sin(2 * math.pi * freq * 2 * t)
        s += 0.18 * math.sin(2 * math.pi * freq * 4 * t)
        out[k] = env * s
    return out


def bass(freq, dur):
    """彈跳貝斯：基音 + 少量八度，圓潤包絡。"""
    n = int(dur * SR)
    out = [0.0] * n
    for k in range(n):
        t = k / SR
        env = min(1.0, t / 0.01) * math.exp(-3.0 * t)
        s = math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(2 * math.pi * freq * 2 * t)
        out[k] = env * s
    return out


def kick(dur=0.18):
    """大鼓：音高從 ~120Hz 滑到 ~45Hz + 快速衰減。"""
    n = int(dur * SR)
    out = [0.0] * n
    for k in range(n):
        t = k / SR
        f = 120 * math.exp(-22 * t) + 45
        env = math.exp(-16 * t)
        out[k] = env * math.sin(2 * math.pi * f * t)
    return out


def clap(dur=0.16):
    """拍手/小鼓：帶通感的噪音爆裂（快速衰減）。"""
    n = int(dur * SR)
    out = [0.0] * n
    for k in range(n):
        t = k / SR
        env = math.exp(-30 * t)
        out[k] = env * random.uniform(-1, 1)
    return out


def hat(dur=0.05, gain=1.0):
    """hi-hat：極短高頻噪音。"""
    n = int(dur * SR)
    out = [0.0] * n
    for k in range(n):
        t = k / SR
        env = math.exp(-90 * t)
        out[k] = gain * env * random.uniform(-1, 1)
    return out


def synth():
    n = int(TOTAL * SR)
    buf = [0.0] * n

    for b in range(BARS):
        bar_t = b * BAR
        ch = CHORDS[b]

        # 旋律
        t = bar_t
        for (nm, dur) in MELODY[b]:
            add(buf, int(t * SR), [0.62 * s for s in marimba(note(nm), dur * BEAT * 1.6)])
            t += dur * BEAT

        # 貝斯：root–fifth–root–fifth（每拍），製造彈跳
        seq = [ROOT_OCT[ch], FIFTH[ch], ROOT_OCT[ch], FIFTH[ch]]
        for beat in range(4):
            add(buf, int((bar_t + beat * BEAT) * SR),
                [0.5 * s for s in bass(note(seq[beat]), BEAT * 0.95)])

        # 和弦墊底：每拍輕輕點一下分解和弦（增加豐滿度）
        tones = CHORD_NOTES[ch]
        for beat in range(4):
            nm = tones[beat % 3] + "4"
            add(buf, int((bar_t + beat * BEAT) * SR),
                [0.16 * s for s in marimba(note(nm), BEAT * 1.2)])

        # 鼓組
        for beat in range(4):
            tb = bar_t + beat * BEAT
            if beat in (0, 2):  # 大鼓 1、3
                add(buf, int(tb * SR), [0.9 * s for s in kick()])
            if beat in (1, 3):  # 拍手 2、4
                add(buf, int(tb * SR), [0.33 * s for s in clap()])
            # hi-hat 每半拍，反拍稍重
            for half in (0, 1):
                th = tb + half * BEAT / 2
                add(buf, int(th * SR), [0.12 * s for s in hat(gain=1.0 if half else 0.7)])

    # 正規化 + 首尾極短淡入淡出（避免循環接縫爆音）
    peak = max(1e-6, max(abs(x) for x in buf))
    fade = int(0.012 * SR)
    out = bytearray()
    for i, x in enumerate(buf):
        v = x / peak * 0.9
        if i < fade:
            v *= i / fade
        if i > n - fade:
            v *= (n - i) / fade
        v = max(-1.0, min(1.0, v))
        out += struct.pack("<h", int(v * 32767))
    return bytes(out)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    pcm = synth()
    with wave.open(WAV, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm)
    subprocess.run(
        [FFMPEG, "-y", "-i", WAV,
         "-af", "loudnorm=I=-16:TP=-1.5,aresample=44100",
         "-codec:a", "libmp3lame", "-q:a", "4", MP3],
        check=True,
    )
    os.remove(WAV)
    print("BGM ->", MP3, f"({BARS} bars, {TOTAL:.0f}s loop)")


if __name__ == "__main__":
    main()
