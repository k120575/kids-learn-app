import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../content/voice_manifest.dart';
import 'progress_store.dart';

/// 全 App 的聲音出口：
/// - 語音：優先播放預先烤好的「HsiaoChen 國語音檔」（`assets/voice/<md5>.mp3`），
///   發音標準一致、完全離線；找不到對應音檔才退回裝置內建 TTS。
/// - 背景音樂：輕鬆無歌詞循環（`assets/music/bgm.mp3`）。**講話/出題時自動壓低
///   音量（ducking），講完再恢復**，不蓋過語音與題目音效。
/// - 點擊回饋：系統音效 + 觸覺回饋。
///
/// 音檔由 `tool/gen_voice.py`（edge-tts）產生，雜湊集合在 voice_manifest.dart；
/// 背景音樂由 `tool/gen_bgm.py` 合成。
class AudioService with WidgetsBindingObserver {
  AudioService._();
  static final AudioService instance = AudioService._();

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _voice = AudioPlayer(); // 語音
  final AudioPlayer _sfx = AudioPlayer(); // 題目音效（動物/樂器）
  final AudioPlayer _beat = AudioPlayer(); // 節奏鼓聲
  final AudioPlayer _cheer = AudioPlayer(); // 答對歡呼音
  final AudioPlayer _bgm = AudioPlayer(); // 背景音樂（循環）
  // 分開播放器：避免「歡呼音被下一題的動物聲切掉」「最後一拍被歡呼切掉」。

  // ----- 背景音樂閃避（ducking）-----
  /// 目前正在「講話/出題」的播放器集合；非空 → 壓低背景音樂。
  final Set<AudioPlayer> _talking = <AudioPlayer>{};
  Timer? _restoreTimer;
  bool _bgmPlaying = false;

  /// 背景音樂是否「因切到背景而被暫停」（回前景時據此決定要不要接著播）。
  bool _bgmPausedByLifecycle = false;

  /// 語音閘門：speak/speakForDuration 時「同步」開啟，語音自然播完
  /// （onPlayerComplete）或被 stop 時關閉。waitUntilVoiceIdle 等這個 gate，
  /// 確保「題目/音效」一定等關卡名稱（或上一句）念完才出聲。
  /// 用 gate 而非查 _voice.state：play() 還沒切到 playing 狀態時查 state 會誤判成
  /// 「沒在播」而不等待 → 聲音重疊。gate 在 speak 呼叫當下同步開啟，不會有此競態。
  Completer<void>? _voiceGate;

  /// 壓低時的音量倍率（相對使用者設定的背景音量）。
  static const double _duckFactor = 0.25;

