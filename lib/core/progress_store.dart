import '../models/profile.dart';
import 'db.dart';
import 'stickers.dart';

/// 進度與設定（記憶體快取 + 寫穿 SQLite）。
///
/// 對外維持「同步讀取」的 API，UI 不需處理 async；寫入則同步更新快取 +
/// 非同步寫進 [AppDb]。無平台環境（單元測試）時自動退回純記憶體。
///
/// 資料以「目前選定的孩子（active profile）」為範圍：切換孩子會重新載入該孩子的
/// 星星 / 貼紙 / 難度。設定（聲音、音樂、休息提醒）為全域共用。
class ProgressStore {
  ProgressStore._();
  static final ProgressStore instance = ProgressStore._();

  // 目前選定孩子的資料
  final Map<String, int> _stars = <String, int>{};
  final List<String> _stickers = <String>[];
  final Map<String, int> _difficulty = <String, int>{}; // gameId → 等級 0..2

  // 獎勵系統（v3）
  int _balance = 0; // 可花用星星
  int _earnedTotal = 0; // 累積賺到的星星總數
  final Map<String, int> _toys = <String, int>{}; // toyId → 擁有數量
  final Map<String, int> _achTier = <String, int>{}; // achId → 已解鎖等級
  int _streakCur = 0;
  int _streakBest = 0;
  String _streakLast = '';

  /// 本次開啟若有每日簽到獎勵，暫存於此供首頁顯示一次。
  (int bonus, int streak)? pendingWelcome;

  // 孩子檔案
  final List<Profile> _profiles = <Profile>[];
  String _active = AppDb.kDefaultProfile;

  // 全域設定
  bool _sound = true;
  bool _music = true;
  double _musicVol = 0.5;
  int _screen = 20;

  Future<void> init() async {
    // 預設（無平台 / 測試時的後備）
    _profiles
      ..clear()
      ..add(const Profile(id: AppDb.kDefaultProfile, name: '寶貝', emoji: '🐧'));
    _active = AppDb.kDefaultProfile;
    try {
      await AppDb.instance.init();
      final Map<String, String> s = await AppDb.instance.loadSettings();
      _sound = (s['sound_enabled'] ?? 'true') == 'true';
      _music = (s['music_enabled'] ?? 'true') == 'true';
      _musicVol = double.tryParse(s['music_volume'] ?? '0.5') ?? 0.5;
      _screen = int.tryParse(s['screen_time_minutes'] ?? '20') ?? 20;
      _active = s['active_profile'] ?? AppDb.kDefaultProfile;
      await _reloadProfiles();
      await _loadActiveData();
    } catch (_) {
      // 測試/無平台 → 純記憶體
    }
  }

  void _persist(Future<void> Function() op) {
    if (AppDb.instance.ready) {
      op().catchError((Object _) {});
    }
  }

  // ===================== 孩子檔案 =====================
  List<Profile> get profiles => List<Profile>.unmodifiable(_profiles);
  String get activeProfileId => _active;
  Profile get activeProfile => _profiles.firstWhere(
    (Profile p) => p.id == _active,
    orElse: () => _profiles.isNotEmpty
        ? _profiles.first
        : const Profile(id: AppDb.kDefaultProfile, name: '寶貝', emoji: '🐧'),
  );

  Future<void> _reloadProfiles() async {
    final List<Map<String, Object?>> rows = await AppDb.instance.loadProfiles();
    if (rows.isEmpty) return; // 保留記憶體後備
    _profiles
      ..clear()
      ..addAll(
        rows.map(
          (Map<String, Object?> r) => Profile(
            id: r['id'] as String,
            name: r['name'] as String,
            emoji: r['emoji'] as String,
            createdAt: r['created_at'] as int,
            sort: r['sort'] as int,
          ),
        ),
      );
    if (!_profiles.any((Profile p) => p.id == _active)) {
      _active = _profiles.first.id;
    }
  }

  Future<void> _loadActiveData() async {
    _stars
      ..clear()
      ..addAll(await AppDb.instance.loadStars(_active));
    _stickers
      ..clear()
      ..addAll(await AppDb.instance.loadStickers(_active));
    _difficulty
      ..clear()
      ..addAll(await AppDb.instance.loadDifficulty(_active));
    final (int, int) w = await AppDb.instance.loadWallet(_active);
    _balance = w.$1;
    _earnedTotal = w.$2;
    _toys
      ..clear()
      ..addAll(await AppDb.instance.loadToys(_active));
    _achTier
      ..clear()
      ..addAll(await AppDb.instance.loadAchievements(_active));
    final (String, int, int)? st = await AppDb.instance.loadStreak(_active);
    _streakLast = st?.$1 ?? '';
    _streakCur = st?.$2 ?? 0;
    _streakBest = st?.$3 ?? 0;
  }

