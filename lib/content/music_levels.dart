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

/// 4-5 歲加難版：每題多一個干擾項（共 5 選項＝全部樂器一起出），辨音更難。
final List<PickRound> instrumentBank45 = buildSoundRounds(
  instruments,
  '這是什麼樂器的聲音？',
  distractors: 4,
);

// ===================== 聽辨音樂屬性（ListenChooseGame）=====================
// tone clip 由 tool/gen_tones.py 合成（assets/sfx/tone_*.mp3）。
// 每組答案卡固定不洗牌：靠「聽聲音」決定點哪張，位置（含上/下）本身就是要教的對應。

/// 從兩組音檔建題庫：a 組正解 = 第 0 張卡、b 組正解 = 第 1 張卡。
List<SoundQuestion> _twoWay(List<String> a, List<String> b) => <SoundQuestion>[
  for (final String s in a) SoundQuestion(s, 0),
  for (final String s in b) SoundQuestion(s, 1),
];

// ---- 3-4 高高低低：音高（限大音程，約兩個八度）----
const List<SoundChoice> pitchHiLoChoices = <SoundChoice>[
  SoundChoice('🐦', '高'), // 上：高高的鳥
  SoundChoice('🐘', '低'), // 下：低低的象
];
final List<SoundQuestion> pitchHiLoBank = _twoWay(
  <String>['tone_hi1.mp3', 'tone_hi2.mp3', 'tone_hi3.mp3'],
  <String>['tone_lo1.mp3', 'tone_lo2.mp3', 'tone_lo3.mp3'],
);

// ---- 3-4 快快慢慢：速度 ----
const List<SoundChoice> tempoChoices = <SoundChoice>[
  SoundChoice('🐇', '快'),
  SoundChoice('🐢', '慢'),
];
final List<SoundQuestion> tempoBank = _twoWay(
  <String>['tone_fast1.mp3', 'tone_fast2.mp3', 'tone_fast3.mp3'],
  <String>['tone_slow1.mp3', 'tone_slow2.mp3', 'tone_slow3.mp3'],
);

// ---- 4-5 大聲小聲：力度 ----
const List<SoundChoice> dynamicsChoices = <SoundChoice>[
  SoundChoice('🦁', '大聲'),
  SoundChoice('🐭', '小聲'),
];
final List<SoundQuestion> dynamicsBank = _twoWay(
  <String>['tone_loud1.mp3', 'tone_loud2.mp3', 'tone_loud3.mp3'],
  <String>['tone_soft1.mp3', 'tone_soft2.mp3', 'tone_soft3.mp3'],
);

// ---- 4-5 音的長短：時值（一個長音 ta / 兩個短音 ti-ti）----
const List<SoundChoice> durationChoices = <SoundChoice>[
  SoundChoice('🎵', '一個長音', child: DurationGlyph(long: true)),
  SoundChoice('🎵🎵', '兩個短音', child: DurationGlyph(long: false)),
];
final List<SoundQuestion> durationBank = _twoWay(
  <String>['tone_long1.mp3', 'tone_long2.mp3', 'tone_long3.mp3'],
  <String>['tone_short1.mp3', 'tone_short2.mp3', 'tone_short3.mp3'],
);

// ---- 5-6 音往哪裡走：音高方向（上行 / 下行）----
const List<SoundChoice> directionChoices = <SoundChoice>[
  SoundChoice('⬆️', '往上'),
  SoundChoice('⬇️', '往下'),
];
final List<SoundQuestion> directionBank = _twoWay(
  <String>['tone_up1.mp3', 'tone_up2.mp3', 'tone_up3.mp3'],
  <String>['tone_down1.mp3', 'tone_down2.mp3', 'tone_down3.mp3'],
);

// ---- 5-6 哪個音不對：熟悉曲中找走音（一個音明顯離調）----
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
