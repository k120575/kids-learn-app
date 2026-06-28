import 'dart:math';

import 'package:flutter/foundation.dart';

import 'db.dart';
import 'progress_store.dart';
import 'sync_models.dart';

/// Phase 2 跨裝置進度同步（Google Drive appDataFolder）的 App 端核心。
/// 完整設計見 docs/PLAN_billing_sync.md §3。
///
/// 這是「骨架」：同步狀態、設定持久化、合併（取 max 防退步）、export/import round-trip
/// 都已就緒且可單元測試。真正打 Google 登入 / Drive API 的部分抽在 [CloudGateway] 介面後，
/// 預設用 [StubCloudGateway]（永遠回報「未連線」）。等 OAuth 開好後，新增一個
/// google_sign_in + googleapis 的實作換上去即可，本檔與 UI 都不用改。
///
/// ⚠️ v1.0 上架版本維持 [kSyncFeatureEnabled] = false：設定頁不顯示同步卡、不觸發任何
/// 網路行為，保持「離線零收集」（對應 Play Data safety 情境 A）。要開賣同步那一版才翻 true，
/// 並同時把 Play 問卷改情境 B、換隱私政策（見 docs/PLAY_STORE_LAUNCH.md「之後改版必改清單」）。

/// 同步功能總開關。false＝整套同步 UI/行為隱藏（v1.0 離線版）。
const bool kSyncFeatureEnabled = false;

/// Drive 上的快照檔名（存在 appDataFolder 隱藏資料夾內）。
const String kSnapshotFileName = 'progress.json';

/// 最小權限 scope：只看得到本 App 自己的隱藏資料夾，看不到使用者其他檔案。
const String kDriveAppDataScope = 'https://www.googleapis.com/auth/drive.appdata';

enum SyncStatus { idle, syncing, ok, failed }

/// 雲端閘道：把 google_sign_in / Drive API 隔在介面後，方便測試注入假實作。
abstract class CloudGateway {
  /// 目前是否已登入且雲端可用。
  Future<bool> isAvailable();

  /// 已登入的家長 Google 帳號 email（顯示用）；未登入回 null。
  Future<String?> signedInEmail();

  /// 家長主動觸發登入並授權 drive.appdata。回傳是否成功。
  Future<bool> signIn();

  /// 登出（關閉同步時）。
  Future<void> signOut();

  /// 下載雲端快照；appDataFolder 內尚無檔案則回 null。
  Future<ProgressSnapshot?> download();

  /// 上傳快照覆蓋 appDataFolder 的 [kSnapshotFileName]。
  Future<void> upload(ProgressSnapshot snapshot);
}

/// 預設骨架實作：永遠未連線。換成真的 Drive 同步前的佔位。
///
/// TODO(sync): 新增 `DriveCloudGateway implements CloudGateway`，以 google_sign_in + googleapis 實作：
///   - 依賴：pubspec 加 `google_sign_in`、`googleapis`（drive v3）、`googleapis_auth`。
///   - signIn()        → GoogleSignIn(scopes:[kDriveAppDataScope]).signIn()，取 authHeaders。
///   - isAvailable()   → 是否有已登入帳號 + 能取得授權標頭。
///   - download()      → drive.files.list(spaces:'appDataFolder', q:name=progress.json)
///                       → 有則 files.get(downloadOptions: fullMedia) → jsonDecode → ProgressSnapshot.fromJson。
///   - upload()        → 無檔則 create、有檔則 update，parents:['appDataFolder']、media=快照 JSON。
///   接上後把 [SyncService.instance] 的 gateway 換成它（見 main.dart）。
///   先決條件（Kevin 在 Google Cloud Console）：建 OAuth Client(Android) + 填 release/debug SHA-1、
///   OAuth consent screen 加 scope drive.appdata、啟用 Drive API（見 PLAN §7）。
class StubCloudGateway implements CloudGateway {
  const StubCloudGateway();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String?> signedInEmail() async => null;

  @override
  Future<bool> signIn() async => false;

  @override
  Future<void> signOut() async {}

  @override
  Future<ProgressSnapshot?> download() async => null;

  @override
  Future<void> upload(ProgressSnapshot snapshot) async {}
}

/// 同步狀態的單一事實來源。UI 同步讀 [enabled]/[account]/[status]，變更後 notifyListeners。
class SyncService extends ChangeNotifier {
  SyncService._(this._gateway);

  /// 全域單例。預設用骨架閘道；接上真 Drive 後改這裡的 gateway。
  static SyncService instance = SyncService._(const StubCloudGateway());

  /// 測試用：注入假閘道並重置狀態。
  @visibleForTesting
  static void debugSetGateway(CloudGateway gateway) {
    instance = SyncService._(gateway);
  }

  final CloudGateway _gateway;

