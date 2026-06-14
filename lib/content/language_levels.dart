import 'dart:math';

import '../games/pick_game.dart';

/// 聽音指圖 50 題庫（詞彙, emoji）。每局由 PickGame 隨機抽題，
/// 選項（1 正解 + 3 干擾）在啟動時自動產生。
const List<(String, String)> listenVocab = <(String, String)>[
  ('小狗', '🐶'),
  ('小貓', '🐱'),
  ('小魚', '🐟'),
  ('牛', '🐮'),
  ('豬', '🐷'),
  ('青蛙', '🐸'),
  ('小鳥', '🐦'),
  ('兔子', '🐰'),
  ('老虎', '🐯'),
  ('獅子', '🦁'),
  ('大象', '🐘'),
  ('猴子', '🐵'),
  ('熊', '🐻'),
  ('企鵝', '🐧'),
  ('鴨子', '🦆'),
  ('雞', '🐔'),
  ('綿羊', '🐑'),
  ('馬', '🐴'),
  ('蝴蝶', '🦋'),
  ('烏龜', '🐢'),
  ('蘋果', '🍎'),
  ('香蕉', '🍌'),
  ('葡萄', '🍇'),
  ('草莓', '🍓'),
  ('西瓜', '🍉'),
  ('橘子', '🍊'),
  ('紅蘿蔔', '🥕'),
  ('玉米', '🌽'),
  ('麵包', '🍞'),
  ('蛋糕', '🍰'),
  ('餅乾', '🍪'),
  ('冰淇淋', '🍦'),
  ('牛奶', '🥛'),
  ('蛋', '🥚'),
  ('糖果', '🍬'),
  ('汽車', '🚗'),
  ('公車', '🚌'),
  ('飛機', '✈️'),
  ('火車', '🚂'),
  ('腳踏車', '🚲'),
  ('帆船', '⛵'),
  ('皮球', '⚽'),
  ('氣球', '🎈'),
  ('雨傘', '☂️'),
  ('帽子', '🎩'),
  ('太陽', '☀️'),
  ('月亮', '🌙'),
  ('星星', '⭐'),
  ('花', '🌸'),
  ('樹', '🌳'),
];

final List<PickRound> listenPointBank = _buildListenBank();

List<PickRound> _buildListenBank() {
  final Random rng = Random();
  final List<PickRound> bank = <PickRound>[];
  for (int i = 0; i < listenVocab.length; i++) {
    final (String, String) item = listenVocab[i];
    final Set<int> others = <int>{};
    while (others.length < 3) {
      final int j = rng.nextInt(listenVocab.length);
      if (j != i) others.add(j);
    }
    final List<String> opts = <String>[
      item.$2,
      for (final int j in others) listenVocab[j].$2,
    ]..shuffle(rng);
    bank.add(
      PickRound(
        prompt: '找出${item.$1}',
        options: opts,
        correctIndex: opts.indexOf(item.$2),
      ),
    );
  }
  return bank;
}

/// 聲音尋寶：真實動物叫聲題庫（18 種，全 bigsoundbank CC0），每局隨機抽題。
const List<(String, String)> soundAnimals = <(String, String)>[
  ('cat.mp3', '🐱'),
  ('dog.mp3', '🐶'),
  ('frog.mp3', '🐸'),
  ('pig.mp3', '🐷'),
  ('sheep.mp3', '🐑'),
  ('rooster.mp3', '🐓'),
  ('duck.mp3', '🦆'),
  ('horse.mp3', '🐴'),
  ('owl.mp3', '🦉'),
  ('goat.mp3', '🐐'),
  ('hen.mp3', '🐔'),
  ('crow.mp3', '🐦'),
  ('bee.mp3', '🐝'),
  ('cricket.mp3', '🦗'),
  ('elephant.mp3', '🐘'),
  ('tiger.mp3', '🐯'),
  ('wolf.mp3', '🐺'),
  ('whale.mp3', '🐋'),
];
final List<PickRound> soundHuntBank = buildSoundRounds(soundAnimals, '這是誰的聲音？');
