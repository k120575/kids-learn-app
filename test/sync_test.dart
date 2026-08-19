import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/core/sync_models.dart';
import 'package:kids_learn_app/core/sync_service.dart';

ProfileData _data({
  Map<String, int>? stars,
  Set<String>? stickers,
  int balance = 0,
  int earnedTotal = 0,
  Map<String, int>? toys,
  Map<String, int>? achievements,
  String streakLast = '',
  int streakCurrent = 0,
  int streakBest = 0,
  Map<String, int>? dailyTime,
  Map<String, int>? difficulty,
}) => ProfileData(
  stars: stars ?? <String, int>{},
  stickers: stickers ?? <String>{},
  difficulty: difficulty ?? <String, int>{},
  balance: balance,
  earnedTotal: earnedTotal,
  toys: toys ?? <String, int>{},
  achievements: achievements ?? <String, int>{},
  streakLast: streakLast,
  streakCurrent: streakCurrent,
  streakBest: streakBest,
  dailyTime: dailyTime ?? <String, int>{},
);

ProgressSnapshot _snap({
  required String deviceId,
  required int updatedAt,
  List<ProfileMeta>? profiles,
  Map<String, ProfileData>? data,
}) => ProgressSnapshot(
  schema: kSnapshotSchema,
  deviceId: deviceId,
  updatedAt: updatedAt,
  profiles: profiles ?? const <ProfileMeta>[],
  data: data ?? const <String, ProfileData>{},
);

class _FakeCloud implements CloudGateway {
  static const String email = 'parent@gmail.com';

  ProgressSnapshot? remote;
  ProgressSnapshot? lastUploaded;
  bool signedIn = false;
  bool wipeCalled = false;

  @override
  Future<bool> isAvailable() async => signedIn;

  @override
  Future<String?> signedInEmail() async => signedIn ? email : null;

  @override
  Future<bool> signIn() async {
    signedIn = true;
    return true;
  }

  @override
  Future<void> signOut() async => signedIn = false;

  @override
  Future<ProgressSnapshot?> download() async => remote;

  @override
  Future<void> upload(ProgressSnapshot snapshot) async {
    lastUploaded = snapshot;
    remote = snapshot;
  }

  @override
  Future<void> wipe() async {
    wipeCalled = true;
    remote = null;
  }
}

