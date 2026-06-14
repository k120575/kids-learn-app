# -*- coding: utf-8 -*-
"""
合成「音樂領域聽辨遊戲」用的 tone clip → assets/sfx/。

音色來源：真實鋼琴錄音（Bach C 大調前奏曲）。因為該曲是連續的 C 大調琶音
（每一刻都是 C-E-G 和弦、踏板延音），無法直接切出乾淨的單音；改用
**FFT 諧波篩（harmonic sieve）**：從和弦窗只保留某個基頻（C5）及其整數泛音、
其餘歸零，反 FFT 還原出「一個真實鋼琴音色的 C5 單音」，再用取樣器 pitch-shift
到各音高，組成各遊戲所需 clip。

產出（每組多個變體）：
  高高低低 :  tone_hi1..3（高）          / tone_lo1..3（低，差約兩個八度）
  音往哪裡走: tone_up1..3（低→高）       / tone_down1..3（高→低）
  快快慢慢 :  tone_fast1..3（密集）       / tone_slow1..3（疏落）
  大聲小聲 :  tone_loud1..3（大）         / tone_soft1..3（同音高、小聲）★不正規化
  音的長短 :  tone_long1..3（長音 ta）    / tone_short1..3（兩個短音 ti-ti）
  這首對嗎 :  melody_ok1..4（正確）       / melody_bad1..4（一個音走音）

用法：
  python tool/gen_tones.py                 # 正式輸出 assets/sfx
  python tool/gen_tones.py <資料夾>         # 輸出到指定資料夾（先放桌面試聽）
需要 ffmpeg 與 numpy。
"""
import math
import os
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets", "sfx")
FFMPEG = os.environ.get(
    "FFMPEG", r"C:\src\ffmpeg\ffmpeg-8.1.1-essentials_build\bin\ffmpeg.exe")

SR = 44100

# 真實鋼琴音來源（可用環境變數覆蓋）。預設：桌面那首 Bach C 大調前奏曲。
SRC_MP3 = os.environ.get(
    "PIANO_SRC",
    os.path.join(os.path.expanduser("~"), "Desktop",
                 "背景音樂 無版權音樂 免費音樂 BGM音樂下載 歌名_ C Major Prelude "
                 "作者_ Bach  古典樂  開心音樂.mp3"))
# 取一段「剛敲下、含起音」的和弦窗（前面有 0.75s 前奏；0.97s 是一個起音點）。
# ⚠️ 只取「單一次敲擊」：曲中 C5 約每 0.66s 重敲一次（下一個 onset 在 1.63s），
# 窗若跨過會含兩次敲擊 → 長音聽起來變兩個音。故 T1 設在第二次敲擊之前。
SRC_T0, SRC_T1 = 0.97, 1.55


def freq(name):
    """音名（如 C5、F#4）→ 頻率（A4=440）。"""
    semis = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    base = semis[name[0]] + (1 if "#" in name else 0)
    n = base + (int(name[-1]) - 4) * 12 - 9
    return 440.0 * (2 ** (n / 12.0))


