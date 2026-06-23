# 技術規劃：付費解鎖 + 跨裝置進度同步

> 狀態：規劃（未實作）。定價 **NT$350**，模式 **Freemium + 一次性買斷**。
> 後端策略：**Google 原生**，零自建後端。
> 本文件是實作前的單一事實來源；對應商業決策見對話紀錄。

---

## 0. 兩句話總結

1. **付費解鎖**走 Google Play Billing 的「非消耗型商品」。`queryPurchases()` 在任何
   登入同一 Google/Play 帳號的裝置上**自動還原**——付費的跨裝置「免費附贈」，不需登入 UI。
2. **進度同步**走家長 Google 帳號 + Google **Drive appDataFolder**：把本機 SQLite 匯出成
   一份 JSON 快照丟到隱藏的 app 資料夾，換機/平板拉回來。家長在家長鎖後手動開啟，COPPA 安全。

這兩條軸**彼此獨立**，可分兩階段交付（先 Billing，再 Sync）。

---

## 1. 現況接縫（這些已經就緒，不用重蓋）

| 既有資產       | 位置                                             | 在本規劃的角色                          |
| ---------- | ---------------------------------------------- | -------------------------------- |
| 家長鎖（乘法題）   | `lib/core/parent_gate.dart` `showParentGate()` | 購買入口、開啟同步前的閘門，直接復用               |
| 學習報告儀表板    | `lib/screens/dashboard_screen.dart`            | 付費價值之一；免費看基本、付費看完整               |
| SQLite 持久層 | `lib/core/db.dart`（現 v4 ⇐ 本規劃升版）               | 同步只讀寫這幾張表，已是設計好的同步接縫             |
| 進度快取門面     | `lib/core/progress_store.dart`                 | entitlement 與 sync 狀態掛這裡，UI 同步讀取 |
| 關卡清單卡片     | `lib/screens/game_list.dart` `BigCard + onTap` | 鎖關卡 UI 與 paywall 觸發的唯一掛點         |
| 設定頁（家長區）   | `lib/screens/settings_screen.dart`             | 新增「升級完整版 / 雲端同步 / 還原購買」          |
| 啟動序列       | `lib/main.dart`                                | 插入 Billing/Sync 初始化              |
| 年齡段常數      | `registry.dart` `_age34/_age45/_age56`         | 免費/付費切分的依據                       |

---

## 2. 付費解鎖（Play Billing）

### 2.1 商品設計

- 套件：`in_app_purchase`（官方，含 Android Billing 封裝）。
- 商品：**單一非消耗型（managed product，非訂閱）**
  - SKU：`full_unlock_family`
  - 價格：NT$350（Play Console 以 TWD 為基準，其他幣別自動換算）
  - 解鎖：4-5 + 5-6 全關卡 + 家長儀表板完整版。**全域、跟 Google 帳號走、所有孩子檔案共用**。

### 2.2 EntitlementService（新檔 `lib/core/entitlement_service.dart`）

單例，職責：

1. **啟動時**：`InAppPurchase.instance.restorePurchases()` →
   監聽 `purchaseStream` → 收到 `full_unlock_family` 且狀態 `purchased/restored` →
   `_verify()` → 標記 `entitled = true`。
2. **購買流程**：`buyNonConsumable(...)` → 監聽同一 stream → 成功後 `completePurchase()`。
3. **驗證**：對買斷商品，採 **本機 + Google 簽章驗證** 即可（`PurchaseDetails.verificationData`）。
   不自建伺服器；若日後要更強，留 `_verify()` 介面可換成雲端驗證。
4. **本機快取**：寫入 `settings` 表 `key='entitlement_full' value='1'`（全域設定，不分 profile）。
   離線啟動時先信任快取，連線後以 `queryPurchases` 對帳（撤銷/退款 → 取消快取）。

對外 API（同步讀取，UI 不碰 async）：

