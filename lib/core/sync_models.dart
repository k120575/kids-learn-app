/// 跨裝置同步的「整包快照」資料模型與合併邏輯（純 Dart，不依賴 Flutter / DB）。
///
/// 完整設計見 docs/PLAN_billing_sync.md §3。重點：
/// - 同步不逐列對帳，而是把所有 profile 的進度匯出成一份 JSON 快照上 Drive。
/// - 合併採「whole-snapshot last-write-wins + 防退步」：星星 / earned_total / streak.best /
///   玩具 / 成就一律「只增不減取 max」，即使時間戳判斷失誤也不會吃掉孩子已賺到的進度。
/// - `entitlement_full` **不**進快照（付費狀態由 Play Billing 自己跨裝置還原，杜絕改快照偽造解鎖）。
library;

/// 快照 schema 版本，對齊 AppDb version。改資料形狀時 +1 並在 import 端處理舊版。
const int kSnapshotSchema = 4;

Map<String, int> _maxMap(Map<String, int> a, Map<String, int> b) {
  final Map<String, int> out = Map<String, int>.from(a);
  b.forEach((String k, int v) {
    final int? cur = out[k];
    if (cur == null || v > cur) out[k] = v;
  });
  return out;
}

Map<String, int> _asIntMap(Object? v) {
  if (v is! Map) return <String, int>{};
  return <String, int>{
    for (final MapEntry<Object?, Object?> e in v.entries)
      e.key as String: (e.value as num).toInt(),
  };
}

/// 孩子檔案的中繼資料（不含進度本身）。
class ProfileMeta {
  const ProfileMeta({
    required this.id,
    required this.name,
    required this.emoji,
    required this.createdAt,
    required this.sort,
  });

  final String id;
  final String name;
  final String emoji;
  final int createdAt;
  final int sort;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'emoji': emoji,
    'createdAt': createdAt,
    'sort': sort,
  };

  factory ProfileMeta.fromJson(Map<String, Object?> j) => ProfileMeta(
    id: j['id'] as String,
    name: j['name'] as String,
    emoji: j['emoji'] as String,
    createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
    sort: (j['sort'] as num?)?.toInt() ?? 0,
  );
}

/// 單一孩子的全部進度資料。
///
/// 註：遊玩事件流（plays）為家長報告的歷史明細，跨裝置合併會重複且非「進度狀態」，
/// 故 v1 同步不納入快照（各裝置報告歷史維持本機）。彙總後的星星/成就/時間才進同步。
class ProfileData {
  const ProfileData({
    required this.stars,
    required this.stickers,
    required this.difficulty,
    required this.balance,
    required this.earnedTotal,
    required this.toys,
    required this.achievements,
    required this.streakLast,
    required this.streakCurrent,
    required this.streakBest,
    required this.dailyTime,
  });

  final Map<String, int> stars; // gameId → 最佳星數
  final Set<String> stickers;
  final Map<String, int> difficulty; // gameId → 等級
  final int balance; // 可花用星星
  final int earnedTotal; // 累積賺到的星星
  final Map<String, int> toys; // toyId → 擁有數
  final Map<String, int> achievements; // achId → 已解鎖等級
  final String streakLast;
  final int streakCurrent;
  final int streakBest;
  final Map<String, int> dailyTime; // yyyy-MM-dd → 秒

  Map<String, Object?> toJson() => <String, Object?>{
    'stars': stars,
    'stickers': stickers.toList(),
    'difficulty': difficulty,
    'balance': balance,
    'earnedTotal': earnedTotal,
    'toys': toys,
    'achievements': achievements,
    'streakLast': streakLast,
    'streakCurrent': streakCurrent,
    'streakBest': streakBest,
    'dailyTime': dailyTime,
  };

  factory ProfileData.fromJson(Map<String, Object?> j) => ProfileData(
    stars: _asIntMap(j['stars']),
    stickers: <String>{
      for (final Object? s in (j['stickers'] as List<Object?>? ?? <Object?>[]))
        s as String,
    },
    difficulty: _asIntMap(j['difficulty']),
    balance: (j['balance'] as num?)?.toInt() ?? 0,
    earnedTotal: (j['earnedTotal'] as num?)?.toInt() ?? 0,
    toys: _asIntMap(j['toys']),
    achievements: _asIntMap(j['achievements']),
    streakLast: j['streakLast'] as String? ?? '',
    streakCurrent: (j['streakCurrent'] as num?)?.toInt() ?? 0,
    streakBest: (j['streakBest'] as num?)?.toInt() ?? 0,
    dailyTime: _asIntMap(j['dailyTime']),
  );