  Future<void> init() async {
    try {
      // audio context：所有播放器「混音、互不搶焦點」。
      // 預設 gain 會讓每個播放器各自 requestAudioFocus(GAIN)，後播的會搶走焦點、
      // 把背景音樂暫停掉 → 改用 mixWithOthers（Android focus none）由我們自己用
      // 音量做 ducking。必須「逐一」設定（這些播放器在 setAudioContext 前就建立，
      // 不會自動套用全域設定）。
      final AudioContext ctx =
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build();
      await AudioPlayer.global.setAudioContext(ctx);
      for (final AudioPlayer pl in <AudioPlayer>[
        _voice,
        _sfx,
        _beat,
        _cheer,
        _bgm
      ]) {
        await pl.setAudioContext(ctx);
      }
    } catch (_) {}
    try {
      for (final AudioPlayer pl in <AudioPlayer>[_voice, _sfx, _beat, _cheer]) {
        await pl.setReleaseMode(ReleaseMode.stop);
      }
      await _bgm.setReleaseMode(ReleaseMode.loop); // 背景音樂循環
    } catch (_) {}
    // 監聽「會講話的播放器」狀態，動態壓低/恢復背景音樂。
    for (final AudioPlayer pl in <AudioPlayer>[_voice, _sfx, _beat]) {
      pl.onPlayerStateChanged.listen((PlayerState st) => _onTalkState(pl, st));
    }
    // 語音自然播完 → 關閉語音閘門（讓等待中的題目/音效接著播）。
    _voice.onPlayerComplete.listen((_) => _closeVoiceGate());
    // 監聽 App 生命週期：切到背景時暫停音訊，省電（不然背景音樂會一直播）。
    WidgetsBinding.instance.addObserver(this);
    try {
      await _tts.setLanguage('zh-TW');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.1);
      // false：發出即返回，不可阻塞遊戲流程。
      await _tts.awaitSpeakCompletion(false);
    } catch (_) {}
    // 依設定啟動背景音樂。
    if (ProgressStore.instance.musicEnabled) {
      await startBgm();
    }
  }

  /// App 切到背景/回前景時的音訊處理：背景時暫停背景音樂、停掉語音與音效，
  /// 避免在背景持續發聲耗電；回前景且音樂仍開著時無縫接著播。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_bgmPausedByLifecycle) {
          _bgmPausedByLifecycle = false;
          // 用 startBgm 重新播放（比 resume 穩：長時間背景後播放器可能被系統回收，
          // resume 會失敗；startBgm 內部會自行檢查音樂是否開啟）。
          startBgm().catchError((Object _) {});
        }
        break;
      case AppLifecycleState.inactive:
        break; // 短暫狀態（如下拉通知）不處理，避免一直暫停/恢復閃爍
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_bgmPlaying) _bgmPausedByLifecycle = true;
        _bgm.pause().catchError((Object _) {});
        _closeVoiceGate();
        for (final AudioPlayer pl in <AudioPlayer>[
          _voice,
          _sfx,
          _beat,
          _cheer
        ]) {
          pl.stop().catchError((Object _) {});
        }
        _tts.stop().catchError((Object _) {});
        break;
    }
  }

  bool get _enabled => ProgressStore.instance.soundEnabled;

  String _key(String text) =>
      md5.convert(utf8.encode(text)).toString().substring(0, 16);

  // ===================== 背景音樂 =====================

  /// 開始（或恢復）播放背景音樂。未啟用或缺檔則安靜略過。
  ///
  /// 注意：音量必須透過 [play] 的 volume 參數帶入。Android MediaPlayer 在「尚未
  /// 設定音源」時呼叫 setVolume 會進入錯誤狀態（error -38）導致整個播放失敗，
  /// 所以這裡不可先 setVolume 再 play。
  Future<void> startBgm() async {
    if (!ProgressStore.instance.musicEnabled) return;
    try {
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.play(
        AssetSource('music/bgm.mp3'),
        volume: _targetBgmVolume(),
      );
      _bgmPlaying = true;
    } catch (_) {
      _bgmPlaying = false; // 缺檔：保持安靜，不影響其他功能
    }
  }

  Future<void> stopBgm() async {
    _bgmPlaying = false;
    try {
      await _bgm.stop();
    } catch (_) {}
  }

  /// 設定改變（開關/音量）時呼叫，即時生效。
  Future<void> applyMusicSetting() async {
    if (ProgressStore.instance.musicEnabled) {
      if (_bgmPlaying) {
        await _bgm.setVolume(_targetBgmVolume());
      } else {
        await startBgm();
      }
    } else {
      await stopBgm();
    }
  }

  double _targetBgmVolume() {
    final double base = ProgressStore.instance.musicVolume;
    return _talking.isEmpty ? base : base * _duckFactor;
  }

  void _onTalkState(AudioPlayer pl, PlayerState st) {
    if (st == PlayerState.playing) {
      _talking.add(pl);
      _restoreTimer?.cancel();
      _applyBgmVolume();
    } else {
      // stopped / completed / paused → 該來源講完了。
      if (_talking.remove(pl) && _talking.isEmpty) {
        // 稍微延遲再恢復，避免「兩段語音之間」音量忽高忽低的抖動。
        _restoreTimer?.cancel();
        _restoreTimer = Timer(const Duration(milliseconds: 350), () {
          if (_talking.isEmpty) _applyBgmVolume();
        });
      }
    }
  }

  void _applyBgmVolume() {
    if (!_bgmPlaying) return;
    _bgm.setVolume(_targetBgmVolume()).catchError((Object _) {});
  }

  // ===================== 語音 =====================

  /// 開啟語音閘門（同步）。放掉上一個等待者再建新的。
  void _openVoiceGate() {
    final Completer<void>? old = _voiceGate;
    if (old != null && !old.isCompleted) old.complete();
    _voiceGate = Completer<void>();
  }

  /// 關閉語音閘門：喚醒所有 waitUntilVoiceIdle 的等待者。
  void _closeVoiceGate() {
    final Completer<void>? g = _voiceGate;
    if (g != null && !g.isCompleted) g.complete();
    _voiceGate = null;
  }

  /// 念一段話：只播烤好的國語音檔。沒有對應音檔就「不出聲」，
  /// 絕不使用裝置內建 TTS（那會是外國腔的爛中文，且會與音檔疊在一起）。
  Future<void> speak(String text) async {
    if (!_enabled || text.isEmpty) return;
    final String key = _key(text);
    if (!voiceManifest.contains(key)) return; // 沒烤的就靜音
    _openVoiceGate(); // 同步開閘：保證緊接著（甚至下一個 frame）的 waitUntilVoiceIdle 等得到
    try {
      await _voice.stop();
      await _voice.play(AssetSource('voice/$key.mp3'));
    } catch (_) {
      _closeVoiceGate();
    }
  }

  /// 等目前的語音（speak，例如剛進關卡時念的關卡名稱）播完才返回；
  /// 逾時保護避免卡住。用來確保題目/音效不會蓋過關卡名稱或上一句提示。
  Future<void> waitUntilVoiceIdle(
      {Duration timeout = const Duration(seconds: 5)}) async {
    final Completer<void>? gate = _voiceGate;
    if (gate == null || gate.isCompleted) return;
    try {
      await gate.future.timeout(timeout);
    } catch (_) {}
  }

  /// 念一段話，但先等目前的語音（通常是進場時念的關卡名稱）播完再念，
  /// 避免第一句題目/提示蓋掉關卡名稱。用於每個遊戲「進場後的第一句」。
  Future<void> speakAfterVoice(String text) async {
    await waitUntilVoiceIdle();
    await speak(text);
  }

  Future<void> stop() async {
    _closeVoiceGate(); // 被打斷時也要放掉等待者，避免卡住
    for (final AudioPlayer pl in <AudioPlayer>[_voice, _sfx, _beat, _cheer]) {
      try {
        await pl.stop();
      } catch (_) {}
    }
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// 念一段話並「等它播完」才返回（用於需要先講完再做下一步，例如節奏示範）。
  Future<void> speakAndWait(String text) async {
    if (!_enabled || text.isEmpty) return;
    final String key = _key(text);
    if (!voiceManifest.contains(key)) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return;
    }
    _openVoiceGate();
    try {
      await _voice.stop();
      await _voice.play(AssetSource('voice/$key.mp3'));
      await _voice.onPlayerComplete.first
          .timeout(const Duration(seconds: 3), onTimeout: () {});
    } catch (_) {
      _closeVoiceGate();
    }
  }

  /// 念一段話，並等「實際音檔長度 + [extra]」才返回（用 getDuration 取得真實長度，
  /// 不靠不可靠的完成事件）。節奏示範用：確保語音念完再敲鼓、不疊聲。
  Future<void> speakForDuration(String text,
      {Duration extra = const Duration(milliseconds: 500)}) async {
    if (!_enabled || text.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return;
    }
    final String key = _key(text);
    if (!voiceManifest.contains(key)) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      return;
    }
    _openVoiceGate();
    try {
      await _voice.stop();
      await _voice.setSource(AssetSource('voice/$key.mp3'));
      final Duration? d = await _voice.getDuration();
      await _voice.resume();
      // 取不到長度時用保守的 2.8s 後備（最長提示語約 2.7s），避免鼓聲疊到語音。
      await Future<void>.delayed(
          (d ?? const Duration(milliseconds: 2800)) + extra);
    } catch (_) {
      _closeVoiceGate();
      await Future<void>.delayed(const Duration(milliseconds: 2800));
    }
  }

  Future<bool> _playOn(AudioPlayer pl, String file) async {
    if (!_enabled) return false;
    try {
      await pl.stop();
      await pl.play(AssetSource('sfx/$file'));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 題目音效（動物/樂器，`assets/sfx/<file>`）。缺檔回傳 false（退回語音）。
  /// 先等關卡名稱/上一句語音念完，避免聲音與語音重疊。
  Future<bool> playSfx(String file) async {
    await waitUntilVoiceIdle();
    return _playOn(_sfx, file);
  }

  /// 播題目音效並「等它播完」才返回（用實際長度）。
  /// 用於聽音辨識遊戲（聲音尋寶/樂器配對）：必須先聽完聲音才開放作答。
  /// 缺檔或關音回傳 false（呼叫端退回語音提示）。
  Future<bool> playSfxAndWait(String file) async {
    if (!_enabled) return false;
    await waitUntilVoiceIdle(); // 先讓關卡名稱/上一句語音念完，避免重疊
    try {
      await _sfx.stop();
      await _sfx.setSource(AssetSource('sfx/$file'));
      final Duration? d = await _sfx.getDuration();
      await _sfx.resume();
      await Future<void>.delayed(
          (d ?? const Duration(milliseconds: 1500)) +
              const Duration(milliseconds: 300));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 節奏鼓聲（獨立播放器，不會被歡呼音切掉）。
  /// 先等關卡名稱/上一句語音念完，避免鼓聲與語音重疊。
  Future<bool> playBeat(String file) async {
    await waitUntilVoiceIdle();
    return _playOn(_beat, file);
  }

  /// 答對歡呼音（獨立播放器，不會被下一題音效切掉）。
  Future<bool> playCheer(String file) => _playOn(_cheer, file);

  /// 點擊回饋。
  Future<void> tap() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static const List<String> _praises = <String>[
    '太棒了！',
    '答對了！',
    '你好厲害！',
    '你做到了！',
    '好棒喔！',
  ];
  int _praiseIdx = 0;

  /// 答對：觸覺 + 歡呼音（有 success 音檔就播，沒有則念鼓勵語）。
  Future<void> correct() async {
    try {
      await HapticFeedback.lightImpact();
      final bool cheered = await playCheer('success.mp3');
      if (!cheered) {
        final String p = _praises[_praiseIdx % _praises.length];
        _praiseIdx++;
        await speak(p);
      }
    } catch (_) {}
  }

  /// 答錯：溫和提示，不責備。
  Future<void> wrong() async {
    try {
      await HapticFeedback.mediumImpact();
      await speak('再試一次');
    } catch (_) {}
  }

  /// 完成一個遊戲。
  Future<void> finished() async {
    await speak('全部完成，好棒！');
  }
}
