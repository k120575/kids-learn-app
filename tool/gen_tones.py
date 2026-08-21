# -*- coding: utf-8 -*-
"""
合成「音樂領域聽辨遊戲」用的 tone clip → assets/sfx/。

音色來源：真實鋼琴錄音（Bach C 大調前奏曲）。因為該曲是連續的 C 大調琶音
（每一刻都是 C-E-G 和弦、踏板延音），無法直接切出乾淨的單音；改用
**FFT 諧波篩（harmonic sieve）**：從和弦窗只保留某個基頻（C5）及其整數泛音、
其餘歸零，反 FFT 還原出「一個真實鋼琴音色的 C5 單音」，再用取樣器 pitch-shift
到各音高，組成各遊戲所需 clip。

產出（每組多個變體）：
  高高低低 :  tone_hi1..4（高）          / tone_lo1..4（低，差約兩個八度）
  音往哪裡走: tone_up1..4（低→高）       / tone_down1..4（高→低）
  快快慢慢 :  tone_fast1..4（密集）       / tone_slow1..4（疏落）
  大聲小聲 :  tone_loud1..3（大）         / tone_soft1..3（同音高、小聲）★不正規化
  音的長短 :  tone_long1..4（長音 ta）    / tone_short1..4（兩個短音 ti-ti）
  這首對嗎 :  melody_ok1..4（正確）       / melody_bad1..4（一個音走音）

hard 變體（適性難度「挑戰」階用，檔名 *_h*）：對比縮小但仍可辨——
  高高低低 :  tone_hi_h / tone_lo_h（差約一個八度，非兩個）
  音往哪裡走: tone_up_h / tone_down_h（音程縮到 3~4 個半音）
  快快慢慢 :  tone_fast_h / tone_slow_h（速度差 ~1.9:1，非 3.3:1）
  大聲小聲 :  tone_loud_h / tone_soft_h（差 ~6dB，非 ~13dB）★同組共用縮放
  音的長短 :  tone_long_h / tone_short_h（長音較短、短音較拖）
  這首對嗎 :  melody_bad_h1..4（微離調：走音只差 1~2 個半音、仍出調）

用法：
  python tool/gen_tones.py                 # 只產缺的檔（不動已出貨的 clip）
  python tool/gen_tones.py --force         # 全部重產
  python tool/gen_tones.py <資料夾>         # 輸出到指定資料夾（先放桌面試聽）
需要 ffmpeg 與 numpy。

⚠️ 原始鋼琴來源（桌面 Bach mp3）若已刪除，會自動改用 assets/sfx/tone_loud1.mp3
（本工具先前產出的乾淨 C5 單音、無 loudnorm）bootstrap——此時只該「補產新檔」，
不要 --force 重產舊檔（音色會有極小漂移）。
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

# 真實鋼琴音來源（可用環境變數覆蓋）。
# 預設（2026-08-21 起）：University of Iowa MIS 的 Piano.mf.C5.aiff——
# 一顆乾淨的真實鋼琴 C5 單音（theremin.music.uiowa.edu，授權聲明
# 「may be downloaded and used for any projects, without restrictions」，
# 查證 2026-08-21）。已入庫 tool/piano_src/，來源不會再弄丟。
# 單音來源用 onset 自動偵測取窗，不需手調 T0/T1。
SRC_NOTE_AIFF = os.path.join(ROOT, "tool", "piano_src", "Piano.mf.C5.aiff")
# 舊來源（桌面 Bach C 大調前奏曲，已刪；留路徑當歷史紀錄/後備）。
SRC_MP3 = os.environ.get(
    "PIANO_SRC",
    os.path.join(os.path.expanduser("~"), "Desktop",
                 "背景音樂 無版權音樂 免費音樂 BGM音樂下載 歌名_ C Major Prelude "
                 "作者_ Bach  古典樂  開心音樂.mp3"))
# Bach 路徑用：取一段「剛敲下、含起音」的和弦窗（0.97s 是一個起音點）。
# ⚠️ 只取「單一次敲擊」：曲中 C5 約每 0.66s 重敲一次，窗跨過會含兩次敲擊。
SRC_T0, SRC_T1 = 0.97, 1.55


def freq(name):
    """音名（如 C5、F#4）→ 頻率（A4=440）。"""
    semis = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    base = semis[name[0]] + (1 if "#" in name else 0)
    n = base + (int(name[-1]) - 4) * 12 - 9
    return 440.0 * (2 ** (n / 12.0))


