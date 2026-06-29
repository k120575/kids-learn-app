import 'dart:async';
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'sync_models.dart';
import 'sync_service.dart';

/// 真正的 Google Drive appDataFolder 同步閘道（換掉 [StubCloudGateway]）。
///
/// 設計：把 google_sign_in（v7）+ googleapis(drive v3) 全部隔在這個檔，
/// `sync_service.dart` / UI 都不依賴它們，方便測試與保持核心乾淨。
///
/// 權限：只用 [kDriveAppDataScope]（drive.appdata）——看得到、改得到的只有本 App 自己的
/// 隱藏資料夾，碰不到使用者其他 Drive 檔案，對家長最安全（COPPA/Families 友善）。
///
/// ⚠️ 先決條件（Kevin 在 Google Cloud Console，見 docs/OAUTH_SETUP.md）：
///   1. 啟用 Drive API、OAuth 同意畫面(Auth Platform) 設好、scope 加 drive.appdata。
///   2. 建 **Android** OAuth client（套件 com.kevin.kids_learn_app + 各 build 的 SHA-1）。
///   3. **建一個 Web 類型 OAuth client**，把它的 client ID 填到下面 [kGoogleServerClientId]。
///      google_sign_in 在 Android 上「沒有 google-services.json」時，initialize() **必須**帶
///      Web client ID 當 serverClientId，否則登入會失敗（見 google_sign_in_android README）。
class DriveCloudGateway implements CloudGateway {
  DriveCloudGateway();

  /// 只要 drive.appdata 一個 scope。
  static const List<String> _scopes = <String>[kDriveAppDataScope];

  GoogleSignInAccount? _account;
  bool _initialized = false;

  /// google_sign_in v7 的 initialize() 只能呼叫一次。第一次用到時才初始化。
  Future<void> _ensureInit() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      // 沒用 google-services.json，必須提供 Web OAuth client ID。見類別註解。
      serverClientId: kGoogleServerClientId.isEmpty ? null : kGoogleServerClientId,
    );
    _initialized = true;
  }

  /// 嘗試以最小互動恢復先前的登入（背景同步用；不會跳帳號選擇 UI）。
  Future<GoogleSignInAccount?> _restore() async {
    if (_account != null) return _account;
    await _ensureInit();
    try {
      final Future<GoogleSignInAccount?>? f =
          GoogleSignIn.instance.attemptLightweightAuthentication();
      if (f == null) return _account;
      _account = await f;
    } catch (_) {
      // 恢復失敗就維持未登入；不丟例外（同步全程靜默降級）。
    }
    return _account;
  }

  /// 取得已授權 drive.appdata 的 HTTP 標頭（不彈 UI）。沒授權或無有效 token → null。
  Future<Map<String, String>?> _headers() async {
    final GoogleSignInAccount? account = await _restore();
    if (account == null) return null;
    return account.authorizationClient.authorizationHeaders(_scopes);
  }

  /// 建一個已帶授權標頭的 Drive API client；未登入/未授權 → null。
  Future<drive.DriveApi?> _api() async {
    final Map<String, String>? headers = await _headers();
    if (headers == null) return null;
    return drive.DriveApi(_AuthClient(headers));
  }

  @override
  Future<bool> isAvailable() async => await _headers() != null;

  @override
  Future<String?> signedInEmail() async => (await _restore())?.email;

  @override
  Future<bool> signIn() async {
    await _ensureInit();
    if (!GoogleSignIn.instance.supportsAuthenticate()) return false;
    try {
      // 1) 互動登入（家長已過 parent gate，由設定頁按鈕觸發）。
      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
      // 2) 確認已授權 drive.appdata（必要時跳授權 UI）。
      await account.authorizationClient.authorizeScopes(_scopes);
      _account = account;
      return true;
    } on GoogleSignInException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInit();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    _account = null;
  }

  @override
  Future<ProgressSnapshot?> download() async {
    final drive.DriveApi? api = await _api();
    if (api == null) return null;
    final String? id = await _findSnapshotId(api);
    if (id == null) return null;
    final drive.Media media = await api.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final List<int> bytes = await _collectBytes(media.stream);
    final Object? decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) return null;
    return ProgressSnapshot.fromJson(decoded.cast<String, Object?>());
  }

  @override
  Future<void> upload(ProgressSnapshot snapshot) async {
    final drive.DriveApi? api = await _api();
    if (api == null) return;
    final List<int> bytes = utf8.encode(jsonEncode(snapshot.toJson()));
    final drive.Media media = drive.Media(
      Stream<List<int>>.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );
    final String? existingId = await _findSnapshotId(api);
    if (existingId != null) {
      // 已有檔：只換內容，不動 metadata/parents。
      await api.files.update(drive.File(), existingId, uploadMedia: media);
    } else {
      // 首次：建在隱藏的 appDataFolder 內。
      final drive.File meta = drive.File()
        ..name = kSnapshotFileName
        ..parents = <String>['appDataFolder'];
      await api.files.create(meta, uploadMedia: media);
    }
  }

  /// 找 appDataFolder 內 [kSnapshotFileName] 的 fileId；沒有則 null。
  Future<String?> _findSnapshotId(drive.DriveApi api) async {
    final drive.FileList list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$kSnapshotFileName'",
      $fields: 'files(id,name)',
    );
    final List<drive.File>? files = list.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }

  static Future<List<int>> _collectBytes(Stream<List<int>> stream) async {
    final List<int> out = <int>[];
    await for (final List<int> chunk in stream) {
      out.addAll(chunk);
    }
    return out;
  }
}

/// 把 google_sign_in 取得的授權標頭塞進每個 Drive API 請求的 http client。
class _AuthClient extends http.BaseClient {
  _AuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