  /// 合併兩份同一孩子的進度：取 max 防退步。
  ///
  /// 「勝方」＝ earned_total 較高者（平手比 streak.best）。勝方提供無法逐項取 max 的
  /// 欄位（可花餘額、適性難度、目前連續天數）；可累積的欄位則兩邊逐項取 max。
  static ProfileData merge(ProfileData a, ProfileData b) {
    final bool bWins =
        b.earnedTotal > a.earnedTotal ||
        (b.earnedTotal == a.earnedTotal && b.streakBest > a.streakBest);
    final ProfileData win = bWins ? b : a;
    return ProfileData(
      stars: _maxMap(a.stars, b.stars),
      stickers: <String>{...a.stickers, ...b.stickers},
      difficulty: win.difficulty,
      balance: win.balance,
      earnedTotal: a.earnedTotal >= b.earnedTotal ? a.earnedTotal : b.earnedTotal,
      toys: _maxMap(a.toys, b.toys),
      achievements: _maxMap(a.achievements, b.achievements),
      streakLast: win.streakLast,
      streakCurrent: win.streakCurrent,
      streakBest: a.streakBest >= b.streakBest ? a.streakBest : b.streakBest,
      dailyTime: _maxMap(a.dailyTime, b.dailyTime),
    );
  }
}

/// 一台裝置匯出的整包進度快照。
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.schema,
    required this.deviceId,
    required this.updatedAt,
    required this.profiles,
    required this.data,
  });

  final int schema;
  final String deviceId;
  final int updatedAt; // epoch millis，衝突解決比這個
  final List<ProfileMeta> profiles;
  final Map<String, ProfileData> data; // profileId → 進度

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': schema,
    'deviceId': deviceId,
    'updatedAt': updatedAt,
    'profiles': <Object?>[for (final ProfileMeta m in profiles) m.toJson()],
    'data': <String, Object?>{
      for (final MapEntry<String, ProfileData> e in data.entries)
        e.key: e.value.toJson(),
    },
  };

  factory ProgressSnapshot.fromJson(Map<String, Object?> j) => ProgressSnapshot(
    schema: (j['schema'] as num?)?.toInt() ?? kSnapshotSchema,
    deviceId: j['deviceId'] as String? ?? '',
    updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
    profiles: <ProfileMeta>[
      for (final Object? m in (j['profiles'] as List<Object?>? ?? <Object?>[]))
        ProfileMeta.fromJson((m as Map).cast<String, Object?>()),
    ],
    data: <String, ProfileData>{
      for (final MapEntry<Object?, Object?> e
          in (j['data'] as Map? ?? <Object?, Object?>{}).entries)
        e.key as String: ProfileData.fromJson(
          (e.value as Map).cast<String, Object?>(),
        ),
    },
  );

  /// 合併本機與雲端快照：profiles 取聯集，相同孩子的進度逐項取 max 防退步。
  /// `updatedAt` 取較新者；中繼資料（名字/emoji）以較新一份為準。
  static ProgressSnapshot merge(ProgressSnapshot local, ProgressSnapshot remote) {
    final bool remoteNewer = remote.updatedAt > local.updatedAt;
    final ProgressSnapshot metaBase = remoteNewer ? remote : local;
    final ProgressSnapshot metaOther = remoteNewer ? local : remote;
    final Map<String, ProfileMeta> metaById = <String, ProfileMeta>{};
    for (final ProfileMeta m in metaOther.profiles) {
      metaById[m.id] = m;
    }
    for (final ProfileMeta m in metaBase.profiles) {
      metaById[m.id] = m; // 較新一份覆蓋同 id 的中繼資料
    }

    final Set<String> ids = <String>{...local.data.keys, ...remote.data.keys};
    final Map<String, ProfileData> merged = <String, ProfileData>{};
    for (final String id in ids) {
      final ProfileData? l = local.data[id];
      final ProfileData? r = remote.data[id];
      if (l != null && r != null) {
        merged[id] = ProfileData.merge(l, r);
      } else {
        merged[id] = (l ?? r)!;
      }
    }

    final List<ProfileMeta> profiles = metaById.values.toList()
      ..sort((ProfileMeta a, ProfileMeta b) => a.sort.compareTo(b.sort));

    return ProgressSnapshot(
      schema: kSnapshotSchema,
      deviceId: local.deviceId,
      updatedAt: local.updatedAt >= remote.updatedAt
          ? local.updatedAt
          : remote.updatedAt,
      profiles: profiles,
      data: merged,
    );
  }
}
