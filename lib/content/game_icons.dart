/// 關卡入口圖示（扁平繪本插畫，去背 webp）：GameDef.id → `assets/images/icons/{key}.webp`。
/// 同玩法跨年齡共用一張。由 tool/gen_game_icons.py 的 GAME_ICON 產生，新增關卡兩邊都要加。
library;

const Map<String, String> _gameIcon = <String, String>{
  'listen_point': 'listen_point',
  'listen_point_45': 'listen_point',
  'sound_hunt': 'sound_hunt',
  'read_aloud_34': 'read_aloud',
  'read_aloud_45': 'read_aloud',
  'count_tap': 'count_tap',
  'color_sort': 'color_sort',
  'advanced_sort': 'advanced_sort',
  'advanced_sort_45': 'advanced_sort',
  'shape_match': 'shape_match',
  'house_puzzle': 'puzzle',
  'puzzle_56': 'puzzle',
  'maze': 'maze',
  'maze_hard': 'maze',
  'instrument_pick': 'instrument',
  'instrument_45': 'instrument',
  'tempo_34': 'tempo',
  'pitch_hilo_34': 'pitch_hilo',
  'find_same_34': 'find_same',
  'whats_missing_34': 'whats_missing',
  'next_in_row_34': 'next_in_row',
  'arithmetic': 'arithmetic',
  'arithmetic_56': 'arithmetic',
  'compare': 'compare',
  'compare_56': 'compare',
  'block_copy_45': 'block_copy',
  'tangram_45': 'tangram',
  'memory': 'memory',
  'memory_56': 'memory',
  'spot_diff': 'spot_diff',
  'pattern': 'pattern',
  'pattern_56': 'pattern',
  'odd_one_out': 'odd_one_out',
  'odd_one_out_56': 'odd_one_out',
  'opposites': 'opposites',
  'hanzi_read': 'hanzi',
  'hanzi_56': 'hanzi',
  'zhuyin_onset': 'zhuyin',
  'zhuyin_56': 'zhuyin',
  'dynamics_45': 'dynamics',
  'duration_45': 'duration',
  'measure_56': 'measure',
  'multiply_56': 'multiply',
  'symmetry_56': 'symmetry',
  'rotate_match_56': 'rotate_match',
  'sound_memory_56': 'sound_memory',
  'tuning_56': 'tuning',
  'direction_56': 'direction',
  'sudoku_56': 'sudoku',
};

/// 關卡圖示路徑；沒有對應圖時回傳 null（卡片會退回顯示 emoji）。
String? gameIconAsset(String gameId) {
  final String? key = _gameIcon[gameId];
  return key == null ? null : iconAsset(key);
}

/// `assets/images/icons/` 底下的圖示路徑（年齡、首頁按鈕等也共用）。
String iconAsset(String key) => 'assets/images/icons/$key.webp';
