# -*- coding: utf-8 -*-
"""
合成 4-5 歲「樂器配對」第二套樂器聲 → assets/sfx/inst_*.mp3。

背景：instrument_45 原本與 3-4 樂器配對共用同一套 5 個音檔（鼓/鈴/小號/
小提琴/沙鈴），兩邊都是試玩關 → 付費前後聽到一模一樣的內容。這裡合成一套
全新的 5 種樂器，与 3-4 那套零重疊：
  inst_piano     鋼琴 🎹  ：真實鋼琴取樣（assets/sfx/tone_loud1.mp3 的 C5 單音，
                            與 gen_tones.py 同一 bootstrap 來源）pitch-shift 出琶音
  inst_guitar    吉他 🎸  ：Karplus-Strong 撥弦（物理弦模型，很有吉他味）
  inst_conga     手鼓 🪘  ：膜振盪合成（音高快速下滑的正弦 + 手掌拍擊噪音）
  inst_accordion 手風琴 🪗：多把微失諧鋸齒波和弦 + 顫音（簧片感）
  inst_flute     長笛 🪈  ：正弦 + 弱泛音 + 5Hz 顫音 + 氣聲起音

用法：python tool/gen_instruments.py [輸出資料夾] [--force]
需要 ffmpeg 與 numpy。emoji 🎹🎸🪘🪗🪈 已驗證存在於 bundled NotoColorEmoji。
"""
import math
import os
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_ARGS = [a for a in sys.argv[1:] if not a.startswith("-")]
FORCE = "--force" in sys.argv[1:]
OUT_DIR = _ARGS[0] if _ARGS else os.path.join(ROOT, "assets", "sfx")
FFMPEG = os.environ.get(
    "FFMPEG", r"C:\src\ffmpeg\ffmpeg-8.1.1-essentials_build\bin\ffmpeg.exe")

SR = 44100
RNG = np.random.default_rng(20260821)  # 固定種子 → 重跑產出一致


def freq(name):
    semis = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    base = semis[name[0]] + (1 if "#" in name else 0)
    n = base + (int(name[-1]) - 4) * 12 - 9
    return 440.0 * (2 ** (n / 12.0))


def silence(dur):
    return np.zeros(int(dur * SR))


def place(buf, samples, start_sec):
    s = int(start_sec * SR)
    e = min(len(buf), s + len(samples))
    if e > s:
        buf[s:e] += samples[:e - s]
    return buf


def fade(x, fi=0.004, fo=0.03):
    n = len(x)
    a = int(fi * SR)
    b = int(fo * SR)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)
    return x


# ---------- 鋼琴：取樣器（同 gen_tones bootstrap 來源） ----------

def _load_piano_c5():
    boot = os.path.join(ROOT, "assets", "sfx", "tone_loud1.mp3")
    tmp = os.path.join(OUT_DIR, "_p.wav")
    os.makedirs(OUT_DIR, exist_ok=True)
    subprocess.run([FFMPEG, "-y", "-i", boot, "-ac", "1", "-ar", str(SR), tmp],
                   check=True, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL)
    w = wave.open(tmp, "rb")
    seg = (np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
           .astype(np.float64) / 32768.0)
    w.close()
    os.remove(tmp)
    seg /= max(1e-9, np.abs(seg).max())
    F = np.fft.rfft(seg * np.hanning(len(seg)))
    fr = np.fft.rfftfreq(len(seg), 1 / SR)
    band = (fr > 500) & (fr < 545)
    f0 = float(fr[band][np.argmax(np.abs(F)[band])])
    return seg, f0


def piano():
    src, f0 = _load_piano_c5()

    def note(name, dur):
        r = 2 ** (12.0 * math.log2(freq(name) / f0) / 12.0)
        idx = np.arange(0, len(src), r)
        s = np.interp(idx, np.arange(len(src)), src)
        n = int(dur * SR)
        s = np.pad(s, (0, max(0, n - len(s))))[:n]
        return fade(s.copy(), fo=0.05)

    buf = silence(2.4)
    for i, (nm, t) in enumerate(
            [("C5", 0.0), ("E5", 0.35), ("G5", 0.7), ("C6", 1.05)]):
        place(buf, 0.8 * note(nm, 1.1), t)
    return buf


# ---------- 吉他：Karplus-Strong 撥弦 ----------

def pluck(f, dur, bright=0.5):
    n = int(dur * SR)
    period = int(SR / f)
    buf = np.zeros(n)
    # 初始激勵：白噪音（撥片撥動瞬間）
    line = (RNG.random(period) * 2 - 1)
    for i in range(n):
        buf[i] = line[i % period]
        # 低通回授：相鄰兩點平均 → 弦的能量衰減
        line[i % period] = 0.996 * (
            bright * line[i % period] + (1 - bright) * line[(i + 1) % period])
    return fade(buf, fi=0.001, fo=0.05)