```
EntitlementService.instance.isFullUnlocked  // bool，UI 直接讀
EntitlementService.instance.buyFullUnlock(context)   // 觸發購買
EntitlementService.instance.restore()                // 還原購買
EntitlementService.instance.addListener(...)         // 解鎖後刷新 UI
```

### 2.3 免費／付費切分（AccessPolicy，新檔 `lib/content/access_policy.dart`）

規則純資料驅動、集中一處，方便日後調整免費厚度：

- **3-4 歲（`age3_4`）**：全領域全關卡免費。
- **4-5 / 5-6 歲**：每個（年齡段 × 領域）的**第一關**免費試玩，其餘鎖。
- entitlement 為真時：全部解鎖。

```
bool isGameFree(GameDef g, AgeBand band):
  if band == age3_4: return true
  // 該 band×domain 下、registry 順序的第一個 = trial
  return g.id == firstGameId(band, g.domain)

bool isUnlocked(GameDef g, AgeBand band):
  return EntitlementService.instance.isFullUnlocked || isGameFree(g, band)
```

> 不改 `GameDef` 結構（保持 registry 簡潔）；鎖定是「政策」不是「資料屬性」，故獨立成
> `access_policy.dart`，吃 registry 既有順序決定 trial 關。

### 2.4 鎖關卡 UI（改 `game_list.dart`）

- 卡片若 `!isUnlocked`：疊半透明遮罩 + 🔒 角標，`onTap` 不進遊戲，改：
  `播放「這個要請爸爸媽媽解鎖喔」語音 → showParentGate → 通過則 push PaywallScreen`。
- 已解鎖卡片行為不變。

### 2.5 PaywallScreen（新檔 `lib/screens/paywall_screen.dart`）

- **對家長講價值**（孩子使用者看不懂、也不該被誘導）：列出解鎖後內容量、家長報告截圖、
  「一次買斷 NT$350、**非訂閱、不會自動扣款**」（台灣家長的信任賣點）。
- 主按鈕「解鎖完整版 NT$350」→ `buyFullUnlock`；次按鈕「還原購買」。
- 入口前已過 parent gate（2.4），故此頁可直接顯示價格。

### 2.6 設定頁新增（`settings_screen.dart`）

家長區加一張卡：未解鎖顯示「⭐ 升級完整版」→ PaywallScreen；已解鎖顯示「✅ 完整版已解鎖」+
「還原購買」按鈕（換機後手動觸發保險）。

### 2.7 啟動整合（`main.dart`）

`ProgressStore.init()` 後加 `await EntitlementService.instance.init();`
（內部 `restorePurchases` 對帳；失敗不阻擋進 App，先用本機快取）。

---

## 3. 跨裝置進度同步（Google Drive appDataFolder）

### 3.1 為什麼是 Drive appDataFolder（而非 Play Games Saved Games）

- appDataFolder 是**每個 App 專屬的隱藏資料夾**，免費、無容量焦慮、不需自建後端。
- 身份用**家長的 Google 帳號**（裝置擁有者），由家長在家長鎖後主動授權 →
  不涉及兒童 PII、不需要兒童帳號 → **COPPA / Google Families 友善**。
- Play Games Saved Games 偏遊戲帳號、對學齡前情境綁定彆扭，故不採。

### 3.2 依賴

- `google_sign_in`（取得帳號 + OAuth）
- `googleapis`（Drive v3）+ `googleapis_auth`
- scope 僅 `https://www.googleapis.com/auth/drive.appdata`（最小權限，看不到使用者其他檔案）

### 3.3 同步資料模型：整包 JSON 快照

不逐表逐列對帳（過度工程），而是把**目前裝置所有 profile 範圍的資料**匯出成一份快照：

