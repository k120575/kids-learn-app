import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 本機 SQLite 持久層（唯一的「資料庫真相來源」）。
///
/// v2 起資料以「孩子檔案（profile）」分流：星星、貼紙、遊玩紀錄、每日時間、
/// 適性難度都帶 profile_id，讓多個孩子共用一台平板而進度互不干擾。
///
/// 這層是日後接雲端同步（Supabase）的接縫：CloudSync 只要讀寫這幾張表，
/// 再與雲端對帳即可，上層（ProgressStore / UI）完全不用改。
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  static const String kDefaultProfile = 'default';

  Database? _db;
  bool get ready => _db != null;

  Future<void> init() async {
    final String dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'kids_learn.db'),
      version: 3,
      onCreate: _createLatest,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _createLatest(Database db, int version) async {
    await _createV2Tables(db);
    await _createV3Tables(db);
    await _seedDefaultProfile(db);
    await db.insert('wallet', <String, Object?>{
      'profile_id': kDefaultProfile,
      'balance': 0,
      'earned_total': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute(
      'CREATE TABLE profiles(id TEXT PRIMARY KEY, name TEXT NOT NULL, '
      'emoji TEXT NOT NULL, created_at INTEGER NOT NULL, sort INTEGER NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE stars(profile_id TEXT NOT NULL, game_id TEXT NOT NULL, '
      'stars INTEGER NOT NULL, PRIMARY KEY(profile_id, game_id))',
    );
    await db.execute(
      'CREATE TABLE stickers(profile_id TEXT NOT NULL, sticker TEXT NOT NULL, '
      'earned_at INTEGER NOT NULL, PRIMARY KEY(profile_id, sticker))',
    );
    await db.execute(
      'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE difficulty(profile_id TEXT NOT NULL, game_id TEXT NOT NULL, '
      'level INTEGER NOT NULL, PRIMARY KEY(profile_id, game_id))',
    );
    await db.execute(
      'CREATE TABLE plays(id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'profile_id TEXT NOT NULL, game_id TEXT NOT NULL, stars INTEGER NOT NULL, '
      'mistakes INTEGER NOT NULL, played_at INTEGER NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE daily_time(profile_id TEXT NOT NULL, day TEXT NOT NULL, '
      'seconds INTEGER NOT NULL, PRIMARY KEY(profile_id, day))',
    );
  }

  /// v3 新增：星星錢包、扭蛋玩具、成就獎盃、連續天數。
  Future<void> _createV3Tables(Database db) async {
    await db.execute(
      'CREATE TABLE wallet(profile_id TEXT PRIMARY KEY, balance INTEGER NOT NULL, '
      'earned_total INTEGER NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE toys(profile_id TEXT NOT NULL, toy_id TEXT NOT NULL, '
      'count INTEGER NOT NULL, earned_at INTEGER NOT NULL, '
      'PRIMARY KEY(profile_id, toy_id))',
    );
    await db.execute(
      'CREATE TABLE achievements(profile_id TEXT NOT NULL, ach_id TEXT NOT NULL, '
      'tier INTEGER NOT NULL, unlocked_at INTEGER NOT NULL, '
      'PRIMARY KEY(profile_id, ach_id))',
    );
    await db.execute(
      'CREATE TABLE streak(profile_id TEXT PRIMARY KEY, last_day TEXT NOT NULL, '
      'current INTEGER NOT NULL, best INTEGER NOT NULL)',
    );
  }

  /// 升級遷移（逐版累加）。
  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'CREATE TABLE profiles(id TEXT PRIMARY KEY, name TEXT NOT NULL, '
        'emoji TEXT NOT NULL, created_at INTEGER NOT NULL, sort INTEGER NOT NULL)',
      );
      await _seedDefaultProfile(db);

      // stars：重建為帶 profile_id 的複合主鍵，舊資料歸到 default。
      await db.execute('ALTER TABLE stars RENAME TO stars_old');
      await db.execute(
        'CREATE TABLE stars(profile_id TEXT NOT NULL, game_id TEXT NOT NULL, '
        'stars INTEGER NOT NULL, PRIMARY KEY(profile_id, game_id))',
      );
      await db.execute(
        "INSERT INTO stars(profile_id, game_id, stars) "
        "SELECT '$kDefaultProfile', game_id, stars FROM stars_old",
      );
      await db.execute('DROP TABLE stars_old');

      // stickers：同樣處理。
      await db.execute('ALTER TABLE stickers RENAME TO stickers_old');
      await db.execute(
        'CREATE TABLE stickers(profile_id TEXT NOT NULL, sticker TEXT NOT NULL, '
        'earned_at INTEGER NOT NULL, PRIMARY KEY(profile_id, sticker))',
      );
      await db.execute(
        "INSERT INTO stickers(profile_id, sticker, earned_at) "
        "SELECT '$kDefaultProfile', sticker, earned_at FROM stickers_old",
      );
      await db.execute('DROP TABLE stickers_old');

      await db.execute(
        'CREATE TABLE difficulty(profile_id TEXT NOT NULL, game_id TEXT NOT NULL, '
        'level INTEGER NOT NULL, PRIMARY KEY(profile_id, game_id))',
      );
      await db.execute(
        'CREATE TABLE plays(id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'profile_id TEXT NOT NULL, game_id TEXT NOT NULL, stars INTEGER NOT NULL, '
        'mistakes INTEGER NOT NULL, played_at INTEGER NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE daily_time(profile_id TEXT NOT NULL, day TEXT NOT NULL, '
        'seconds INTEGER NOT NULL, PRIMARY KEY(profile_id, day))',
      );
    }
    if (oldVersion < 3) {
      await _createV3Tables(db);
      // 既有孩子：把目前累積的星星數轉成「可花用餘額」+「累積總額」當起始值。
      await db.execute(
        'INSERT INTO wallet(profile_id, balance, earned_total) '
        'SELECT id, COALESCE((SELECT SUM(stars) FROM stars s '
        'WHERE s.profile_id = p.id), 0), '
        'COALESCE((SELECT SUM(stars) FROM stars s2 '
        'WHERE s2.profile_id = p.id), 0) FROM profiles p',
      );
    }
  }

  Future<void> _seedDefaultProfile(Database db) async {
    await db.insert('profiles', <String, Object?>{
      'id': kDefaultProfile,
      'name': '寶貝',
      'emoji': '🐧',
      'created_at': 0,
      'sort': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('settings', <String, Object?>{
      'key': 'active_profile',
      'value': kDefaultProfile,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // ----- profiles -----
  Future<List<Map<String, Object?>>> loadProfiles() =>
      _db!.query('profiles', orderBy: 'sort ASC, created_at ASC');

  Future<void> upsertProfile(
    String id,
    String name,
    String emoji,
    int createdAt,
    int sort,
  ) => _db!.insert('profiles', <String, Object?>{
    'id': id,
    'name': name,
    'emoji': emoji,
    'created_at': createdAt,
    'sort': sort,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  static const List<String> _profileTables = <String>[
    'stars',
    'stickers',
    'difficulty',
    'plays',
    'daily_time',
    'wallet',
    'toys',
    'achievements',
    'streak',
  ];

  Future<void> deleteProfile(String id) async {
    await _db!.delete('profiles', where: 'id = ?', whereArgs: <Object?>[id]);
    for (final String t in _profileTables) {
      await _db!.delete(t, where: 'profile_id = ?', whereArgs: <Object?>[id]);
    }
  }

  // ----- stars -----
  Future<Map<String, int>> loadStars(String profileId) async {
    final List<Map<String, Object?>> rows = await _db!.query(
      'stars',
      where: 'profile_id = ?',
      whereArgs: <Object?>[profileId],
    );
    return <String, int>{
      for (final Map<String, Object?> r in rows)
        r['game_id'] as String: r['stars'] as int,
    };
  }

  Future<void> setStar(String profileId, String gameId, int stars) =>
      _db!.insert('stars', <String, Object?>{
        'profile_id': profileId,
        'game_id': gameId,
        'stars': stars,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  // ----- stickers -----
  Future<List<String>> loadStickers(String profileId) async {
    final List<Map<String, Object?>> rows = await _db!.query(
      'stickers',
      where: 'profile_id = ?',
      whereArgs: <Object?>[profileId],
      orderBy: 'earned_at ASC',
    );
    return <String>[
      for (final Map<String, Object?> r in rows) r['sticker'] as String,
    ];
  }

  Future<void> addSticker(String profileId, String sticker, int earnedAt) =>
      _db!.insert('stickers', <String, Object?>{
        'profile_id': profileId,
        'sticker': sticker,
        'earned_at': earnedAt,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

  // ----- settings（全域）-----
  Future<Map<String, String>> loadSettings() async {
    final List<Map<String, Object?>> rows = await _db!.query('settings');
    return <String, String>{
      for (final Map<String, Object?> r in rows)
        r['key'] as String: r['value'] as String,
    };
  }

  Future<void> setSetting(String key, String value) => _db!.insert(
    'settings',
    <String, Object?>{'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  // ----- 適性難度 -----
  Future<Map<String, int>> loadDifficulty(String profileId) async {
    final List<Map<String, Object?>> rows = await _db!.query(
      'difficulty',
      where: 'profile_id = ?',
      whereArgs: <Object?>[profileId],
    );
    return <String, int>{
      for (final Map<String, Object?> r in rows)
        r['game_id'] as String: r['level'] as int,
    };
  }

  Future<void> setDifficulty(String profileId, String gameId, int level) =>
      _db!.insert('difficulty', <String, Object?>{
        'profile_id': profileId,
        'game_id': gameId,
        'level': level,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  // ----- 遊玩紀錄（家長報告用）-----
  Future<void> addPlay(
    String profileId,
    String gameId,
    int stars,
    int mistakes,
    int playedAt,
  ) => _db!.insert('plays', <String, Object?>{
    'profile_id': profileId,
    'game_id': gameId,
    'stars': stars,
    'mistakes': mistakes,
    'played_at': playedAt,
  });

  /// 每個遊戲的彙總：遊玩次數、累計錯誤、最佳星數。
  Future<List<Map<String, Object?>>> gameStats(String profileId) =>
      _db!.rawQuery(
        'SELECT game_id, COUNT(*) AS plays, SUM(mistakes) AS mistakes, '
        'MAX(stars) AS best FROM plays WHERE profile_id = ? GROUP BY game_id '
        'ORDER BY plays DESC',
        <Object?>[profileId],
      );

  Future<int> totalPlays(String profileId) async {
    final List<Map<String, Object?>> r = await _db!.rawQuery(
      'SELECT COUNT(*) AS n FROM plays WHERE profile_id = ?',
      <Object?>[profileId],
    );
    return (r.first['n'] as int?) ?? 0;
  }

  // ----- 每日使用時間（休息提醒 + 家長報告共用）-----
  Future<void> addDailyTime(String profileId, String day, int deltaSeconds) =>
      _db!.rawInsert(
        'INSERT INTO daily_time(profile_id, day, seconds) VALUES(?, ?, ?) '
        'ON CONFLICT(profile_id, day) DO UPDATE SET seconds = seconds + ?',
        <Object?>[profileId, day, deltaSeconds, deltaSeconds],
      );

  Future<Map<String, int>> loadDailyTime(String profileId) async {
    final List<Map<String, Object?>> rows = await _db!.query(
      'daily_time',
      where: 'profile_id = ?',
      whereArgs: <Object?>[profileId],
      orderBy: 'day DESC',
      limit: 14,
    );
    return <String, int>{
      for (final Map<String, Object?> r in rows)
        r['day'] as String: r['seconds'] as int,
    };
  }

  Future<void> clearProfileData(String profileId) async {
    for (final String t in _profileTables) {
      await _db!.delete(
        t,
        where: 'profile_id = ?',
        whereArgs: <Object?>[profileId],
      );
    }
  }

  // ----- 星星錢包 -----
  Future<(int, int)> loadWallet(String profileId) async {
    final List<Map<String, Object?>> rows = await _db!.query(
      'wallet',
      where: 'profile_id = ?',
      whereArgs: <Object?>[profileId],
      limit: 1,
    );
    if (rows.isEmpty) {
      await _db!.insert('wallet', <String, Object?>{
        'profile_id': profileId,
        'balance': 0,
        'earned_total': 0,
      });
      return (0, 0);
    }
    return (rows.first['balance'] as int, rows.first['earned_total'] as int);
  }

  Future<void> setWallet(String profileId, int balance, int earnedTotal) =>
      _db!.insert('wallet', <String, Object?>{
        'profile_id': profileId,
        'balance': balance,
        'earned_total': earnedTotal,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  // ----- 扭蛋玩具 -----
  Future<Map<String, int>> loadToys(String profileId) async {
    final List<Map<String, Object?>> rows = await _db!.query(
      'toys',
      where: 'profile_id = ?',
      whereArgs: <Object?>[profileId],
    );
    return <String, int>{
      for (final Map<String, Object?> r in rows)
        r['toy_id'] as String: r['count'] as int,
    };
  }

  Future<void> setToy(
    String profileId,
    String toyId,
    int count,
    int earnedAt,
  ) => _db!.insert('toys', <String, Object?>{
    'profile_id': profileId,
    'toy_id': toyId,
    'count': count,
    'earned_at': earnedAt,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  // ----- 成就 -----
  Future<Map<String, int>> loadAchievements(String profileId) async {
    final List<Map<String, Object?>> rows = await _db!.query(
      'achievements',
      where: 'profile_id = ?',
      whereArgs: <Object?>[profileId],
    );
    return <String, int>{
      for (final Map<String, Object?> r in rows)
        r['ach_id'] as String: r['tier'] as int,
    };
  }

  Future<void> setAchievement(
    String profileId,
    String achId,
    int tier,
    int unlockedAt,
  ) => _db!.insert('achievements', <String, Object?>{
    'profile_id': profileId,
    'ach_id': achId,
    'tier': tier,
    'unlocked_at': unlockedAt,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  // ----- 連續天數 -----
  Future<(String, int, int)?> loadStreak(String profileId) async {
    final List<Map<String, Object?>> rows = await _db!.query(
      'streak',
      where: 'profile_id = ?',
      whereArgs: <Object?>[profileId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (
      rows.first['last_day'] as String,
      rows.first['current'] as int,
      rows.first['best'] as int,
    );
  }

  Future<void> setStreak(
    String profileId,
    String lastDay,
    int current,
    int best,
  ) => _db!.insert('streak', <String, Object?>{
    'profile_id': profileId,
    'last_day': lastDay,
    'current': current,
    'best': best,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}