def _prepare_source():
    """從鋼琴錄音切窗 → 諧波篩出乾淨的 C5 單音 → 回傳 (samples, f0)。"""
    tmp = os.path.join(OUT_DIR, "_src.wav")
    os.makedirs(OUT_DIR, exist_ok=True)
    subprocess.run(
        [FFMPEG, "-y", "-ss", str(SRC_T0), "-t", str(SRC_T1 - SRC_T0),
         "-i", SRC_MP3, "-ac", "1", "-ar", str(SR), tmp],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    w = wave.open(tmp, "rb")
    seg = (np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
           .astype(np.float64) / 32768.0)
    w.close()
    os.remove(tmp)
    # 偵測 C5 附近的精確基頻
    F = np.fft.rfft(seg * np.hanning(len(seg)))
    fr = np.fft.rfftfreq(len(seg), 1 / SR)
    band = (fr > 500) & (fr < 545)
    f0 = float(fr[band][np.argmax(np.abs(F)[band])])
    # 諧波篩 + 提亮：保留 n*f0 並讓高次泛音加成（去掉 E、G、並對抗「悶」）
    F = np.fft.rfft(seg)
    fr = np.fft.rfftfreq(len(seg), 1 / SR)
    F2 = np.zeros_like(F)
    for n in range(1, 19):
        c = n * f0
        band = np.abs(fr - c) < max(5.0, 0.012 * c)
        F2[band] = F[band] * (1.0 + 0.14 * (n - 1))  # 高次泛音加成 → 更亮
    note = np.fft.irfft(F2, len(seg))
    note /= max(1e-9, np.abs(note).max())
    # 取真實鎚擊瞬態（原始寬頻、只留高頻）→ 補回清脆起音（諧波篩會把它削掉）
    raw = seg[:int(0.022 * SR)].copy()
    Fa = np.fft.rfft(raw)
    fra = np.fft.rfftfreq(len(raw), 1 / SR)
    Fa[fra < 1200] = 0
    attack = np.fft.irfft(Fa, len(raw))
    attack *= np.linspace(1, 0, len(attack)) ** 2  # 快速收掉
    attack /= max(1e-9, np.abs(attack).max())
    return note, f0, attack


_SRC_NOTE, _SRC_F0, _SRC_ATTACK = _prepare_source()


def shift(note, semitones):
    """取樣器 pitch-shift：線性重取樣（同時改音高與長度）。"""
    r = 2 ** (semitones / 12.0)
    idx = np.arange(0, len(note), r)
    return np.interp(idx, np.arange(len(note)), note)


def sampled_note(name, dur, amp=0.7, short=False):
    """把鋼琴來源音 pitch-shift 到 [name] 音高、取 [dur] 秒、整形包絡。
    [short]=True → 額外指數衰減做成 staccato（快快慢慢/短音用）。"""
    semis = 12.0 * math.log2(freq(name) / _SRC_F0)
    s = shift(_SRC_NOTE, semis)
    n = int(dur * SR)
    if len(s) < n:
        s = np.pad(s, (0, n - len(s)))
    note = s[:n].astype(np.float64)
    if short:
        t = np.arange(n) / SR
        note *= np.exp(-6.0 * t)
    fa = int(0.003 * SR)
    note[:fa] *= np.linspace(0, 1, fa)
    # 疊上真實鎚擊瞬態（pitch 跟著移）→ 清脆起音
    click = shift(_SRC_ATTACK, semis)
    m = min(len(click), n)
    note[:m] += 0.6 * click[:m]
    # 尾端淡出（避免硬切爆音）。
    fo = int(min(0.06, dur * 0.3) * SR)
    if fo > 0:
        note[-fo:] *= np.linspace(1, 0, fo)
    return amp * note


def silence(dur):
    return np.zeros(int(dur * SR))


def place(buf, samples, start_sec):
    s = int(start_sec * SR)
    e = min(len(buf), s + len(samples))
    if e > s:
        buf[s:e] += samples[:e - s]
    return buf


# ---------- 各組 clip 建構 ----------

def single(name, dur=1.1, amp=0.7):
    return sampled_note(name, dur, amp=amp)


def seq(*notes, gap=0.06, dur=0.5):
    parts = []
    for nm in notes:
        parts.append(sampled_note(nm, dur, amp=0.7))
        if gap > 0:
            parts.append(silence(gap))
    return np.concatenate(parts)


def repeated(name, count, interval, total):
    buf = np.zeros(int(total * SR))
    hit = sampled_note(name, min(interval, 0.3), amp=0.7, short=True)
    for k in range(count):
        place(buf, hit, k * interval)
    return buf


def long_note(name):
    """一個長音：單次鋼琴敲擊 + 回授梳狀殘響尾巴，把延音拉長（像踩延音踏板的尾韻），
    仍是「一個音」，只是 ring 更久——和「兩個短音」對比更明顯。"""
    note = sampled_note(name, 0.6, amp=0.7)
    out = np.zeros(int(1.9 * SR))
    out[:len(note)] = note
    # 串接數個回授梳狀延遲線 → 較密、平滑的指數衰減尾巴
    for delay, fb in [(0.037, 0.6), (0.053, 0.55), (0.071, 0.5)]:
        d = int(delay * SR)
        for i in range(d, len(out)):
            out[i] += fb * out[i - d]
    return out


def short_pair(name):
    buf = np.zeros(int(1.2 * SR))
    one = sampled_note(name, 0.28, amp=0.7, short=True)
    place(buf, one, 0.0)
    place(buf, one, 0.34)
    return buf


def melody(notes, note_dur=0.45, gap=0.05):
    parts = []
    for nm in notes:
        parts.append(sampled_note(nm, note_dur, amp=0.7))
        parts.append(silence(gap))
    return np.concatenate(parts)


def shift_name(name, semis):
    """音名升降半音 → 新音名。"""
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    semitone = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    total = semitone[name[0]] + (1 if "#" in name else 0) + int(name[-1]) * 12 + semis
    return names[total % 12] + str(total // 12)


# 這首對嗎：熟悉短曲（C 大調）＋走音點（第 wrong_i 個音升 6 個半音＝三全音）。
TUNES = [
    (["C5", "C5", "G5", "G5", "A5", "A5", "G5"], 4),          # 小星星
    (["C5", "D5", "E5", "C5", "C5", "D5", "E5", "C5"], 2),    # 兩隻老虎
    (["G5", "E5", "E5", "F5", "D5", "D5", "C5"], 3),          # 小蜜蜂
    (["C5", "C5", "D5", "C5", "F5", "E5"], 4),                # 生日快樂
]


def build_clips():
    clips = {}

    # 高高低低（高 vs 低，差約兩個八度）
    for i, nm in enumerate(["C6", "D6", "E6"], 1):
        clips[f"tone_hi{i}"] = (single(nm), True)
    for i, nm in enumerate(["C4", "D4", "E4"], 1):
        clips[f"tone_lo{i}"] = (single(nm), True)

    # 音往哪裡走（低→高 / 高→低）
    for i, (a, b) in enumerate([("C5", "C6"), ("G4", "D5"), ("E4", "B4")], 1):
        clips[f"tone_up{i}"] = (seq(a, b), True)
    for i, (a, b) in enumerate([("C6", "C5"), ("D5", "G4"), ("B4", "E4")], 1):
        clips[f"tone_down{i}"] = (seq(a, b), True)

    # 快快慢慢（密集 vs 疏落）
    for i, nm in enumerate(["A4", "C5", "F4"], 1):
        clips[f"tone_fast{i}"] = (repeated(nm, 9, 0.26, 2.5), True)
    for i, nm in enumerate(["A4", "C5", "F4"], 1):
        clips[f"tone_slow{i}"] = (repeated(nm, 3, 0.85, 2.5), True)

    # 大聲小聲（同音高、只差音量；整組共用縮放、不正規化）
    dyn = {}
    for i, nm in enumerate(["C5", "E5", "G5"], 1):
        dyn[f"tone_loud{i}"] = single(nm, amp=0.95)
    for i, nm in enumerate(["C5", "E5", "G5"], 1):
        dyn[f"tone_soft{i}"] = single(nm, amp=0.22)
    gpeak = max(1e-6, max(float(np.abs(s).max()) for s in dyn.values()))
    g = 0.9 / gpeak
    for name, s in dyn.items():
        clips[name] = (s * g, False)

    # 音的長短（一個長音 vs 兩個短音）
    for i, nm in enumerate(["C5", "E5", "G5"], 1):
        clips[f"tone_long{i}"] = (long_note(nm), True)
    for i, nm in enumerate(["C5", "E5", "G5"], 1):
        clips[f"tone_short{i}"] = (short_pair(nm), True)

    # 這首對嗎（正確 vs 走音）
    for i, (notes, wrong_i) in enumerate(TUNES, 1):
        clips[f"melody_ok{i}"] = (melody(notes), True)
        bad = list(notes)
        bad[wrong_i] = shift_name(bad[wrong_i], 6)
        clips[f"melody_bad{i}"] = (melody(bad), True)

    return clips


def write_mp3(name, samples, do_norm):
    wav = os.path.join(OUT_DIR, f"_{name}.wav")
    mp3 = os.path.join(OUT_DIR, f"{name}.mp3")
    if do_norm:
        scale = 0.97 / max(1e-9, float(np.abs(samples).max()))
    else:
        scale = 1.0  # 大聲小聲：已整組共用縮放，不可再各自正規化
    data = np.clip(samples * scale, -1, 1)
    pcm = (data * 32767).astype("<i2")
    w = wave.open(wav, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
    w.close()
    # treble 提亮（對抗悶）；大聲小聲組同樣 EQ、相對音量不變。
    bright = "treble=g=3:f=3000"
    af = (f"{bright},loudnorm=I=-16:TP=-1.5" if do_norm
          else f"{bright},aresample=44100")
    subprocess.run(
        [FFMPEG, "-y", "-i", wav, "-af", af,
         "-codec:a", "libmp3lame", "-q:a", "5", mp3],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.remove(wav)
    return os.path.getsize(mp3)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"來源鋼琴音 f0 = {_SRC_F0:.1f} Hz（諧波篩出的 C5 單音）")
    clips = build_clips()
    total = 0
    for name, (samples, do_norm) in clips.items():
        size = write_mp3(name, samples, do_norm)
        total += size
        print(f"{name}.mp3 -> {size} bytes" + ("" if do_norm else "  (no-norm)"))
    print(f"完成：{len(clips)} 個 tone clip，共 {total // 1024} KB。輸出：{OUT_DIR}")


if __name__ == "__main__":
    main()
