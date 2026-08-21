import '../games/listen_choose_game.dart';
import '../games/pick_game.dart';

/// 樂器點選配對：真實樂器聲題庫（全 bigsoundbank CC0），每局隨機抽題。
/// 僅收錄有乾淨 CC0 音效＋清楚 emoji 的樂器（鋼琴/吉他因無 CC0 音效移除）。
const List<(String, String)> instruments = <(String, String)>[
  ('snare.mp3', '🥁'),
  ('bell.mp3', '🔔'),
  ('trumpet.mp3', '🎺'),
  ('violin.mp3', '🎻'),
  ('shaker.mp3', '🪇'),
];
final List<PickRound> instrumentBank = buildSoundRounds(
  instruments,
  '這是什麼樂器的聲音？',
);

/// 4-5 歲第二套樂器（合成，tool/gen_instruments.py；emoji 已驗過在 bundled
/// NotoColorEmoji 內）。與 3-4 那套零重疊——instrument_45 是試玩關，原本跟
/// 3-4 樂器配對共用同 5 個音檔，付費前後聽到一模一樣的內容（試玩關互撞）。
const List<(String, String)> instruments45 = <(String, String)>[
  ('inst_piano.mp3', '🎹'),
  ('inst_guitar.mp3', '🎸'),
  ('inst_conga.mp3', '🪘'),
  ('inst_accordion.mp3', '🪗'),
  ('inst_flute.mp3', '🪈'),
];

/// 4-5 歲加難版：每題多一個干擾項（共 5 選項＝全部樂器一起出），辨音更難。
final List<PickRound> instrumentBank45 = buildSoundRounds(
  instruments45,
  '這是什麼樂器的聲音？',
  distractors: 4,
);

// ===================== 聽辨音樂屬性（ListenChooseGame）=====================
// tone clip 由 tool/gen_tones.py 合成（assets/sfx/tone_*.mp3）。
// 每組答案卡固定不洗牌：靠「聽聲音」決定點哪張，位置（含上/下）本身就是要教的對應。
// 每關兩個題池：base（難度 0/1）與 hard（挑戰階＝levelFor==2，*_h clip，
// 對比縮小：較小音程/較近速度差/較近音量差/微離調）。

/// 從兩組音檔建題庫：a 組正解 = 第 0 張卡、b 組正解 = 第 1 張卡。
List<SoundQuestion> _twoWay(List<String> a, List<String> b) => <SoundQuestion>[
  for (final String s in a) SoundQuestion(s, 0),
  for (final String s in b) SoundQuestion(s, 1),
];

/// 產檔名序列：tone_hi → [tone_hi1.mp3 ... tone_hiN.mp3]。
List<String> _n(String stem, int count) => <String>[
  for (int i = 1; i <= count; i++) '$stem$i.mp3',
];

// ---- 3-4 高高低低：音高（base 差約兩個八度 / hard 差約一個八度）----
const List<SoundChoice> pitchHiLoChoices = <SoundChoice>[
  SoundChoice('🐦', '高'), // 上：高高的鳥
  SoundChoice('🐘', '低'), // 下：低低的象
];
final List<SoundQuestion> pitchHiLoBank = _twoWay(
  _n('tone_hi', 4),
  _n('tone_lo', 4),
);
final List<SoundQuestion> pitchHiLoBankHard = _twoWay(
  _n('tone_hi_h', 3),
  _n('tone_lo_h', 3),
);

// ---- 3-4 快快慢慢：速度（base ~3.3:1 / hard ~1.9:1）----
const List<SoundChoice> tempoChoices = <SoundChoice>[
  SoundChoice('🐇', '快'),
  SoundChoice('🐢', '慢'),
];
final List<SoundQuestion> tempoBank = _twoWay(
  _n('tone_fast', 4),
  _n('tone_slow', 4),
);
final List<SoundQuestion> tempoBankHard = _twoWay(
  _n('tone_fast_h', 3),
  _n('tone_slow_h', 3),
);

// ---- 4-5 大聲小聲：力度（base 差 ~13dB / hard 差 ~6dB）----
const List<SoundChoice> dynamicsChoices = <SoundChoice>[
  SoundChoice('🦁', '大聲'),
  SoundChoice('🐭', '小聲'),
];
final List<SoundQuestion> dynamicsBank = _twoWay(
  _n('tone_loud', 3),
  _n('tone_soft', 3),
);
final List<SoundQuestion> dynamicsBankHard = _twoWay(
  _n('tone_loud_h', 3),
  _n('tone_soft_h', 3),
);

// ---- 4-5 音的長短：時值（一個長音 ta / 兩個短音 ti-ti；hard 時值差縮小）----
const List<SoundChoice> durationChoices = <SoundChoice>[
  SoundChoice('🎵', '一個長音', child: DurationGlyph(long: true)),
  SoundChoice('🎵🎵', '兩個短音', child: DurationGlyph(long: false)),
];
final List<SoundQuestion> durationBank = _twoWay(
  _n('tone_long', 4),
  _n('tone_short', 4),
);
final List<SoundQuestion> durationBankHard = _twoWay(
  _n('tone_long_h', 3),
  _n('tone_short_h', 3),
);

// ---- 5-6 音往哪裡走：音高方向（base 音程 7~12 半音 / hard 3~4 半音）----
const List<SoundChoice> directionChoices = <SoundChoice>[
  SoundChoice('⬆️', '往上'),
  SoundChoice('⬇️', '往下'),
];
final List<SoundQuestion> directionBank = _twoWay(
  _n('tone_up', 4),
  _n('tone_down', 4),
);
final List<SoundQuestion> directionBankHard = _twoWay(
  _n('tone_up_h', 3),
  _n('tone_down_h', 3),
);

// ---- 5-6 這首對嗎：熟悉曲中找走音（base 三全音 / hard 微離調 1~2 半音）----
const List<SoundChoice> tuningChoices = <SoundChoice>[
  SoundChoice('😊', '對的'),
  SoundChoice('🙉', '怪怪的'),
];
// 每首歌的「正確版 / 走音版」。播音前會先念+顯示歌名，孩子才有參照可比對。
// 歌名順序須與 tool/gen_tones.py 的 TUNES 一致。
const List<String> _tuneNames = <String>['小星星', '兩隻老虎', '小蜜蜂', '生日快樂'];
final List<SoundQuestion> tuningBank = <SoundQuestion>[
  for (int i = 0; i < _tuneNames.length; i++) ...<SoundQuestion>[
    SoundQuestion('melody_ok${i + 1}.mp3', 0, name: _tuneNames[i]),
    SoundQuestion('melody_bad${i + 1}.mp3', 1, name: _tuneNames[i]),
  ],
];
// hard 池的「對的」沿用同一批 ok clip（正確版本來就只有一種）。
final List<SoundQuestion> tuningBankHard = <SoundQuestion>[
  for (int i = 0; i < _tuneNames.length; i++) ...<SoundQuestion>[
    SoundQuestion('melody_ok${i + 1}.mp3', 0, name: _tuneNames[i]),
    SoundQuestion('melody_bad_h${i + 1}.mp3', 1, name: _tuneNames[i]),
  ],
];
