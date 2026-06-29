# OAuth 設定指南（Phase 2 跨裝置同步 / Google Drive appDataFolder）

> 目的：讓 `DriveCloudGateway`（google_sign_in + Drive API）能在本機 debug build 端到端登入並讀寫
> Drive 的 `appDataFolder`。本文件對應 **2025 改版後的「Google Auth Platform」介面**（舊的單一
> 「OAuth 同意畫面」頁已拆成 品牌 / 目標對象 / 資料存取權 / 用戶端）。
>
> 相關文件：`docs/PLAN_billing_sync.md` §3/§7（同步技術規劃）、`docs/PLAY_STORE_LAUNCH.md`（上架/必改清單）。
> 程式接縫：`lib/core/sync_service.dart`（`CloudGateway` 介面 + `StubCloudGateway`，旗標 `kSyncFeatureEnabled`）。

---

## 0. 先備資料（照貼用）

| 項目 | 值 |
|---|---|
| 套件名稱 (Package name) | `com.kevin.kids_learn_app` |
| **Debug** SHA-1（本機 debug build 測試用） | `B6:87:E5:65:1D:C9:0C:B2:28:87:E4:B6:AD:DC:B3:79:F9:A7:7C:E1` |
| **Upload/Release** SHA-1（本機 release keystore `keystore/kids-learn-release.jks`，alias `kidslearn`） | `E3:35:CF:D6:CA:65:B2:B4:EC:A8:D2:9A:F5:21:BE:4F:A6:1C:54:53` |
| **Play App Signing** SHA-1 | ⚠️ 去 Play 後台抓（見 §1 步驟 0） |
| Drive scope（最小權限） | `https://www.googleapis.com/auth/drive.appdata` |
| 測試使用者 | `k120575@gmail.com`（+ 任何要測同步的家人帳號） |

### ⚠️ 為什麼要三組 SHA-1？（google_sign_in 在 Play 上最常見的坑）
上傳的是 AAB、Play 預設開「**Play App Signing**」，會用**另一把 App 簽署金鑰**重簽，使用者實際裝到的版本
指紋 ≠ 本機 release keystore。所以：
- **本機 debug build** 登入 → 要 **Debug SHA-1**
- **本機 release build** 登入 → 要 **Upload/Release SHA-1**
- **從 Play 下載安裝的版本** 登入 → 要 **Play App Signing SHA-1**

三組都登記才能覆蓋三種情境。**本機開發只需先建 debug 那組就能驗證**；release / Play 兩組在送正式版前補齊。

### 重新撈 SHA-1 的指令（之後需要時）
```bash
# Debug（標準密碼 android）
keytool -list -v -keystore "$USERPROFILE/.android/debug.keystore" \
  -alias androiddebugkey -storepass android -keypass android | grep -i SHA1

# Release（密碼在 android/key.properties，已 gitignore）
keytool -list -v -keystore keystore/kids-learn-release.jks -alias kidslearn | grep -i SHA1
```
keytool 路徑：`C:\Program Files\Java\jdk-21.0.10\bin\keytool`（已在 PATH）。
Play App Signing SHA-1：Play Console → App → 測試與發布 → 設定 → **應用程式簽署**，複製「應用程式簽署金鑰憑證」的 SHA-1。

---

## 1. Google Cloud Console 操作步驟

### 步驟 0 — 抓 Play App Signing SHA-1（可選，本機測試可略過）
Play Console → 你的 App → **測試與發布 → 設定 → 應用程式簽署 (App signing)**
→ 複製「**應用程式簽署金鑰憑證**」欄的 **SHA-1**。沒有它，正式從 Play 下載的人會登入失敗。

### 步驟 1 — 選/建 Cloud 專案
https://console.cloud.google.com/ → 右上專案下拉 → 沿用 `kids-learn-app`（已建）或新增。

### 步驟 2 — 啟用 Drive API
選單 → **API 和服務 → 程式庫** → 搜尋「**Google Drive API**」→ **啟用**。

### 步驟 3 — Google Auth Platform（新版，左側選單依序做）

新版沒有單一「OAuth 同意畫面」頁，拆成下面三項。入口：選單 → **API 和服務 → OAuth 同意畫面**
（會導到 Google Auth Platform；左側即 品牌 / 目標對象 / 資料存取權 / 用戶端 / 驗證中心 / 設定）。

#### 3a — 品牌 (Branding)
- 應用程式名稱：**寶貝學習樂園**
- 使用者支援電郵：`k120575@gmail.com`
- 開發人員聯絡資訊：`k120575@gmail.com`
- Logo / 首頁網址可留空（要過正式驗證才需要）→ 儲存。