  static const String _kEnabled = 'sync_enabled';
  static const String _kAccount = 'sync_account';
  static const String _kLastSync = 'last_sync_at';
  static const String _kDeviceId = 'device_id';

  bool _enabled = false;
  String? _account;
  int _lastSyncAt = 0;
  String _deviceId = '';
  SyncStatus _status = SyncStatus.idle;

  bool get enabled => _enabled;
  String? get account => _account;
  int get lastSyncAt => _lastSyncAt;
  String get deviceId => _deviceId;
  SyncStatus get status => _status;

  /// 啟動：載入同步設定、確保 device_id 存在。不做網路行為（失敗不阻擋進 App）。
  /// 之後若 [enabled]，呼叫端可在背景觸發 [syncNow]。
  Future<void> init() async {
    final Map<String, String> s = await _loadSettings();
    _enabled = (s[_kEnabled] ?? '0') == '1';
    _account = s[_kAccount];
    _lastSyncAt = int.tryParse(s[_kLastSync] ?? '0') ?? 0;
    _deviceId = s[_kDeviceId] ?? '';
    if (_deviceId.isEmpty) {
      _deviceId = _newDeviceId();
      await _setSetting(_kDeviceId, _deviceId);
    }
    notifyListeners();
  }

  /// 家長開啟同步：登入 → 首次同步（合併雲端與本機，取 max 防退步，不會吃掉任一邊進度）。
  /// 呼叫端須已通過 parent gate。回傳是否成功開啟。
  ///
  /// TODO(sync): PLAN §3.7 提到「首次開啟若雲端有資料，詢問用雲端覆蓋本機 or 上傳本機」。
  /// 目前採安全預設＝雙向合併取 max（不需使用者抉擇、也不會退步）；日後要做覆蓋詢問再加。
  Future<bool> enable() async {
    if (!await _gateway.signIn()) return false;
    _enabled = true;
    _account = await _gateway.signedInEmail();
    await _setSetting(_kEnabled, '1');
    if (_account != null) await _setSetting(_kAccount, _account!);
    notifyListeners();
    await syncNow();
    return true;
  }

  /// 關閉同步並登出。本機進度永遠保留（訪客也存），只是不再上雲。
  Future<void> disable() async {
    await _gateway.signOut();
    _enabled = false;
    _account = null;
    await _setSetting(_kEnabled, '0');
    await _setSetting(_kAccount, '');
    notifyListeners();
  }

  /// 立即同步：下載雲端 → 與本機合併（取 max）→ 寫回本機 → 上傳合併結果。
  /// 全程失敗靜默降級（純本機照常跑），只更新 [status] 供設定頁顯示。
  Future<void> syncNow() async {
    if (!_enabled) return;
    _setStatus(SyncStatus.syncing);
    try {
      if (!await _gateway.isAvailable()) {
        _setStatus(SyncStatus.failed);
        return;
      }
      final ProgressSnapshot local = await _exportLocal();
      final ProgressSnapshot? remote = await _gateway.download();
      final ProgressSnapshot merged = remote == null
          ? local
          : ProgressSnapshot.merge(local, remote);
      if (remote != null) {
        await _importMerged(merged);
      }
      await _gateway.upload(merged);
      _lastSyncAt = merged.updatedAt;
      await _setSetting(_kLastSync, '$_lastSyncAt');
      _setStatus(SyncStatus.ok);
    } catch (_) {
      _setStatus(SyncStatus.failed);
    }
  }

  Future<ProgressSnapshot> _exportLocal() async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (!AppDb.instance.ready) {
      // 無平台（測試）→ 空快照。
      return ProgressSnapshot(
        schema: kSnapshotSchema,
        deviceId: _deviceId,
        updatedAt: now,
        profiles: const <ProfileMeta>[],
        data: const <String, ProfileData>{},
      );
    }
    return AppDb.instance.exportSnapshot(_deviceId, now);
  }

  Future<void> _importMerged(ProgressSnapshot merged) async {
    if (!AppDb.instance.ready) return;
    await AppDb.instance.importSnapshot(merged);
    await ProgressStore.instance.reload();
  }

  void _setStatus(SyncStatus s) {
    _status = s;
    notifyListeners();
  }

  String _newDeviceId() {
    final Random r = Random();
    final int ms = DateTime.now().microsecondsSinceEpoch;
    final int rand = r.nextInt(0x7fffffff);
    return '${ms.toRadixString(16)}-${rand.toRadixString(16)}';
  }

  Future<Map<String, String>> _loadSettings() async {
    if (!AppDb.instance.ready) return <String, String>{};
    try {
      return await AppDb.instance.loadSettings();
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _setSetting(String key, String value) async {
    if (!AppDb.instance.ready) return;
    try {
      await AppDb.instance.setSetting(key, value);
    } catch (_) {}
  }
}