```json
{
  "schema": 4,
  "deviceId": "<uuid>",
  "updatedAt": 1750000000,
  "profiles": [ {id,name,emoji,...} ],
  "data": {
    "<profileId>": {
      "stars": {...}, "stickers": [...], "difficulty": {...},
      "wallet": {...}, "toys": {...}, "achievements": {...},
      "streak": {...}, "plays": [...], "dailyTime": {...}
    }
  }
}
```

> 註：`entitlement_full` **不**進同步快照——付費狀態由 Play Billing 自己跨裝置還原，
> 避免「改快照偽造解鎖」的攻擊面。

### 3.4 SyncService（新檔 `lib/core/sync_service.dart`）

- `exportSnapshot()`：讀 AppDb 全表 → 組 JSON。
- `importSnapshot(json)`：覆寫本機（在交易內），完成後 `ProgressStore.reload()`。
- `push()`：export → 上傳覆蓋 appDataFolder 的 `progress.json`。
- `pull()`：下載 → 比對 `updatedAt` → 決定 merge。

### 3.5 衝突解決：whole-snapshot last-write-wins + 防退步

單一孩子在兩台裝置交替使用是主情境，故：

- 比 `updatedAt`：雲端較新 → 拉下覆寫；本機較新 → 推上去。
- **防退步保險**（避免「離線玩很多、卻被舊雲端蓋掉」）：匯入前，對每個 profile 的
  `wallet.earned_total`、`streak.best`、各遊戲 `stars` 取 **max**，星星/成就只增不減。
  → 即使時間戳判斷失誤，也不會吃掉孩子已賺到的進度。
- 真正分歧（兩台都離線各玩）罕見；採「保留較高 earned_total 的那份為主、另一份的 stars 逐項取 max」。

### 3.6 觸發時機

- **App 啟動**：若 `sync_enabled`，背景 `pull()`（不阻擋進首頁）。
- **變更後**：關卡完成等寫入後，debounce 30s `push()`（避免頻繁打 API）。
- **進 App 背景 / 離開**：`push()` 一次。
- **手動**：設定頁「立即同步」按鈕。
- 全程失敗**靜默降級**（純本機照常跑），只在設定頁顯示「上次同步：時間 / 失敗」。

### 3.7 UI（設定頁家長區）

一張「☁️ 雲端同步」卡：

- 關閉時：「開啟雲端同步」→ parent gate → Google 登入 → 首次 `pull`（雲端有資料則詢問
  「用雲端進度覆蓋本機？」二選一）。
- 開啟時：顯示帳號、上次同步時間、「立即同步」、「關閉同步（登出）」。

---

## 4. 資料模型變更（AppDb v4 migration）

`db.dart` `version: 3 → 4`，`_upgrade` 加 `if (oldVersion < 4)`：

- **不需新表**：同步走整包匯出、entitlement/sync 狀態存 `settings` 表既可。
- 新增 `settings` 鍵（全域）：
  - `entitlement_full`（'0'/'1'）
  - `sync_enabled`（'0'/'1'）
  - `sync_account`（email，顯示用）
  - `last_sync_at`（epoch）
  - `device_id`（首次啟動產生的 uuid，衝突解決辨識來源）
- `ProgressStore` 對應加：`isFullUnlocked`、`syncEnabled` 等同步讀取的 getter。
  
  > 設定鍵用 insert/replace，現有 `setSetting/loadSettings` 直接支援，migration 幾乎零風險。

---

## 5. 合規（Google Play）—— 這款是兒童 App，硬規則

- **購買前必過 parent gate**（已具備）；**不對孩子顯示**價格誘導或閃爍購買鈕。
- 符合 **Google Play Families Policy**：付費入口藏在家長區。
- **Data safety 表單**要更新：宣告會存取 Google Drive（appdata）、用途為「使用者進度備份」、
  不分享第三方、可刪除。
- **隱私政策**要新增：說明 Drive appDataFolder 用途、Billing 由 Google 處理、兒童不蒐集 PII。
- 退款依 Google Play 政策（買斷 48 小時自助退款）——entitlement 對帳會自動撤銷。

