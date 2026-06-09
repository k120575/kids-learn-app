import 'package:flutter/material.dart';

/// 扭蛋玩具的稀有度。權重決定抽中機率。
enum ToyRarity {
  common('普通', Color(0xFF90A4AE), 70),
  rare('稀有', Color(0xFF42A5F5), 25),
  legendary('傳說', Color(0xFFFFB300), 5);

  const ToyRarity(this.label, this.color, this.weight);
  final String label;
  final Color color;
  final int weight;
}

/// 一個可收集的玩具模型（用 emoji 當外觀，id 即 emoji，唯一）。
class Toy {
  const Toy(this.id, this.name, this.rarity);
  final String id;
  final String name;
  final ToyRarity rarity;
}

/// 扭蛋玩具池。分稀有度：普通好抽、傳說難得（製造收集動力）。
const List<Toy> toyPool = <Toy>[
  // 普通（18）
  Toy('🚗', '小汽車', ToyRarity.common),
  Toy('🚌', '公車', ToyRarity.common),
  Toy('🚓', '警車', ToyRarity.common),
  Toy('🚒', '消防車', ToyRarity.common),
  Toy('🚜', '拖拉機', ToyRarity.common),
  Toy('⛵', '帆船', ToyRarity.common),
  Toy('🐶', '小狗', ToyRarity.common),
  Toy('🐱', '小貓', ToyRarity.common),
  Toy('🐰', '兔子', ToyRarity.common),
  Toy('🐸', '青蛙', ToyRarity.common),
  Toy('🐢', '烏龜', ToyRarity.common),
  Toy('🐧', '企鵝', ToyRarity.common),
  Toy('⚽', '足球', ToyRarity.common),
  Toy('🪀', '溜溜球', ToyRarity.common),
  Toy('🪁', '風箏', ToyRarity.common),
  Toy('🧸', '泰迪熊', ToyRarity.common),
  Toy('🎈', '氣球', ToyRarity.common),
  Toy('🎀', '蝴蝶結', ToyRarity.common),
  // 稀有（9）
  Toy('🚀', '火箭', ToyRarity.rare),
  Toy('🚁', '直升機', ToyRarity.rare),
  Toy('🦊', '狐狸', ToyRarity.rare),
  Toy('🐬', '海豚', ToyRarity.rare),
  Toy('🦋', '蝴蝶', ToyRarity.rare),
  Toy('🦒', '長頸鹿', ToyRarity.rare),
  Toy('🐘', '大象', ToyRarity.rare),
  Toy('🎠', '旋轉木馬', ToyRarity.rare),
  Toy('🎡', '摩天輪', ToyRarity.rare),
  // 普通（追加 20）
  Toy('🐮', '乳牛', ToyRarity.common),
  Toy('🐷', '小豬', ToyRarity.common),
  Toy('🐔', '小雞', ToyRarity.common),
  Toy('🐵', '猴子', ToyRarity.common),
  Toy('🐠', '熱帶魚', ToyRarity.common),
  Toy('🐝', '蜜蜂', ToyRarity.common),
  Toy('🐞', '瓢蟲', ToyRarity.common),
  Toy('🦆', '鴨子', ToyRarity.common),
  Toy('🐴', '小馬', ToyRarity.common),
  Toy('🐑', '綿羊', ToyRarity.common),
  Toy('🍎', '蘋果', ToyRarity.common),
  Toy('🍌', '香蕉', ToyRarity.common),
  Toy('🍓', '草莓', ToyRarity.common),
  Toy('🍇', '葡萄', ToyRarity.common),
  Toy('🍉', '西瓜', ToyRarity.common),
  Toy('🍪', '餅乾', ToyRarity.common),
  Toy('🍩', '甜甜圈', ToyRarity.common),
  Toy('🌈', '彩虹', ToyRarity.common),
  Toy('🌟', '亮星星', ToyRarity.common),
  Toy('🍄', '蘑菇', ToyRarity.common),
  // 稀有（追加 9）
  Toy('🦜', '鸚鵡', ToyRarity.rare),
  Toy('🦩', '紅鶴', ToyRarity.rare),
  Toy('🦚', '孔雀', ToyRarity.rare),
  Toy('🦛', '河馬', ToyRarity.rare),
  Toy('🐊', '鱷魚', ToyRarity.rare),
  Toy('🦓', '斑馬', ToyRarity.rare),
  Toy('🦏', '犀牛', ToyRarity.rare),
  Toy('🎢', '雲霄飛車', ToyRarity.rare),
  Toy('🎸', '吉他', ToyRarity.rare),
  // 傳說（5 + 追加 4）
  Toy('🦄', '獨角獸', ToyRarity.legendary),
  Toy('🐉', '神龍', ToyRarity.legendary),
  Toy('👑', '皇冠', ToyRarity.legendary),
  Toy('💎', '鑽石', ToyRarity.legendary),
  Toy('🛸', '幽浮', ToyRarity.legendary),
  Toy('🦕', '長頸龍', ToyRarity.legendary),
  Toy('🦖', '暴龍', ToyRarity.legendary),
  Toy('👽', '外星人', ToyRarity.legendary),
  Toy('🤖', '機器人', ToyRarity.legendary),
];

/// 每抽花費的星星數。
const int kGachaCost = 50;

/// 抽到重複時退還的星星數。
const int kDuplicateRefund = 5;

Toy? toyById(String id) {
  for (final Toy t in toyPool) {
    if (t.id == id) return t;
  }
  return null;
}