void main() {
  group('ProfileData.merge 取 max 防退步', () {
    test('星星逐項取 max、聯集，不會被舊資料蓋掉', () {
      final ProfileData a = _data(
        stars: <String, int>{'g1': 3, 'g2': 1},
        earnedTotal: 100,
        streakBest: 10,
        toys: <String, int>{'t1': 2},
        achievements: <String, int>{'a1': 3},
      );
      final ProfileData b = _data(
        stars: <String, int>{'g1': 1, 'g3': 2},
        earnedTotal: 50,
        streakBest: 4,
        toys: <String, int>{'t1': 1, 't2': 1},
        achievements: <String, int>{'a1': 1, 'a2': 2},
      );
      final ProfileData m = ProfileData.merge(a, b);
      expect(m.stars, <String, int>{'g1': 3, 'g2': 1, 'g3': 2});
      expect(m.earnedTotal, 100);
      expect(m.streakBest, 10);
      expect(m.toys, <String, int>{'t1': 2, 't2': 1});
      expect(m.achievements, <String, int>{'a1': 3, 'a2': 2});
    });

    test('勝方（earned_total 較高）提供餘額 / 目前連續天數 / 難度', () {
      final ProfileData hi = _data(
        balance: 80,
        earnedTotal: 100,
        streakCurrent: 7,
        streakLast: '2026-06-28',
        difficulty: <String, int>{'g1': 2},
      );
      final ProfileData lo = _data(
        balance: 5,
        earnedTotal: 30,
        streakCurrent: 1,
        streakLast: '2026-06-01',
        difficulty: <String, int>{'g1': 0},
      );
      final ProfileData m = ProfileData.merge(lo, hi); // 順序不影響勝方判定
      expect(m.balance, 80);
      expect(m.streakCurrent, 7);
      expect(m.streakLast, '2026-06-28');
      expect(m.difficulty, <String, int>{'g1': 2});
      expect(m.earnedTotal, 100);
    });

    test('合併對稱：a,b 與 b,a 對可累積欄位結果一致', () {
      final ProfileData a = _data(stars: <String, int>{'g': 3}, earnedTotal: 9);
      final ProfileData b = _data(stars: <String, int>{'g': 2}, earnedTotal: 9);
      expect(
        ProfileData.merge(a, b).stars,
        ProfileData.merge(b, a).stars,
      );
    });
  });

  group('ProgressSnapshot', () {
    test('JSON round-trip 不失真', () {
      final ProgressSnapshot snap = _snap(
        deviceId: 'dev-1',
        updatedAt: 1750000000,
        profiles: <ProfileMeta>[
          const ProfileMeta(
            id: 'p1',
            name: '小明',
            emoji: '🐧',
            createdAt: 1,
            sort: 0,
          ),
        ],
        data: <String, ProfileData>{
          'p1': _data(
            stars: <String, int>{'g1': 3},
            stickers: <String>{'s1', 's2'},
            balance: 12,
            earnedTotal: 40,
            toys: <String, int>{'t1': 1},
            streakBest: 5,
            dailyTime: <String, int>{'2026-06-28': 600},
          ),
        },
      );
      final ProgressSnapshot back = ProgressSnapshot.fromJson(
        jsonDecode(jsonEncode(snap.toJson())) as Map<String, Object?>,
      );
      expect(back.deviceId, 'dev-1');
      expect(back.updatedAt, 1750000000);
      expect(back.profiles.single.name, '小明');
      expect(back.data['p1']!.stars, <String, int>{'g1': 3});
      expect(back.data['p1']!.stickers, <String>{'s1', 's2'});
      expect(back.data['p1']!.earnedTotal, 40);
      expect(back.data['p1']!.dailyTime, <String, int>{'2026-06-28': 600});
    });

    test('合併：聯集 profiles，新孩子也帶進來', () {
      final ProgressSnapshot local = _snap(
        deviceId: 'dev-local',
        updatedAt: 200,
        profiles: <ProfileMeta>[
          const ProfileMeta(
            id: 'p1',
            name: '小明',
            emoji: '🐧',
            createdAt: 1,
            sort: 0,
          ),
        ],
        data: <String, ProfileData>{
          'p1': _data(stars: <String, int>{'g1': 2}, earnedTotal: 10),
        },
      );
      final ProgressSnapshot remote = _snap(
        deviceId: 'dev-remote',
        updatedAt: 100,
        profiles: <ProfileMeta>[
          const ProfileMeta(
            id: 'p2',
            name: '小華',
            emoji: '🦊',
            createdAt: 2,
            sort: 1,
          ),
        ],
        data: <String, ProfileData>{
          'p2': _data(stars: <String, int>{'g9': 3}, earnedTotal: 99),
        },
      );
      final ProgressSnapshot m = ProgressSnapshot.merge(local, remote);
      expect(m.profiles.map((ProfileMeta p) => p.id).toSet(), <String>{
        'p1',
        'p2',
      });
      expect(m.data['p1']!.stars, <String, int>{'g1': 2});
      expect(m.data['p2']!.stars, <String, int>{'g9': 3});
      expect(m.updatedAt, 200); // 取較新
      expect(m.deviceId, 'dev-local');
    });
  });

  group('SyncService 流程（無平台，純記憶體 + 假雲端）', () {
    test('預設骨架閘道：未連線、開啟同步失敗', () async {
      SyncService.debugSetGateway(const StubCloudGateway());
      await SyncService.instance.init();
      expect(SyncService.instance.enabled, isFalse);
      expect(await SyncService.instance.enable(), isFalse);
      expect(SyncService.instance.enabled, isFalse);
    });

    test('登入後開啟同步 → enabled、帳號就緒、首次同步上傳', () async {
      final _FakeCloud cloud = _FakeCloud();
      SyncService.debugSetGateway(cloud);
      await SyncService.instance.init();
      final bool ok = await SyncService.instance.enable();
      expect(ok, isTrue);
      expect(SyncService.instance.enabled, isTrue);
      expect(SyncService.instance.account, 'parent@gmail.com');
      expect(cloud.lastUploaded, isNotNull); // 首次同步把本機推上去
      expect(SyncService.instance.status, SyncStatus.ok);
    });

    test('關閉同步 → enabled 變 false、登出、雲端保留', () async {
      final _FakeCloud cloud = _FakeCloud();
      SyncService.debugSetGateway(cloud);
      await SyncService.instance.init();
      await SyncService.instance.enable();
      await SyncService.instance.disable();
      expect(SyncService.instance.enabled, isFalse);
      expect(SyncService.instance.account, isNull);
      expect(cloud.signedIn, isFalse);
      expect(cloud.wipeCalled, isFalse); // 預設保留雲端備份
    });

    test('關閉同步並刪除雲端備份 → wipe 被呼叫、雲端清空（隱私政策承諾）', () async {
      final _FakeCloud cloud = _FakeCloud();
      SyncService.debugSetGateway(cloud);
      await SyncService.instance.init();
      await SyncService.instance.enable();
      expect(cloud.remote, isNotNull); // 首次同步已上傳
      final bool wiped =
          await SyncService.instance.disable(alsoWipeCloud: true);
      expect(wiped, isTrue);
      expect(cloud.wipeCalled, isTrue);
      expect(cloud.remote, isNull);
      expect(SyncService.instance.enabled, isFalse);
      expect(cloud.signedIn, isFalse);
    });

    test('破壞性變更後 pushLocalReplace：整包覆蓋上雲、不合併雲端舊資料', () async {
      final _FakeCloud cloud = _FakeCloud();
      // 雲端已有一個孩子的舊快照（模擬刪除前同步過）。
      cloud.remote = _snap(
        deviceId: 'dev-old',
        updatedAt: 100,
        profiles: <ProfileMeta>[
          const ProfileMeta(
            id: 'p-deleted',
            name: '已刪除的孩子',
            emoji: '🐧',
            createdAt: 1,
            sort: 0,
          ),
        ],
        data: <String, ProfileData>{
          'p-deleted': _data(stars: <String, int>{'g1': 3}, earnedTotal: 10),
        },
      );
      SyncService.debugSetGateway(cloud);
      await SyncService.instance.init();
      await SyncService.instance.enable();
      // 一般同步是合併：雲端舊孩子會出現在上傳結果（聯集）。
      expect(
        cloud.lastUploaded!.profiles.map((ProfileMeta p) => p.id),
        contains('p-deleted'),
      );
      // 本機刪除後改走覆蓋：上傳的是本機現況（無平台＝空），舊孩子不得復活。
      await SyncService.instance.pushLocalReplace();
      expect(SyncService.instance.status, SyncStatus.ok);
      expect(cloud.lastUploaded!.profiles, isEmpty);
      // 之後的 syncNow 也不會把（已被覆蓋掉的）資料撈回來。
      await SyncService.instance.syncNow();
      expect(cloud.lastUploaded!.profiles, isEmpty);
    });
  });
}
