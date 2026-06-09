# -*- coding: utf-8 -*-
"""
合成「答對歡呼音」success.mp3：上行大三和弦琶音 (C-E-G-C) + 明亮和弦收尾
+ 高音閃爍 (twinkle)，鈴鐺/木琴音色、含簡單殘響與立體聲，~1.3 秒，有興奮感。
覆蓋 assets/sfx/success.mp3。

用法：python tool/gen_sfx.py
需要 ffmpeg。
"""
import math
import os
import struct
import subprocess
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "sfx")
WAV = os.path.join(OUT_DIR, "_success.wav")
MP3 = os.path.join(OUT_DIR, "success.mp3")
FFMPEG = os.environ.get(
    "FFMPEG", r"C:\src\ffmpeg\ffmpeg-8.1.1-essentials_build\bin\ffmpeg.exe")

SR = 44100
DUR = 1.35
N = int(SR * DUR)


def freq(name):
    t = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    return 440.0 * (2 ** ((t[name[0]] + (int(name[-1]) - 4) * 12 - 9) / 12.0))


def bell(buf, f, start, dur, amp):
    """鈴鐺/木琴音：基音 + 泛音，快速起音 + 指數衰減。"""
    s = int(start * SR)
    for k in range(int(dur * SR)):
        i = s + k
        if i >= N:
            break
        t = k / SR
        env = (t / 0.003) if t < 0.003 else math.exp(-4.5 * t)
        v = math.sin(2 * math.pi * f * t)
        v += 0.5 * math.sin(2 * math.pi * 2 * f * t)
        v += 0.25 * math.sin(2 * math.pi * 3 * f * t)
        buf[i] += amp * env * v


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    dry = [0.0] * N

    # 上行琶音 C5-E5-G5-C6
    arp = ["C5", "E5", "G5", "C6"]
    for j, nm in enumerate(arp):
        bell(dry, freq(nm), 0.0 + j * 0.085, 0.6, 0.55)

    # 明亮和弦收尾 C6 + E6 + G6
    for nm in ["C6", "E6", "G6"]:
        bell(dry, freq(nm), 0.40, 0.9, 0.4)

    # 高音閃爍 twinkle（很短、很高）
    for j, nm in enumerate(["C7", "E7", "G7"]):
        bell(dry, freq(nm), 0.52 + j * 0.06, 0.25, 0.18)

    # 簡單殘響（幾個遞減延遲拍）
    wet = list(dry)
    for delay, gain in [(0.055, 0.35), (0.11, 0.2), (0.18, 0.12)]:
        d = int(delay * SR)
        for i in range(d, N):
            wet[i] += gain * dry[i - d]

    # 正規化
    peak = max(1e-6, max(abs(x) for x in wet))
    norm = [x / peak * 0.9 for x in wet]

    # 立體聲：右聲道加極短延遲 + 閃爍偏右，營造寬度
    rd = int(0.012 * SR)
    frames = bytearray()
    fade = int(0.02 * SR)
    for i in range(N):
        left = norm[i]
        right = norm[i - rd] if i >= rd else 0.0
        if i > N - fade:
            g = (N - i) / fade
            left *= g
            right *= g
        frames += struct.pack("<hh",
                              int(max(-1, min(1, left)) * 32767),
                              int(max(-1, min(1, right)) * 32767))

    with wave.open(WAV, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    subprocess.run(
        [FFMPEG, "-y", "-i", WAV, "-af", "loudnorm=I=-14:TP=-1.0",
         "-codec:a", "libmp3lame", "-q:a", "4", MP3],
        check=True)
    os.remove(WAV)
    print("success.mp3 ->", os.path.getsize(MP3), "bytes")


if __name__ == "__main__":
    main()