def _load_wav_mono(path, t0=None, t1=None):
    """用 ffmpeg 把任意音檔解成 mono float64（可選切窗）。"""
    tmp = os.path.join(OUT_DIR, "_src.wav")
    os.makedirs(OUT_DIR, exist_ok=True)
    cmd = [FFMPEG, "-y"]
    if t0 is not None:
        cmd += ["-ss", str(t0), "-t", str(t1 - t0)]
    cmd += ["-i", path, "-ac", "1", "-ar", str(SR), tmp]
    subprocess.run(cmd, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    w = wave.open(tmp, "rb")
    seg = (np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
           .astype(np.float64) / 32768.0)
    w.close()
    os.remove(tmp)
    return seg


def _bootstrap_source():
    """原始 Bach mp3 已不在時的後備：拿本工具先前產出的 tone_loud1.mp3
    （乾淨 C5 單音、dynamics 組不做 loudnorm、只加過一次 treble EQ）當來源。
    鎚擊瞬態已烤在裡面 → attack 回傳 None，sampled_note 不再疊 click；
    treble 也已加過 → write_mp3 不再提亮（避免二次 EQ 造成音色漂移）。"""
    boot = os.path.join(ROOT, "assets", "sfx", "tone_loud1.mp3")
    if not os.path.exists(boot):
        raise SystemExit(
            "找不到鋼琴來源：原始 Bach mp3 與 assets/sfx/tone_loud1.mp3 都不存在。")
    seg = _load_wav_mono(boot)
    seg = seg / max(1e-9, np.abs(seg).max())
    F = np.fft.rfft(seg * np.hanning(len(seg)))
    fr = np.fft.rfftfreq(len(seg), 1 / SR)
    band = (fr > 500) & (fr < 545)
    f0 = float(fr[band][np.argmax(np.abs(F)[band])])
    return seg, f0, None


def _sieve_c5(seg):
    """對一段含 C5 的音訊窗做諧波篩＋鎚擊瞬態抽取 → (note, f0, attack)。
    （與原 Bach 流程相同：保留 n*f0 泛音、高次加成提亮、起音高頻補回。）"""
    F = np.fft.rfft(seg * np.hanning(len(seg)))
    fr = np.fft.rfftfreq(len(seg), 1 / SR)
    band = (fr > 500) & (fr < 545)
    f0 = float(fr[band][np.argmax(np.abs(F)[band])])
    F = np.fft.rfft(seg)
    fr = np.fft.rfftfreq(len(seg), 1 / SR)
    F2 = np.zeros_like(F)
    for n in range(1, 19):
        c = n * f0
        b = np.abs(fr - c) < max(5.0, 0.012 * c)
        F2[b] = F[b] * (1.0 + 0.14 * (n - 1))
    note = np.fft.irfft(F2, len(seg))
    note /= max(1e-9, np.abs(note).max())
    raw = seg[:int(0.022 * SR)].copy()
    Fa = np.fft.rfft(raw)
    fra = np.fft.rfftfreq(len(raw), 1 / SR)
    Fa[fra < 1200] = 0
    attack = np.fft.irfft(Fa, len(raw))
    attack *= np.linspace(1, 0, len(attack)) ** 2
    attack /= max(1e-9, np.abs(attack).max())
    return note, f0, attack


def _prepare_from_single_note(path):
    """乾淨的鋼琴 C5 單音檔（Iowa MIS / 使用者自錄）：onset 自動偵測取窗。"""
    seg = _load_wav_mono(path)
    peak = max(1e-9, float(np.abs(seg).max()))
    onset = int(np.argmax(np.abs(seg) > 0.1 * peak))
    seg = seg[onset:onset + int(0.58 * SR)]
    seg = seg / max(1e-9, np.abs(seg).max())
    return _sieve_c5(seg)


def _prepare_source():
    """來源優先序：PIANO_SRC 環境變數（單音檔）→ tool/piano_src 的 Iowa C5
    單音 → 桌面 Bach 錄音（歷史路徑）→ bootstrap 自 tone_loud1.mp3。
    回傳 (samples, f0, attack)。"""
    env = os.environ.get("PIANO_SRC")
    if env and os.path.exists(env):
        return _prepare_from_single_note(env)
    if os.path.exists(SRC_NOTE_AIFF):
        return _prepare_from_single_note(SRC_NOTE_AIFF)
    if not os.path.exists(SRC_MP3):
        return _bootstrap_source()
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
    return _sieve_c5(seg)


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
    # 疊上真實鎚擊瞬態（pitch 跟著移）→ 清脆起音。bootstrap 來源已內含，不再疊。
    if _SRC_ATTACK is not None:
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


def long_note(name, tail=1.9, combs=3):
    """一個長音：單次鋼琴敲擊 + 回授梳狀殘響尾巴，把延音拉長（像踩延音踏板的尾韻），
    仍是「一個音」，只是 ring 更久——和「兩個短音」對比更明顯。
    [tail]=總長秒數、[combs]=梳狀延遲線數（hard 變體用較短較少 → 沒那麼明顯長）。"""
    note = sampled_note(name, 0.6, amp=0.7)
    out = np.zeros(int(tail * SR))
    out[:len(note)] = note
    # 串接數個回授梳狀延遲線 → 較密、平滑的指數衰減尾巴
    for delay, fb in [(0.037, 0.6), (0.053, 0.55), (0.071, 0.5)][:combs]:
        d = int(delay * SR)
        for i in range(d, len(out)):
            out[i] += fb * out[i - d]
    return out


def short_pair(name, dur=0.28, second=0.34):
    """兩個短音。[dur]=單音長、[second]=第二聲起點（hard 變體稍拖、較不 staccato）。"""
    buf = np.zeros(int((second + dur + 0.6) * SR))
    one = sampled_note(name, dur, amp=0.7, short=True)
    place(buf, one, 0.0)
    place(buf, one, second)
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


def _in_c_major(name):
    semitone = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    pc = (semitone[name[0]] + (1 if "#" in name else 0)) % 12
    return pc in (0, 2, 4, 5, 7, 9, 11)


def _detune_subtle(name):
    """微離調：先試 +1 半音；若結果仍在 C 大調內（不夠「走音」），改 -1。"""
    up = shift_name(name, 1)
    return up if not _in_c_major(up) else shift_name(name, -1)


def build_clips():
    clips = {}

    # 高高低低（高 vs 低，差約兩個八度）
    for i, nm in enumerate(["C6", "D6", "E6", "F6"], 1):
        clips[f"tone_hi{i}"] = (single(nm), True)
    for i, nm in enumerate(["C4", "D4", "E4", "B3"], 1):
        clips[f"tone_lo{i}"] = (single(nm), True)
    # hard：差約一個八度（邊界壓向中央 C 附近）
    for i, nm in enumerate(["F5", "G5", "A5"], 1):
        clips[f"tone_hi_h{i}"] = (single(nm), True)
    for i, nm in enumerate(["E4", "F4", "G4"], 1):
        clips[f"tone_lo_h{i}"] = (single(nm), True)

    # 音往哪裡走（低→高 / 高→低）
    for i, (a, b) in enumerate(
            [("C5", "C6"), ("G4", "D5"), ("E4", "B4"), ("F4", "F5")], 1):
        clips[f"tone_up{i}"] = (seq(a, b), True)
    for i, (a, b) in enumerate(
            [("C6", "C5"), ("D5", "G4"), ("B4", "E4"), ("F5", "F4")], 1):
        clips[f"tone_down{i}"] = (seq(a, b), True)
    # hard：音程縮到 3~4 個半音
    for i, (a, b) in enumerate([("C5", "E5"), ("G4", "B4"), ("A4", "C5")], 1):
        clips[f"tone_up_h{i}"] = (seq(a, b), True)
    for i, (a, b) in enumerate([("E5", "C5"), ("B4", "G4"), ("C5", "A4")], 1):
        clips[f"tone_down_h{i}"] = (seq(a, b), True)

    # 快快慢慢（密集 vs 疏落，約 3.3:1）
    for i, nm in enumerate(["A4", "C5", "F4", "D5"], 1):
        clips[f"tone_fast{i}"] = (repeated(nm, 9, 0.26, 2.5), True)
    for i, nm in enumerate(["A4", "C5", "F4", "D5"], 1):
        clips[f"tone_slow{i}"] = (repeated(nm, 3, 0.85, 2.5), True)
    # hard：速度差縮到約 1.9:1（快 ~171BPM vs 慢 ~92BPM）
    for i, nm in enumerate(["A4", "C5", "F4"], 1):
        clips[f"tone_fast_h{i}"] = (repeated(nm, 7, 0.35, 2.5), True)
    for i, nm in enumerate(["A4", "C5", "F4"], 1):
        clips[f"tone_slow_h{i}"] = (repeated(nm, 4, 0.65, 2.5), True)

    # 大聲小聲（同音高、只差音量；整組共用縮放、不正規化）
    # hard：差距縮到 ~6dB（base 約 13dB）。同組共用縮放才保得住相對響度。
    dyn = {}
    for i, nm in enumerate(["C5", "E5", "G5"], 1):
        dyn[f"tone_loud{i}"] = single(nm, amp=0.95)
    for i, nm in enumerate(["C5", "E5", "G5"], 1):
        dyn[f"tone_soft{i}"] = single(nm, amp=0.22)
    for i, nm in enumerate(["C5", "E5", "G5"], 1):
        dyn[f"tone_loud_h{i}"] = single(nm, amp=0.80)
    for i, nm in enumerate(["C5", "E5", "G5"], 1):
        dyn[f"tone_soft_h{i}"] = single(nm, amp=0.40)
    gpeak = max(1e-6, max(float(np.abs(s).max()) for s in dyn.values()))
    g = 0.9 / gpeak
    for name, s in dyn.items():
        clips[name] = (s * g, False)

    # 音的長短（一個長音 vs 兩個短音）
    for i, nm in enumerate(["C5", "E5", "G5", "D5"], 1):
        clips[f"tone_long{i}"] = (long_note(nm), True)
    for i, nm in enumerate(["C5", "E5", "G5", "D5"], 1):
        clips[f"tone_short{i}"] = (short_pair(nm), True)
    # hard：長音殘響較短、短音較拖 → 兩者時值差縮小但仍可辨
    for i, nm in enumerate(["C5", "E5", "G5"], 1):
        clips[f"tone_long_h{i}"] = (long_note(nm, tail=1.3, combs=2), True)
    for i, nm in enumerate(["C5", "E5", "G5"], 1):
        clips[f"tone_short_h{i}"] = (short_pair(nm, dur=0.34, second=0.44), True)

    # 這首對嗎（正確 vs 走音）
    for i, (notes, wrong_i) in enumerate(TUNES, 1):
        clips[f"melody_ok{i}"] = (melody(notes), True)
        bad = list(notes)
        bad[wrong_i] = shift_name(bad[wrong_i], 6)
        clips[f"melody_bad{i}"] = (melody(bad), True)
        # hard：微離調（1~2 個半音、仍出 C 大調）
        bad_h = list(notes)
        bad_h[wrong_i] = _detune_subtle(bad_h[wrong_i])
        clips[f"melody_bad_h{i}"] = (melody(bad_h), True)

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
    # bootstrap 來源（_SRC_ATTACK is None）已帶過一次 treble → 不再提亮。
    bright = "anull" if _SRC_ATTACK is None else "treble=g=3:f=3000"
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
    src = "原始錄音諧波篩" if _SRC_ATTACK is not None else "bootstrap(tone_loud1)"
    print(f"來源鋼琴音 f0 = {_SRC_F0:.1f} Hz（{src}）")
    clips = build_clips()
    total = 0
    written = 0
    skipped = 0
    for name, (samples, do_norm) in clips.items():
        if not FORCE and os.path.exists(os.path.join(OUT_DIR, f"{name}.mp3")):
            skipped += 1
            continue
        size = write_mp3(name, samples, do_norm)
        total += size
        written += 1
        print(f"{name}.mp3 -> {size} bytes" + ("" if do_norm else "  (no-norm)"))
    print(f"完成：新寫 {written} 個（跳過既有 {skipped} 個，--force 可重產），"
          f"共 {total // 1024} KB。輸出：{OUT_DIR}")


if __name__ == "__main__":
    main()
