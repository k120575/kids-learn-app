import '../games/arithmetic_game.dart';
import '../games/count_tap_game.dart';
import '../games/drag_match_game.dart';
import '../games/find_same_game.dart';
import '../games/hanzi_picture_game.dart';
import '../games/jigsaw_game.dart';
import '../games/listen_choose_game.dart';
import '../games/maze_game.dart';
import '../games/memory_game.dart';
import '../games/multiplication_game.dart';
import '../games/next_in_row_game.dart';
import '../games/number_compare_game.dart';
import '../games/opposite_game.dart';
import '../games/pattern_matrix_game.dart';
import '../games/pick_game.dart';
import '../games/read_aloud_game.dart';
import '../games/rotate_match_game.dart';
import '../games/sound_memory_game.dart';
import '../games/spot_difference_game.dart';
import '../games/sudoku_game.dart';
import '../games/symmetry_game.dart';
import '../games/whats_missing_game.dart';
import '../games/zhuyin_match_game.dart';
import '../models/age_band.dart';
import '../models/domain.dart';
import '../models/game_def.dart';
import 'lang45_levels.dart';
import 'lang56_levels.dart';
import 'language_levels.dart';
import 'literacy_levels.dart';
import 'logic_levels.dart';
import 'maze_gen.dart';
import 'music_levels.dart';
import 'spatial_levels.dart';

const List<AgeBand> _age56 = <AgeBand>[AgeBand.age5_6];

const List<AgeBand> _age45 = <AgeBand>[AgeBand.age4_5];

const List<AgeBand> _age34 = <AgeBand>[AgeBand.age3_4];