#### 3b — 目標對象 (Audience)　← 舊版的「User type + 測試使用者」
- 使用者類型：**外部 (External)**
- 發布狀態：**保持「測試中 (Testing)」**——別按「發布應用程式 / 推送正式版」。
- **測試使用者 (Test users)**：新增 `k120575@gmail.com`（+ 家人帳號）→ 儲存。
- 💡 Testing 模式下 `drive.appdata` 這種敏感範圍最多 **100 位測試使用者免 Google 審查**，封測夠用。
- ⚠️ 測試使用者的授權 **7 天會過期**，過期重登一次即可，不影響開發。

#### 3c — 資料存取權 (Data Access)　← 舊版的「Scopes」
- 按「**新增或移除範圍 (Add or remove scopes)**」
- 面板最下方「**手動新增範圍 (Manually add scopes)**」文字框貼上：
  ```
  https://www.googleapis.com/auth/drive.appdata
  ```
- 「新增到表格」→ 勾選 → **更新 (Update)** → 儲存。

### 步驟 4 — 用戶端 (Clients)：建 Android OAuth Client
左側「**用戶端**」（或總覽的「建立 OAuth 用戶端」）→ 應用程式類型 **Android**：
- 名稱：`kids-learn-android`
- 套件名稱：`com.kevin.kids_learn_app`
- SHA-1：**一個 client 只能填一組**，故建三個（先建 debug 即可開始開發）：

| 順序 | 名稱 | SHA-1 |
|---|---|---|
| 1（先測這個就夠） | kids-learn-debug | `B6:87:E5:65:1D:C9:0C:B2:28:87:E4:B6:AD:DC:B3:79:F9:A7:7C:E1` |
| 2 | kids-learn-release | `E3:35:CF:D6:CA:65:B2:B4:EC:A8:D2:9A:F5:21:BE:4F:A6:1C:54:53` |
| 3 | kids-learn-play | （Play 後台「應用程式簽署」抓的那組） |

Android client 不會給要塞進 App 的金鑰——Google 用「套件名 + SHA-1」配對授權，**App 端不需下載 json、不需貼任何 client_id**。

### 步驟 4.5（⚠️ 必需！）— 建一個 Web client，並把 client ID 給我
**這步不是選項。** google_sign_in v7 在 Android 上「**沒用 google-services.json**」時，
`initialize()` 必須帶一個 **Web 類型** OAuth client 的 client ID 當 `serverClientId`，
否則登入會直接失敗（出處：`google_sign_in_android` README）。我們沒用 Firebase，所以一定要建。

憑證 (Credentials) → 建立憑證 → OAuth 用戶端 ID → 應用程式類型 **Web 應用程式**：
- 名稱：`kids-learn-web`
- 重新導向 URI / JavaScript 來源：**留空即可**（Android 用不到，只是要它的 client ID）
- 建立後，複製那串 **client ID**（結尾 `.apps.googleusercontent.com`）→ **貼給我**。

我會把它填進 `lib/core/sync_service.dart` 的 `kGoogleServerClientId`。填好才能在實機真正登入。

---

## 2. 完成後 → 程式端（我接手，可端到端驗證）

最小可驗證里程碑＝**資料存取權加好 `drive.appdata` + 建好 debug OAuth client**。達成後：

1. 加依賴：`google_sign_in`、`googleapis`(drive v3)、`googleapis_auth`。
2. 寫 `DriveCloudGateway implements CloudGateway`（`lib/core/sync_service.dart` 內已留 TODO 對照）：
   - `signIn()`：`GoogleSignIn(scopes:[kDriveAppDataScope]).signIn()` → 取 authHeaders。
   - `isAvailable()`：是否有已登入帳號 + 能取授權標頭。
   - `download()`：`drive.files.list(spaces:'appDataFolder', q: name='progress.json')` → `files.get(fullMedia)` → `ProgressSnapshot.fromJson`。
   - `upload()`：無檔則 create、有檔則 update，`parents:['appDataFolder']`、media = 快照 JSON。
3. `main.dart` 把 `StubCloudGateway` 換成 `DriveCloudGateway`、翻 `kSyncFeatureEnabled = true`。
4. **雙裝置實機驗收**：debug build 用測試帳號登入 → A 機玩→push、B 機 pull 接續；測「兩機離線各玩再同步」取 max 不退步。
5. 補測試、`flutter analyze` + 全測綠。

---

## 3. ⚠️ 送審鐵則（出「B 版／含同步」時，程式與 Play 成對改）

翻 `kSyncFeatureEnabled = true` 屬「B 版」，**不可直接覆蓋已上封測的 A 版**。必須成對處理：
- **程式**：接好 Drive + 翻旗標 + `pubspec.yaml` versionCode +1（下次 ≥ `1.0.1+3`）。
- **Play**：Data safety 情境 **A→B**、隱私網址換 `docs/privacy-phase2-draft.html` 內容（逐欄表見
  `docs/PLAY_STORE_LAUNCH.md`「之後改版必改清單」）。
- 封測滿 14 天/12 人後，才申請發布正式版。

故開發階段先「程式做完 + 本機驗證」，**送審那步等 Kevin 決定**。