  void _resetActiveMemory() {
    _stars.clear();
    _stickers.clear();
    _difficulty.clear();
    _toys.clear();
    _achTier.clear();
    _balance = 0;
    _earnedTotal = 0;
    _streakCur = 0;
    _streakBest = 0;
    _streakLast = '';
  }

  Future<void> switchProfile(String id) async {
    if (id == _active) return;
    _active = id;
    _persist(() => AppDb.instance.setSetting('active_profile', id));
    if (AppDb.instance.ready) {
      await _loadActiveData();
    } else {
      _resetActiveMemory();
    }
  }

  Future<void> addProfile(String name, String emoji) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final String id = 'p$now';
    final int sort = _profiles.length;
    final Profile prof = Profile(
      id: id,
      name: name,
      emoji: emoji,
      createdAt: now,
      sort: sort,
    );
    _profiles.add(prof);
    _persist(() => AppDb.instance.upsertProfile(id, name, emoji, now, sort));
    await switchProfile(id); // 新增後切到新孩子（全新空白進度）
  }

  Future<void> renameProfile(String id, String name, String emoji) async {
    final int idx = _profiles.indexWhere((Profile p) => p.id == id);
    if (idx < 0) return;
    final Profile old = _profiles[idx];
    _profiles[idx] = old.copyWith(name: name, emoji: emoji);
    _persist(
      () => AppDb.instance.upsertProfile(
        id,
        name,
        emoji,
        old.createdAt,
        old.sort,
      ),
    );
  }

  Future<void> deleteProfile(String id) async {
    if (_profiles.length <= 1) return; // 至少保留一個孩子
    _profiles.removeWhere((Profile p) => p.id == id);
    _persist(() => AppDb.instance.deleteProfile(id));
    if (_active == id) {
      await switchProfile(_profiles.first.id);
    }
  }

  // ===================== 星星 =====================
  int starsFor(String gameId) => _stars[gameId] ?? 0;

  /// 記錄成績：只保留「最佳星數」。
  Future<void> recordStars(String gameId, int stars) async {
    if (stars > starsFor(gameId)) {
      _stars[gameId] = stars;
      _persist(() => AppDb.instance.setStar(_active, gameId, stars));
    }
  }

  int totalStars() => _stars.values.fold<int>(0, (int a, int b) => a + b);

  Future<void> clearProgress() async {
    _resetActiveMemory();
    _persist(() => AppDb.instance.clearProfileData(_active));
  }

  // ===================== 適性難度 =====================
  /// 遊戲難度等級：0=簡單、1=一般、2=挑戰。預設 1。
  int levelFor(String gameId) {
    final int v = _difficulty[gameId] ?? 1;
    return v < 0 ? 0 : (v > 2 ? 2 : v);
  }

  /// 依本局表現微調難度：全對 → 升一級；錯 ≥3 → 降一級；其餘維持。
  Future<void> recordOutcome(String gameId, int mistakes) async {
    final int cur = levelFor(gameId);
    int next = cur;
    if (mistakes == 0) {
      next = cur < 2 ? cur + 1 : 2;
    } else if (mistakes >= 3) {
      next = cur > 0 ? cur - 1 : 0;
    }
    if (next != cur) {
      _difficulty[gameId] = next;
      _persist(() => AppDb.instance.setDifficulty(_active, gameId, next));
    }
  }

  // ===================== 遊玩紀錄 / 時間 =====================
  Future<void> logPlay(
    String gameId, {
    required int stars,
    required int mistakes,
  }) async {
    final int ts = DateTime.now().millisecondsSinceEpoch;
    _persist(
      () => AppDb.instance.addPlay(_active, gameId, stars, mistakes, ts),
    );
  }

  /// 由 ScreenTimeManager 週期性回報的「實際使用秒數」，累進到今天。
  Future<void> addActiveSeconds(int seconds) async {
    if (seconds <= 0) return;
    _persist(() => AppDb.instance.addDailyTime(_active, _today(), seconds));
  }

  Future<List<Map<String, Object?>>> gameStats() async {
    if (!AppDb.instance.ready) return <Map<String, Object?>>[];
    return AppDb.instance.gameStats(_active);
  }

  Future<Map<String, int>> dailyTime() async {
    if (!AppDb.instance.ready) return <String, int>{};
    return AppDb.instance.loadDailyTime(_active);
  }

  static String _today() {
    final DateTime n = DateTime.now();
    final String m = n.month.toString().padLeft(2, '0');
    final String d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  static String _yesterday() {
    final DateTime n = DateTime.now().subtract(const Duration(days: 1));
    final String m = n.month.toString().padLeft(2, '0');
    final String d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  // ===================== 星星錢包 =====================
  int get balance => _balance;
  int get earnedTotal => _earnedTotal;

  /// 賺到星星（每場遊戲結束呼叫）：同時增加餘額與累積總額。
  Future<void> addEarnedStars(int n) async {
    if (n <= 0) return;
    _balance += n;
    _earnedTotal += n;
    _persist(() => AppDb.instance.setWallet(_active, _balance, _earnedTotal));
  }

  /// 花星星（扭蛋）。餘額不足回傳 false。
  bool spendStars(int n) {
    if (_balance < n) return false;
    _balance -= n;
    _persist(() => AppDb.instance.setWallet(_active, _balance, _earnedTotal));
    return true;
  }

  /// 退回星星（扭蛋抽到重複）：只回到餘額，不計入「累積賺到」。
  void refundStars(int n) {
    _balance += n;
    _persist(() => AppDb.instance.setWallet(_active, _balance, _earnedTotal));
  }

  // ===================== 扭蛋玩具 =====================
  Map<String, int> get toys => Map<String, int>.unmodifiable(_toys);
  int toyCount(String id) => _toys[id] ?? 0;
  int get distinctToyCount => _toys.length;
  bool hasToy(String id) => _toys.containsKey(id);

  /// 收下一個玩具，回傳「是否為新玩具」（用於圖鑑與重複退星判斷）。
  bool addToy(String id) {
    final bool isNew = !_toys.containsKey(id);
    _toys[id] = (_toys[id] ?? 0) + 1;
    final int ts = DateTime.now().millisecondsSinceEpoch;
    _persist(() => AppDb.instance.setToy(_active, id, _toys[id]!, ts));
    return isNew;
  }

  // ===================== 成就 =====================
  int achTier(String id) => _achTier[id] ?? 0;

  Future<void> setAchTier(String id, int tier) async {
    _achTier[id] = tier;
    final int ts = DateTime.now().millisecondsSinceEpoch;
    _persist(() => AppDb.instance.setAchievement(_active, id, tier, ts));
  }

  /// 玩過（拿過星星）的遊戲 id —— 成就「探索家」用。
  Set<String> playedGameIds() =>
      _stars.keys.where((String k) => (_stars[k] ?? 0) > 0).toSet();

  /// 拿過 3 星的遊戲數 —— 成就「完美高手」用。
  int get gamesThreeStarCount => _stars.values.where((int v) => v >= 3).length;

  int get streakCurrent => _streakCur;
  int get streakBest => _streakBest;

  // ===================== 每日簽到（連續天數）=====================
  /// 每次開 App 呼叫一次：更新連續天數並發每日獎勵星星。
  Future<void> dailyCheckIn() async {
    final String today = _today();
    if (_streakLast == today) return; // 今天已簽到過
    if (_streakLast == _yesterday()) {
      _streakCur += 1;
    } else {
      _streakCur = 1;
    }
    if (_streakCur > _streakBest) _streakBest = _streakCur;
    _streakLast = today;
    _persist(
      () => AppDb.instance.setStreak(_active, today, _streakCur, _streakBest),
    );
    // 每日獎勵：基本 5 顆，連續滿 7 的倍數再加碼 10 顆。
    final int bonus = 5 + (_streakCur % 7 == 0 ? 10 : 0);
    await addEarnedStars(bonus);
    pendingWelcome = (bonus, _streakCur);
  }

  // ===================== 貼紙 =====================
  List<String> collectedStickers() => List<String>.unmodifiable(_stickers);

  bool hasSticker(String s) => _stickers.contains(s);

  Future<String?> grantNextSticker() async {
    for (final String s in stickerPool) {
      if (!_stickers.contains(s)) {
        _stickers.add(s);
        final int ts = DateTime.now().millisecondsSinceEpoch;
        _persist(() => AppDb.instance.addSticker(_active, s, ts));
        return s;
      }
    }
    return null;
  }

  // ===================== 設定 =====================
  bool get soundEnabled => _sound;
  set soundEnabled(bool v) {
    _sound = v;
    _persist(() => AppDb.instance.setSetting('sound_enabled', v.toString()));
  }

  bool get musicEnabled => _music;
  set musicEnabled(bool v) {
    _music = v;
    _persist(() => AppDb.instance.setSetting('music_enabled', v.toString()));
  }

  double get musicVolume => _musicVol;
  set musicVolume(double v) {
    _musicVol = v < 0 ? 0 : (v > 1 ? 1 : v);
    _persist(
      () => AppDb.instance.setSetting('music_volume', _musicVol.toString()),
    );
  }

  int get screenTimeMinutes => _screen;
  set screenTimeMinutes(int v) {
    _screen = v;
    _persist(
      () => AppDb.instance.setSetting('screen_time_minutes', v.toString()),
    );
  }
}
