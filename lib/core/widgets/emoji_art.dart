import 'package:flutter/material.dart';

import '../../content/emoji_art_map.dart';

/// 依 emoji 顯示對應的插畫（[kEmojiArt]）；沒有圖時退回顯示 emoji 字元。
///
/// [size] 是方框邊長；emoji 退回時字級取 size 的 0.85，視覺大小與插畫相近。
class EmojiArt extends StatelessWidget {
  const EmojiArt(this.emoji, {super.key, required this.size});

  final String emoji;
  final double size;

  /// 查表時去掉 U+FE0F（變體選擇字元），'☀️' 與 '☀' 視為同一個。
  static String? assetFor(String emoji) =>
      kEmojiArt[emoji.replaceAll('\u{FE0F}', '')];

  static bool hasArt(String emoji) => assetFor(emoji) != null;

  @override
  Widget build(BuildContext context) {
    final String? asset = assetFor(emoji);
    if (asset == null) {
      return Text(emoji, style: TextStyle(fontSize: size * 0.85));
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: emoji,
    );
  }
}