def guitar():
    buf = silence(2.6)
    for nm, t in [("E4", 0.0), ("A4", 0.4), ("C5", 0.8), ("E5", 1.2)]:
        place(buf, 0.7 * pluck(freq(nm), 1.3), t)
    return buf


# ---------- 手鼓：膜振盪（音高下滑正弦 + 拍擊噪音） ----------

def conga_hit(f_hi=190.0, f_lo=95.0, dur=0.5, amp=0.9):
    n = int(dur * SR)
    t = np.arange(n) / SR
    # 指數下滑的音高（鼓膜張力鬆掉的感覺）
    f = f_lo + (f_hi - f_lo) * np.exp(-18 * t)
    phase = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(phase) * np.exp(-9 * t)
    # 手掌拍擊：短噪音爆
    slap = (RNG.random(n) * 2 - 1) * np.exp(-90 * t) * 0.5
    return fade(amp * (body + slap), fi=0.001)


def conga():
    buf = silence(2.2)
    # 兩種音高（開音/悶音）打一小段節奏
    for f, t in [(190, 0.0), (190, 0.35), (240, 0.7), (190, 1.05),
                 (240, 1.35), (190, 1.7)]:
        place(buf, conga_hit(f_hi=f, f_lo=f * 0.5), t)
    return buf


# ---------- 手風琴：微失諧鋸齒波和弦 + 顫音 ----------

def saw(f, n, detune=0.0):
    t = np.arange(n) / SR
    # 顫音（風箱抖動）
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t)
    ph = np.cumsum(f * (1 + detune) * vib) / SR
    x = 2 * (ph % 1.0) - 1
    # 柔化高頻：一階低通
    y = np.copy(x)
    a = 0.25
    for i in range(1, n):
        y[i] = y[i - 1] + a * (x[i] - y[i - 1])
    return y


def accordion():
    n = int(2.2 * SR)
    buf = np.zeros(n)
    # C 大三和弦，每個音兩把微失諧的簧片
    for nm in ["C4", "E4", "G4"]:
        f = freq(nm)
        buf += saw(f, n, -0.004) + saw(f, n, 0.004)
    t = np.arange(n) / SR
    env = np.minimum(1, t / 0.12) * np.minimum(1, (2.2 - t) / 0.3)
    return fade(0.16 * buf * env)


# ---------- 長笛：正弦 + 弱泛音 + 顫音 + 氣聲 ----------

def flute_note(name, dur, amp=0.7):
    f = freq(name)
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.0 * t) * np.minimum(1, t / 0.25)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    tone = np.sin(ph) + 0.28 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    # 氣聲：帶通過的噪音，起音時較強
    breath = (RNG.random(n) * 2 - 1)
    b = np.copy(breath)
    for i in range(1, n):  # 粗略高通
        b[i] = 0.6 * (b[i - 1] + breath[i] - breath[i - 1])
    breath_env = 0.06 + 0.10 * np.exp(-10 * t)
    env = np.minimum(1, t / 0.06) * np.minimum(1, np.maximum(0.0, (dur - t) / 0.12))
    return fade(amp * (tone + b * breath_env) * env, fi=0.01, fo=0.05)


def flute():
    buf = silence(2.4)
    for nm, t, d in [("G5", 0.0, 0.55), ("A5", 0.6, 0.55), ("B5", 1.2, 1.0)]:
        place(buf, flute_note(nm, d), t)
    return buf


# ---------- 輸出 ----------

def write_mp3(name, samples):
    wav = os.path.join(OUT_DIR, f"_{name}.wav")
    mp3 = os.path.join(OUT_DIR, f"{name}.mp3")
    data = samples / max(1e-9, np.abs(samples).max()) * 0.97
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    w = wave.open(wav, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
    w.close()
    subprocess.run(
        [FFMPEG, "-y", "-i", wav, "-af", "loudnorm=I=-16:TP=-1.5",
         "-codec:a", "libmp3lame", "-q:a", "5", mp3],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.remove(wav)
    return os.path.getsize(mp3)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    gens = {
        "inst_piano": piano,
        "inst_guitar": guitar,
        "inst_conga": conga,
        "inst_accordion": accordion,
        "inst_flute": flute,
    }
    for name, fn in gens.items():
        out = os.path.join(OUT_DIR, f"{name}.mp3")
        if not FORCE and os.path.exists(out):
            print(f"{name}.mp3 已存在，跳過（--force 重產）")
            continue
        size = write_mp3(name, fn())
        print(f"{name}.mp3 -> {size} bytes")
    print(f"完成。輸出：{OUT_DIR}")


if __name__ == "__main__":
    main()