/// 全部遊戲的註冊表。新增遊戲只要在這裡加一筆 [GameDef]。
/// 畫面會自動依「年齡段 × 領域」過濾顯示。
final List<GameDef> gameRegistry = <GameDef>[
  // ---------- 語文 ----------
  GameDef(
    id: 'listen_point',
    title: '聽音指圖',
    emoji: '👂',
    domain: Domain.language,
    ageBands: _age34,
    builder: (_) => PickGame(
      gameId: 'listen_point',
      title: '聽音指圖',
      rounds: listenPointBank, // 50 題庫
      pickCount: 10, // 每局隨機抽 10 題
    ),
  ),
  GameDef(
    id: 'sound_hunt',
    title: '聲音尋寶',
    emoji: '🔊',
    domain: Domain.language,
    ageBands: _age34,
    builder: (_) => PickGame(
      gameId: 'sound_hunt',
      title: '聲音尋寶',
      rounds: soundHuntBank, // 14 動物題庫
      pickCount: 10,
    ),
  ),
  GameDef(
    id: 'read_aloud_34',
    title: '跟我念',
    emoji: '🗨️',
    domain: Domain.language,
    ageBands: _age34,
    builder: (_) => const ReadAloudGame(
      gameId: 'read_aloud_34',
      title: '跟我念',
      items: readAloud34, // 親子共學短語
      pickCount: 6,
    ),
  ),

  // ---------- 邏輯數學 ----------
  GameDef(
    id: 'count_tap',
    title: '數數點點',
    emoji: '🔢',
    domain: Domain.logicMath,
    ageBands: _age34,
    builder: (_) => CountTapGame(
      gameId: 'count_tap',
      title: '數數點點',
      rounds: countBank, // 50 題庫
      pickCount: 6, // 每局隨機抽 6 題
    ),
  ),
  GameDef(
    id: 'color_sort',
    title: '顏色分類',
    emoji: '🎨',
    domain: Domain.logicMath,
    ageBands: _age34,
    builder: (_) => DragMatchGame(
      gameId: 'color_sort',
      title: '顏色分類',
      intro: '把一樣顏色的點點，放進一樣顏色的籃子！',
      generator: makeColorSortBoard, // 每回合隨機版面
      rounds: 3,
    ),
  ),
  GameDef(
    id: 'advanced_sort',
    title: '進階分類',
    emoji: '🔷',
    domain: Domain.logicMath,
    ageBands: _age34,
    builder: (_) => DragMatchGame(
      gameId: 'advanced_sort',
      title: '進階分類',
      intro: '顏色和形狀都要一樣，才放得進去喔！',
      generator: makeAdvancedSortBoard, // 每回合隨機版面（2色×2形）
      rounds: 3,
    ),
  ),

  // ---------- 空間 ----------
  GameDef(
    id: 'shape_match',
    title: '形狀配對',
    emoji: '🔷',
    domain: Domain.spatial,
    ageBands: _age34,
    builder: (_) => DragMatchGame(
      gameId: 'shape_match',
      title: '形狀配對',
      intro: '把形狀放進一樣的洞洞裡！',
      generator: makeShapeMatchBoard, // 每回合隨機版面（4 種形狀、各自配色）
      rounds: 6,
    ),
  ),
  GameDef(
    id: 'house_puzzle',
    title: '拼拼圖',
    emoji: '🧩',
    domain: Domain.spatial,
    ageBands: _age34,
    builder: (_) => const JigsawGame(
      gameId: 'house_puzzle',
      title: '拼拼圖',
      minPieces: 4, // 4~9 片，行列隨機（可非正方形）
      maxPieces: 9,
    ),
  ),
  GameDef(
    id: 'maze',
    title: '走迷宮',
    emoji: '🐭',
    domain: Domain.spatial,
    ageBands: _age34,
    builder: (_) => MazeGame(
      gameId: 'maze',
      title: '走迷宮',
      generator: () => genHardMaze(4), // 9×9 程序產生、含死巷（原 5-6 等級）
      genCount: 4,
    ),
  ),

  // ---------- 音樂 ----------
  GameDef(
    id: 'instrument_pick',
    title: '樂器配對',
    emoji: '🎺',
    domain: Domain.music,
    ageBands: _age34,
    builder: (_) => PickGame(
      gameId: 'instrument_pick',
      title: '樂器配對',
      rounds: instrumentBank, // 5 樂器
    ),
  ),
  GameDef(
    id: 'tempo_34',
    title: '快快慢慢',
    emoji: '🐇',
    domain: Domain.music,
    ageBands: _age34,
    builder: (_) => ListenChooseGame(
      gameId: 'tempo_34',
      title: '快快慢慢',
      intro: '快快的聲音，點兔子；慢慢的聲音，點烏龜！',
      choices: tempoChoices,
      questions: tempoBank,
    ),
  ),
  GameDef(
    id: 'pitch_hilo_34',
    title: '高高低低',
    emoji: '🐦',
    domain: Domain.music,
    ageBands: _age34,
    builder: (_) => ListenChooseGame(
      gameId: 'pitch_hilo_34',
      title: '高高低低',
      intro: '高高的聲音，點小鳥；低低的聲音，點大象！',
      choices: pitchHiLoChoices,
      questions: pitchHiLoBank,
      vertical: true, // 高在上、低在下，位置＝音高
      repeats: 3, // 連播 3 次，幼兒比較聽得清
    ),
  ),
  // （節奏跟打已移除）

  // ---------- 動腦 ----------
  // 3-4 全新內容（非難度變體）：感知辨識 + 短期記憶 + 重複規律，
  // 與 4-5 的記憶翻牌/找不同/找規律是不同的認知動作。
  GameDef(
    id: 'find_same_34',
    title: '找一樣',
    emoji: '👀',
    domain: Domain.brain,
    ageBands: _age34,
    builder: (_) => const FindSameGame(gameId: 'find_same_34', title: '找一樣'),
  ),
  GameDef(
    id: 'whats_missing_34',
    title: '什麼不見了',
    emoji: '🙈',
    domain: Domain.brain,
    ageBands: _age34,
    builder: (_) =>
        const WhatsMissingGame(gameId: 'whats_missing_34', title: '什麼不見了'),
  ),
  GameDef(
    id: 'next_in_row_34',
    title: '接下去',
    emoji: '🚂',
    domain: Domain.brain,
    ageBands: _age34,
    builder: (_) => const NextInRowGame(gameId: 'next_in_row_34', title: '接下去'),
  ),

  // ==================== 4-5 歲 ====================
  // ---------- 邏輯數學 ----------
  GameDef(
    id: 'arithmetic',
    title: '加減法',
    emoji: '➕',
    domain: Domain.logicMath,
    ageBands: _age45,
    builder: (_) =>
        const ArithmeticGame(gameId: 'arithmetic', title: '加減法', maxValue: 20),
  ),
  GameDef(
    id: 'compare',
    title: '比大小',
    emoji: '⚖️',
    domain: Domain.logicMath,
    ageBands: _age45,
    builder: (_) => const NumberCompareGame(gameId: 'compare', title: '比大小'),
  ),
  GameDef(
    id: 'advanced_sort_45',
    title: '進階分類',
    emoji: '🔷',
    domain: Domain.logicMath,
    ageBands: _age45,
    builder: (_) => DragMatchGame(
      gameId: 'advanced_sort_45',
      title: '進階分類',
      intro: '顏色和形狀都要一樣，才放得進去喔！',
      generator: () => makeAdvancedSortBoard(hard: true), // 3色×2形=6格、每格1-4個
      rounds: 4,
    ),
  ),
  // ---------- 空間 ----------
  GameDef(
    id: 'maze_hard',
    title: '走迷宮',
    emoji: '🧭',
    domain: Domain.spatial,
    ageBands: _age45,
    builder: (_) => MazeGame(
      gameId: 'maze_hard',
      title: '走迷宮',
      intro: '用箭頭找路走到起司！',
      generator: () => genHardMaze(5), // 11×11 程序產生、含死巷（原 7-8 等級）
      genCount: 4,
    ),
  ),
  GameDef(
    id: 'shape_match_45',
    title: '形狀配對',
    emoji: '🔷',
    domain: Domain.spatial,
    ageBands: _age45,
    builder: (_) => DragMatchGame(
      gameId: 'shape_match_45',
      title: '形狀配對',
      intro: '不要看顏色，把一樣形狀的放進洞洞裡！',
      generator: () => makeShapeMatchBoard(hard: true), // 5 種形狀、全部同色（只能靠形狀）
      rounds: 6,
    ),
  ),
  GameDef(
    id: 'house_puzzle_45',
    title: '拼拼圖',
    emoji: '🧩',
    domain: Domain.spatial,
    ageBands: _age45,
    builder: (_) => const JigsawGame(
      gameId: 'house_puzzle_45',
      title: '拼拼圖',
      minPieces: 9, // 9~16 片，行列隨機（可非正方形）
      maxPieces: 16,
    ),
  ),
  // ---------- 動腦 ----------
  GameDef(
    id: 'memory',
    title: '記憶翻牌',
    emoji: '🃏',
    domain: Domain.brain,
    ageBands: _age45,
    builder: (_) => const MemoryGame(gameId: 'memory', title: '記憶翻牌', pairs: 6),
  ),
  GameDef(
    id: 'spot_diff',
    title: '找不同',
    emoji: '🔍',
    domain: Domain.brain,
    ageBands: _age45,
    builder: (_) => const SpotDifferenceGame(
      gameId: 'spot_diff',
      title: '找不同',
      numDiff: 3, // 適性難度階梯：簡單 2 / 一般 3 / 挑戰 4（原本一般也是 2，太平）
    ),
  ),
  GameDef(
    id: 'pattern',
    title: '找規律',
    emoji: '🧩',
    domain: Domain.brain,
    ageBands: _age45,
    builder: (_) => const PatternMatrixGame(gameId: 'pattern', title: '找規律'),
  ),
  // ---------- 語文 ----------
  GameDef(
    id: 'listen_point_45',
    title: '聽音指圖',
    emoji: '👂',
    domain: Domain.language,
    ageBands: _age45,
    builder: (_) => PickGame(
      gameId: 'listen_point_45',
      title: '聽音指圖',
      rounds: listenPointBank45, // 進階 50 詞
      pickCount: 10,
    ),
  ),
  GameDef(
    id: 'odd_one_out',
    title: '找不同類',
    emoji: '🧺',
    domain: Domain.language,
    ageBands: _age45,
    builder: (_) => PickGame(
      gameId: 'odd_one_out',
      title: '找不同類',
      rounds: oddOneOutBank,
      pickCount: 10,
    ),
  ),
  GameDef(
    id: 'opposites',
    title: '反義詞',
    emoji: '↔️',
    domain: Domain.language,
    ageBands: _age45,
    builder: (_) => const OppositeGame(
      gameId: 'opposites',
      title: '反義詞',
      pairs: oppositePairs,
    ),
  ),
  GameDef(
    id: 'hanzi_read',
    title: '認國字',
    emoji: '🈶',
    domain: Domain.language,
    ageBands: _age45,
    // 4-5 還不太會認字：改成「看圖→選字」，點字念讀音、按確定才判對錯。
    builder: (_) => const HanziPictureGame(
      gameId: 'hanzi_read',
      title: '認國字',
      items: hanziPictureItems, // 具體可圖像化的字（月🌙、山⛰️…）
      pickCount: 8,
    ),
  ),
  GameDef(
    id: 'zhuyin_onset',
    title: '注音對對碰',
    emoji: 'ㄅ',
    domain: Domain.language,
    ageBands: _age45,
    // 4-5 還沒學拼音：不考開頭音，改成「找一樣的注音」配對，配對成功念讀音。
    builder: (_) => const ZhuyinMatchGame(
      gameId: 'zhuyin_onset',
      title: '注音對對碰',
      pool: zhuyinMatchPool, // 14 個聲母（顯示 ㄅ、念「ㄅㄛ」）
    ),
  ),
  GameDef(
    id: 'read_aloud_45',
    title: '跟我念',
    emoji: '🗨️',
    domain: Domain.language,
    ageBands: _age45,
    builder: (_) => const ReadAloudGame(
      gameId: 'read_aloud_45',
      title: '跟我念',
      items: readAloud45, // 親子共學短句
      pickCount: 6,
    ),
  ),
  // ---------- 音樂 ----------
  GameDef(
    id: 'instrument_45',
    title: '樂器配對',
    emoji: '🎺',
    domain: Domain.music,
    ageBands: _age45,
    builder: (_) => PickGame(
      gameId: 'instrument_45',
      title: '樂器配對',
      rounds: instrumentBank45, // 5 選項（全部樂器一起出）、辨音更難
      hard: true,
    ),
  ),
  GameDef(
    id: 'dynamics_45',
    title: '大聲小聲',
    emoji: '🦁',
    domain: Domain.music,
    ageBands: _age45,
    builder: (_) => ListenChooseGame(
      gameId: 'dynamics_45',
      title: '大聲小聲',
      intro: '大聲的，點獅子；小聲的，點老鼠！',
      choices: dynamicsChoices,
      questions: dynamicsBank,
      repeats: 3, // 連播 3 次，幼兒比較聽得清
    ),
  ),
  GameDef(
    id: 'duration_45',
    title: '音的長短',
    emoji: '🎵',
    domain: Domain.music,
    ageBands: _age45,
    builder: (_) => ListenChooseGame(
      gameId: 'duration_45',
      title: '音的長短',
      intro: '一個長長的音，點一個音符；兩個短短的音，點兩個音符！',
      choices: durationChoices,
      questions: durationBank,
    ),
  ),

  // ==================== 5-6 歲・魔法學院 ====================
  // ---------- 語文（咒語學院 📜）----------
  GameDef(
    id: 'hanzi_56',
    title: '認國字',
    emoji: '🈶',
    domain: Domain.language,
    ageBands: _age56,
    builder: (_) => PickGame(
      gameId: 'hanzi_56',
      title: '認國字',
      rounds: hanziBank56, // 36 個一年級常見字（聽詞點字）
      pickCount: 10,
    ),
  ),
  GameDef(
    id: 'zhuyin_56',
    title: '注音開頭',
    emoji: 'ㄅ',
    domain: Domain.language,
    ageBands: _age56,
    builder: (_) => PickGame(
      gameId: 'zhuyin_56',
      title: '注音開頭',
      rounds: zhuyinOnsetBank56, // 進階詞庫、涵蓋更多聲母
      pickCount: 10,
    ),
  ),
  GameDef(
    id: 'measure_56',
    title: '量詞高手',
    emoji: '📦',
    domain: Domain.language,
    ageBands: _age56,
    builder: (_) => PickGame(
      gameId: 'measure_56',
      title: '量詞高手',
      rounds: measureWordBank, // 聽「數什麼」選正確量詞
      pickCount: 10,
    ),
  ),
  GameDef(
    id: 'odd_one_out_56',
    title: '找不同類',
    emoji: '🧺',
    domain: Domain.language,
    ageBands: _age56,
    builder: (_) => PickGame(
      gameId: 'odd_one_out_56',
      title: '找不同類',
      rounds: oddOneOutBank56, // 依用途/語意分類，更抽象
      pickCount: 10,
    ),
  ),

  // ---------- 邏輯數學（鍊金數字 ⚗️）----------
  GameDef(
    id: 'arithmetic_56',
    title: '大數加減',
    emoji: '➕',
    domain: Domain.logicMath,
    ageBands: _age56,
    builder: (_) => const ArithmeticGame(
      gameId: 'arithmetic_56',
      title: '大數加減',
      maxValue: 100, // 含進位退位
    ),
  ),
  GameDef(
    id: 'multiply_56',
    title: '乘法魔法',
    emoji: '✖️',
    domain: Domain.logicMath,
    ageBands: _age56,
    builder: (_) =>
        const MultiplicationGame(gameId: 'multiply_56', title: '乘法魔法'),
  ),
  GameDef(
    id: 'compare_56',
    title: '比大小',
    emoji: '⚖️',
    domain: Domain.logicMath,
    ageBands: _age56,
    builder: (_) => const NumberCompareGame(
      gameId: 'compare_56',
      title: '比大小',
      maxValue: 99, // 兩位數比大小
      count: 4,
    ),
  ),

  // ---------- 空間（魔法陣 🔮）----------
  // （5-6 取消迷宮關卡：迷宮難度已下移到 3-4 / 4-5）
  GameDef(
    id: 'symmetry_56',
    title: '對稱鏡像',
    emoji: '🦋',
    domain: Domain.spatial,
    ageBands: _age56,
    builder: (_) => const SymmetryGame(gameId: 'symmetry_56', title: '對稱鏡像'),
  ),
  GameDef(
    id: 'puzzle_56',
    title: '拼圖高手',
    emoji: '🧩',
    domain: Domain.spatial,
    ageBands: _age56,
    builder: (_) => const JigsawGame(
      gameId: 'puzzle_56',
      title: '拼圖高手',
      minPieces: 16, // 16~25 片，行列隨機（可非正方形）
      maxPieces: 25,
    ),
  ),
  GameDef(
    id: 'rotate_match_56',
    title: '轉轉看',
    emoji: '🔄',
    domain: Domain.spatial,
    ageBands: _age56,
    builder: (_) =>
        const RotateMatchGame(gameId: 'rotate_match_56', title: '轉轉看'),
  ),

  // ---------- 音樂（音波魔法 🎶）----------
  // （節奏進階已移除）
  GameDef(
    id: 'sound_memory_56',
    title: '音波記憶',
    emoji: '🎶',
    domain: Domain.music,
    ageBands: _age56,
    builder: (_) =>
        const SoundMemoryGame(gameId: 'sound_memory_56', title: '音波記憶'),
  ),
  GameDef(
    id: 'direction_56',
    title: '音往哪裡走',
    emoji: '↕️', // 與「音波記憶」🎶 區隔；上下箭頭直接點出「音高方向」

    domain: Domain.music,
    ageBands: _age56,
    builder: (_) => ListenChooseGame(
      gameId: 'direction_56',
      title: '音往哪裡走',
      intro: '聲音往上爬，點上面的箭頭；往下溜，點下面的箭頭！',
      choices: directionChoices,
      questions: directionBank,
      vertical: true,
    ),
  ),
  GameDef(
    id: 'tuning_56',
    title: '這首對嗎',
    emoji: '🎼',
    domain: Domain.music,
    ageBands: _age56,
    builder: (_) => ListenChooseGame(
      gameId: 'tuning_56',
      title: '這首對嗎',
      intro: '聽聽看這首歌，對的點笑臉，怪怪的點摀耳朵！',
      choices: tuningChoices,
      questions: tuningBank,
      pickCount: 6,
    ),
  ),

  // ---------- 動腦（智慧之塔 🗝️）----------
  GameDef(
    id: 'memory_56',
    title: '記憶翻牌',
    emoji: '🃏',
    domain: Domain.brain,
    ageBands: _age56,
    builder: (_) => const MemoryGame(
      gameId: 'memory_56',
      title: '記憶翻牌',
      pairs: 8, // 8 對牌
    ),
  ),
  GameDef(
    id: 'pattern_56',
    title: '找規律',
    emoji: '🔷',
    domain: Domain.brain,
    ageBands: _age56,
    builder: (_) => const PatternMatrixGame(
      gameId: 'pattern_56',
      title: '找規律',
      length: 8, // 更長的規律
    ),
  ),
  GameDef(
    id: 'sudoku_56',
    title: '數獨小將',
    emoji: '🧮',
    domain: Domain.brain,
    ageBands: _age56,
    builder: (_) => const SudokuGame(gameId: 'sudoku_56', title: '數獨小將'),
  ),
];
