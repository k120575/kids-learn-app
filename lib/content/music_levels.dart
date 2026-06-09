import '../games/pick_game.dart';

/// 樂器點選配對：真實樂器聲題庫（全 bigsoundbank CC0），每局隨機抽題。
/// 僅收錄有乾淨 CC0 音效＋清楚 emoji 的樂器（鋼琴/吉他因無 CC0 音效移除）。
const List<(String, String)> instruments = <(String, String)>[
  ('snare.mp3', '🥁'), ('bell.mp3', '🔔'), ('trumpet.mp3', '🎺'),
  ('violin.mp3', '🎻'), ('shaker.mp3', '🪇'),
];
final List<PickRound> instrumentBank =
    buildSoundRounds(instruments, '這是什麼樂器的聲音？');

/// 4-5 歲加難版：每題多一個干擾項（共 5 選項＝全部樂器一起出），辨音更難。
final List<PickRound> instrumentBank45 =
    buildSoundRounds(instruments, '這是什麼樂器的聲音？', distractors: 4);
