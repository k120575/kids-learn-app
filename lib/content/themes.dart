import '../models/age_band.dart';
import '../models/domain.dart';

/// 一個領域在主題世界裡的「站點」包裝（遊樂設施 / 星球）。
/// [image] 為 `assets/images/{image}.png` 的檔名鍵（童書插畫入口圖）；
/// 缺圖時 UI 退回顯示 [emoji]。
class Station {
  const Station(this.name, this.emoji, [this.image]);
  final String name;
  final String emoji;
  final String? image;
}

/// 一個年齡段的主題世界。把領域選單包裝成「探索地圖」。
class WorldTheme {
  const WorldTheme({
    required this.worldName,
    required this.worldEmoji,
    required this.mapTitle,
    required this.greeting,
    required this.stations,
    this.bg,
  });

  final String worldName;
  final String worldEmoji;
  final String mapTitle; // 地圖頁標題
  final String greeting; // 進地圖時企企說的話
  final Map<Domain, Station> stations;

  /// 場景背景圖鍵（`assets/images/{bg}.png`）。
  final String? bg;

  Station stationFor(Domain d) =>
      stations[d] ?? Station(d.label, d.emoji);
}

/// 各年齡段的主題。沒設定的年齡段退回「素」領域名稱。
const Map<AgeBand, WorldTheme> worldThemes = <AgeBand, WorldTheme>{
  AgeBand.age3_4: WorldTheme(
    worldName: '歡樂遊樂園',
    worldEmoji: '🎡',
    mapTitle: '歡樂遊樂園',
    greeting: '歡迎來到遊樂園！想先玩哪個設施呢？',
    bg: 'park_bg',
    stations: <Domain, Station>{
      Domain.language: Station('故事屋', '📖', 'storyhouse'),
      Domain.logicMath: Station('數字摩天輪', '🎡', 'ferris'),
      Domain.spatial: Station('積木城堡', '🏰', 'castle'),
      Domain.music: Station('音樂馬戲團', '🎪', 'circus'),
      Domain.brain: Station('鏡子迷宮', '🪞', 'mirror'),
    },
  ),
  AgeBand.age4_5: WorldTheme(
    worldName: '太空探險',
    worldEmoji: '🚀',
    mapTitle: '星際地圖',
    greeting: '太空船長，準備好探索星球了嗎？',
    bg: 'space_bg',
    stations: <Domain, Station>{
      Domain.language: Station('文字星', '🪐', 'planet_word'),
      Domain.logicMath: Station('數學星', '🔢', 'planet_math'),
      Domain.spatial: Station('積木星', '🧊', 'planet_block'),
      Domain.music: Station('音波星', '🎵', 'planet_music'),
      Domain.brain: Station('謎題星', '🌌', 'planet_puzzle'),
    },
  ),
  AgeBand.age5_6: WorldTheme(
    worldName: '魔法學院',
    worldEmoji: '🪄',
    mapTitle: '魔法學院',
    greeting: '歡迎入學，小魔法師！今天想上哪一堂課呢？',
    bg: 'magic_bg',
    stations: <Domain, Station>{
      Domain.language: Station('咒語學院', '📜', 'magic_spell'),
      Domain.logicMath: Station('鍊金數字', '⚗️', 'magic_alchemy'),
      Domain.spatial: Station('魔法陣', '🔮', 'magic_circle'),
      Domain.music: Station('音波魔法', '🎶', 'magic_sound'),
      Domain.brain: Station('智慧之塔', '🗝️', 'magic_tower'),
    },
  ),
};

WorldTheme? worldFor(AgeBand band) => worldThemes[band];