---

## 6. 測試策略

- **AccessPolicy**：純函式，單元測試免費/trial/鎖定三種情形（不需平台）。
- **EntitlementService**：抽 `InAppPurchase` 介面，用 fake 注入「已購/未購/退款」三情境，
  測快取與對帳邏輯（不打真 Play）。
- **SyncService**：`export → import` round-trip 不失真；衝突解決的「取 max 防退步」單元測試。
- **既有測試**：鎖關卡改動後，`game_list` 相關 widget 測試補「鎖卡點擊不進遊戲、走 paywall」。
- 不在 CI 測真實 Billing/Drive（需帳號），那部分靠手動驗收。

---

## 7. 你（Kevin）必須手動做的事 —— 我無法代勞

> 這些在 Play Console / Google Cloud 後台，需要你的帳號操作。我會在程式碼留 TODO 對應每一項。

**Play Console**

- [ ] 建立 managed product `full_unlock_family`，定價 TWD 350，啟用。
- [ ] 設定 License testing 帳號（自己的 Gmail），才能用測試卡免費跑購買流程。
- [ ] App content → Data safety 表單更新（Drive 存取）。
- [ ] 上傳更新後的隱私政策連結。
- [ ] 確認 App 已歸類於 Families 計畫 / 目標年齡。

**Google Cloud Console**（同步用）

- [ ] 建 OAuth Client（Android），填入 App 的 **SHA-1 簽章**（debug + release 各一）。
- [ ] OAuth consent screen 設定，加入 scope `drive.appdata`。
- [ ] 啟用 Google Drive API。

**App 設定**

- [ ] `google-services` / OAuth 設定檔放進 `android/`。
- [ ] 提供 release keystore SHA-1 給上面 OAuth Client。

---

## 8. 實作階段拆分（建議順序，可分次交付）

**Phase 1 — 付費解鎖（先做、可獨立上線）**

1. 加 `in_app_purchase` 依賴；DB v4 migration（settings 鍵）。
2. `EntitlementService` + `ProgressStore` 整合 + main.dart 啟動對帳。
3. `AccessPolicy` + 單元測試。
4. `game_list` 鎖關卡 UI + parent gate 觸發。
5. `PaywallScreen` + 設定頁升級/還原入口。
6. 接 License testing 帳號手動驗收購買/還原/退款對帳。
   
   > 估：實作面 2–3 個工作段；卡點在你開好 Play Console 商品 + 測試帳號。

**Phase 2 — 跨裝置同步（Phase 1 穩定後）**

1. 加 `google_sign_in` / `googleapis` 依賴。
2. `SyncService`（export/import/push/pull + 衝突取 max）。
3. 設定頁「雲端同步」卡 + 首次覆蓋詢問。
4. 啟動 pull / 變更 debounce push / 背景 push 串接。
5. round-trip + 衝突單元測試；雙裝置手動驗收。
   
   > 估：實作面 3–4 個工作段；卡點在你開好 OAuth Client + SHA-1。

---

## 9. 風險與取捨

| 風險                            | 因應                                                    |
| ----------------------------- | ----------------------------------------------------- |
| 本機 entitlement 快取被竄改偽造解鎖      | 連線後 `queryPurchases` 對帳即撤銷；買斷可接受此風險，不值得自建驗證後端         |
| 同步把孩子進度蓋掉                     | 3.5「只增不減取 max」防退步；首次開啟同步明確詢問覆蓋方向                      |
| 兒童無法登入 Google（Family Link 限制） | 同步綁**家長**帳號、家長主動授權，不要求兒童帳號                            |
| 免費內容給太少→沒人付                   | AccessPolicy 集中可調；先守「3-4 整段免費」，上線後看撞牆/轉換數據再調 trial 厚度 |
| Drive API 配額/離線               | 全程靜默降級為純本機；同步是加值不是必需                                  |
