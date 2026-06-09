/// 年齡段。v1 只啟用 [age3_4]，其餘預留以便日後擴充（只需把 enabled 設為 true
/// 並為各遊戲補上對應的關卡資料，UI 不需改動）。
enum AgeBand {
  // 顯示文案為 3-4 / 4-5 / 5-6（enum 名稱沿用，內容不變）。
  age3_4('3-4 歲', '🐣', true),
  age4_5('4-5 歲', '🐤', true),
  age5_6('5-6 歲', '🦅', true);

  const AgeBand(this.label, this.emoji, this.enabled);

  final String label;
  final String emoji;

  /// 是否在首頁可選。v1 只開 3-4 歲。
  final bool enabled;

  static List<AgeBand> get enabledBands =>
      AgeBand.values.where((AgeBand b) => b.enabled).toList();
}
