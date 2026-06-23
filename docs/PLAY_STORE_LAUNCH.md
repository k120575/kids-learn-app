# Play Store 上架完整步驟 — 寶貝學習樂園 v1.0

> 從產生簽署金鑰到送審，**從上到下照順序做**。
> 每個步驟標明在「**網站**」「**本機**」「**手機**」哪裡操作，給網址/路徑。
> ✅ = 已完成可跳過；⬜ = 還沒做。
> 
> **這是一款「兒童 App」（目標 3–6 歲）**，跟一般 App 多了一整套 **Google Play Families（家庭）政策**要遵守。
> 凡是 🧸 標記的段落，就是「因為這是兒童 App 才特別要注意」的地方，務必照做。

---

## ⚠️ 先讀（兩件最關鍵的事，沒搞清楚會白做工）

### ⚠️ 一：要「真的能賣」＝ Play Console 建商品 **且** App 端串好 Billing，缺一不可

本文件聚焦 **Play Console / 上架操作面**。但你要知道：目前 App 內的付費是**骨架（StubGateway）**——

- `lib/core/entitlement_service.dart` 目前掛的是 `StubGateway`，`buy()` **永遠回傳「暫時無法購買」**。
- `in_app_purchase` 套件**還沒加進 `pubspec.yaml`**，`PlayBillingGateway` 只是 TODO 註解。
- `lib/screens/paywall_screen.dart` 付費牆 UI、`lib/content/access_policy.dart` 鎖關卡邏輯都已就緒，但**按下去不會真的完成購買**。

👉 **結論：要真的賣出 `full_unlock_family`，必須兩邊都完成：**

| 要做的事                                                                                 | 在哪               | 本文件涵蓋？                                      |
| ------------------------------------------------------------------------------------ | ---------------- | ------------------------------------------- |
| ① 在 Play Console 建立 managed product、設 Active、設測試帳號                                   | Play Console（網站） | ✅ 階段 6                                      |
| ② App 端把 `StubGateway` 換成真正的 `PlayBillingGateway`（加 `in_app_purchase` 依賴、實作購買/還原/對帳） | 本機（程式碼）          | ❌ 不在本文件，見 `docs/PLAN_billing_sync.md` §2、§7 |

> 你可以**先不含付費上架**（v1.0 全部關卡先免費或先只開放部分、付費牆暫時隱藏），之後版本再補 Billing；
> 也可以等 ② 做完再一起上。但**只做 ① 不做 ②，使用者按付費牆只會看到「暫時無法購買」**。請先決定策略。

### ⚠️ 二：新個人帳號的「正式版關卡」——封閉測試 12 人 / 14 天

你的開發者帳號（`k120575@gmail.com`）是**個人帳號、且在 2023/11/13 之後新建**，Google 強制規定：

> **必須先做「封閉測試（Closed testing）」，至少 12 位測試人員、連續 14 天參與，才有資格申請發布正式版。**

- **「內部測試（Internal testing）」不算數**——只能拿來自己快速 QA，無法解鎖正式版。
- 12 人是現行數字（2024/12/11 從 20 人降到 12）；14 天必須是**同一批人連續**，中途退出就重算。
- 達標前 Play Console 的「正式版」功能是**鎖住的**。達標後到資訊主頁按「申請發布正式版」、回答 3 段問卷，審查約 7 天。

👉 **時程瓶頸 = 湊 12 個真人 + 等 14 天。策略：先把封閉測試開起來、找人掛上去（時鐘越早跑越好），這 14 天同時把階段 4～6 全部補完。** 詳見**階段 8**。

來源：[App testing requirements for new personal developer accounts — Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)

---

## 🧸 兒童 App 特別須知（和一般 App 最大的差別）—— 2026 現行規定

本 App 目標 **3–6 歲學齡前兒童**，因此**目標年齡層必須包含兒童**，這會觸發 **Google Play Families（家庭）政策**。重點如下（後面各階段會逐一落實）：

| 項目                               | 本 App 要怎麼做                                                                                                                                                                      | 來源                                                                                                                                                                 |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **目標年齡層**                        | 在「目標對象與內容」勾 **Ages 5 and under**（+ 視情況 6-8）。任一勾到兒童 → 自動納入 Families 政策。                                                                                                          | [目標對象與內容](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en)                                                                            |
| **承諾遵守 Families Policy**         | Data safety 最後一題「Have you committed to the Google Play Families Policy?」要選 **Yes**（與一般 18+ App 相反）。                                                                             | [Families Policies](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)                                                                  |
| **內容適齡**                         | 全部內容（題目、emoji、語音、玩具圖鑑）都已是幼兒向，無暴力/性/不當內容 → 已符合。                                                                                                                                  | 同上                                                                                                                                                                 |
| **廣告**                           | **本 App 無廣告**。若日後加廣告，只能用「Families 自我認證廣告 SDK」、禁止興趣式/再行銷廣告、禁止全螢幕干擾式廣告。目前申報 **No ads** 最單純。                                                                                       | [Families 自我認證廣告 SDK](https://support.google.com/googleplay/android-developer/answer/12918983?hl=en)                                                               |
| **購買要過家長閘門（parent gate）**        | 付費入口前**已有家長鎖**（乘法題，`lib/core/parent_gate.dart`），孩子點不進付費牆 → **已符合**「避免兒童誤觸購買」。                                                                                                   | [Families Policies](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)                                                                  |
| **不可用「不適合兒童」的 SDK**              | 本 App **無任何第三方 SDK、無廣告/分析/崩潰回報 SDK** → 天然符合。                                                                                                                                    | 同上                                                                                                                                                                 |
| **兒童資料保護（COPPA / GDPR）更嚴**       | 本 App **完全離線、不蒐集任何資料、不傳輸廣告 ID/IMEI/MAC、不蒐集位置** → 天然符合最嚴格要求。                                                                                                                     | 同上                                                                                                                                                                 |
| **內容分級（IARC）**                   | 走分級問卷、選「教育類」、全部答 No → 會評為「適合所有人 / 3+」。                                                                                                                                          | [內容分級需求](https://support.google.com/googleplay/android-developer/answer/9859655?hl=en)                                                                             |
| **行銷素材與目標一致**                    | 截圖/feature graphic 是卡通幼兒風 → 因為目標已勾兒童，**一致、不會被退**。若沒勾兒童卻用卡通素材才會被退。                                                                                                               | [目標對象與內容](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en)                                                                            |
| **Designed for Families（選擇性加入）** | 「Designed for Families」是讓 App 進 Play 商店「兒童專區」的額外計畫，**非上架必需**。本文件先做到「符合 Families Policy 上架」即可；要進兒童專區再另外申請（見階段 9）。Google 已宣布 2026/04/15 起更新「主要面向兒童宣告」規則，給開發者至少 30 天合規期，加入前再查當下要求。 | [Families 計畫](https://play.google.com/console/about/programs/families/)、[公告](https://support.google.com/googleplay/android-developer/announcements/13412212?hl=en) |

> 🧸 **一句話內化**：本 App 因為「完全離線 + 無廣告 + 無 SDK + 有家長鎖」，其實是**最容易通過 Families 政策的型態**——
> 大部分兒童 App 的雷（廣告 SDK、蒐集資料、誘導購買）我們全都沒踩。你要做的主要是**把這些「乾淨」如實申報**。

---

## 名詞解釋（讀之前先看一下）

| 名詞                          | 是什麼                                     | 在哪                                                                |
| --------------------------- | --------------------------------------- | ----------------------------------------------------------------- |
| **Google Play Console**     | Google 給開發者的**網站**（不用安裝），管理上架的 App      | https://play.google.com/console/                                  |
| **AAB**（Android App Bundle） | Google Play 強制的上傳格式（比 APK 新）            | 打包後在本機 `android/app/build/outputs/bundle/release/app-release.aab` |
| **Keystore（簽署金鑰）**          | 證明 App 是你發的「印章檔」，**遺失就再也不能更新 App**      | 本 App **尚未產生**，見**階段 0**                                          |
| **Internal testing**（內部測試）  | 「先給特定人快速試用」軌道，幾分鐘就能裝；**只能自己 QA，不解鎖正式版** | Play Console 內                                                    |
| **Closed testing**（封閉測試）    | 新個人帳號**解鎖正式版的必經關卡**：≥12 人連續測 14 天       | Play Console 內                                                    |
| **Production**（正式版）         | 真的上架給所有人下載；新個人帳號要先過封閉測試                 | Play Console 內                                                    |
| **Families Policy**（家庭政策）   | 目標含兒童的 App 必須遵守的一整套政策（內容/廣告/購買/資料）      | 適用本 App 🧸                                                        |
| **License testers**（測試帳號）   | 你指定的 Google 帳號，買 IAP 不會真扣錢              | Play Console 內                                                    |
| **IAP / managed product**   | App 內可購買的東西；本 App 是 **1 個非消耗型解鎖商品**     | Play Console 內                                                    |
| **Parent gate（家長閘門）**       | 擋住孩子、只有家長能過的關卡；本 App 用乘法題               | App 內 `parent_gate.dart`                                          |

---

## 階段 0：本機準備 — 從零產生 Release Keystore + 設定簽署 ⬜

> 在**本機**操作。**這是 Flutter 專案、目前 release 還在用 debug 金鑰簽署**（見 `android/app/build.gradle.kts` 第 32 行
> `signingConfig = signingConfigs.getByName("debug")`），上架前**一定要換成自己的 release keystore**，否則之後永遠無法更新 App。

### 0.1 產生 release keystore（一行 `keytool` 指令）

開 **PowerShell**（或 Git Bash），先建資料夾再產金鑰。建議把 keystore 放在 **repo 之外**（避免不小心 commit 上 GitHub）：

```powershell
# 1) 建一個放金鑰的資料夾（在專案外面，例如桌面下）
New-Item -ItemType Directory -Force "D:\IdeaProject\keystores"

# 2) 產生 keystore（會問你密碼、姓名等，記下來）
keytool -genkey -v `
  -keystore "D:\IdeaProject\keystores\kids-learn-release.jks" `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias kidslearn
```

> `keytool` 隨 JDK 附帶。找不到指令時，用 Android Studio 內建 JDK 的 keytool：
> `& "$env:JAVA_HOME\bin\keytool.exe" ...`，或 Flutter 內附的
> `C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`。

過程會問：

- **keystore 密碼**（store password）：自己設、記牢
- **名字 / 組織 / 城市 / 國家**：隨意填（CN 填 `Kevin`、Country code 填 `TW`）
- **key 密碼**：可直接 Enter 沿用 keystore 密碼

產出檔：`D:\IdeaProject\keystores\kids-learn-release.jks`

### 0.2 建立 `android/key.properties`（告訴 Gradle 金鑰在哪）

在 **本機** 新增檔案 `D:\IdeaProject\kids-learn-app\android\key.properties`，內容（密碼改成你剛設的）：

```properties
storePassword=你的keystore密碼
keyPassword=你的key密碼
keyAlias=kidslearn
storeFile=D:/IdeaProject/keystores/kids-learn-release.jks
```

> ⚠️ **路徑用正斜線 `/`**（Gradle 吃 `/`，反斜線會出事）。
> ⚠️ **這個檔含密碼，絕不能進 git**。確認 `android/.gitignore` 有 `key.properties`（Flutter 預設已有；沒有就自己加一行）。

### 0.3 改 `android/app/build.gradle.kts`（套用 signingConfig）

把第 7 行 `android {` **之前**插入讀取 properties 的程式，並把 release buildType 改成用你的金鑰。
目前檔案（D:\IdeaProject\kids-learn-app\android\app\build.gradle.kts）長這樣：

```kotlin
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kevin.kids_learn_app"
    ...
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")   // ← 要換掉這行
        }
    }
}
```

改成（在最上方加 import + 讀檔，在 `android {}` 內加 `signingConfigs`，release 改用 `release` 設定）：

```kotlin
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// 讀取 android/key.properties（簽署金鑰資訊）
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.kevin.kids_learn_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kevin.kids_learn_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // 若想開混淆/縮減可加：isMinifyEnabled = true; isShrinkResources = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
```

> `rootProject.file("key.properties")` 指的是 `android/key.properties`（rootProject = `android/`）。

### 0.4 打包 release AAB

在**本機**專案根目錄（`D:\IdeaProject\kids-learn-app`）跑：

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

產出：`D:\IdeaProject\kids-learn-app\android\app\build\outputs\bundle\release\app-release.aab`

> ⚠️ 第一次跑記得確認 **versionCode = 1 / versionName = 1.0.0**（來自 `pubspec.yaml` 的 `version: 1.0.0+1`）。
> 之後每次更新都要 `+1`（例如 `1.0.1+2`），否則 Play 會擋「versionCode 重複」。

### 0.5 ⚠️ 備份金鑰（這步漏了會後悔一輩子）

- 把 `kids-learn-release.jks` **複製到雲端硬碟**（Google Drive / OneDrive）。
- 把 **keystore 密碼、key 密碼、alias（`kidslearn`）** 存進**密碼管理器**。
- **遺失這把金鑰 = 這個 App 永遠無法再更新**，只能用新 applicationId 重新上架（等於砍掉重練）。

### 0.6 記錄金鑰指紋（之後對照用，可選）

```powershell
keytool -list -v -keystore "D:\IdeaProject\keystores\kids-learn-release.jks" -alias kidslearn
```

把印出來的 **SHA-1 / SHA-256** 抄下來貼這裡（之後若要做 Google Drive 同步 OAuth，OAuth Client 要填 SHA-1）：

- **Alias**: `kidslearn`
- **SHA-1**: `[⚠️ 跑完上面指令填入]`
- **SHA-256**: `[⚠️ 跑完上面指令填入]`

---

## 階段 1：註冊 Google Play 開發者帳號 ⬜

> 在**網站**操作。一次性 **$25 美金**註冊費（信用卡），終身有效。
> （若 `k120575@gmail.com` 已註冊過開發者帳號，跳過本階段。）

1. 開 **https://play.google.com/console/signup**，用 `k120575@gmail.com` 登入
2. 帳號類型選 **Personal**（個人）
3. **Developer name**（公開顯示）：填 `Kevin`（或你想顯示的名字）
4. Email / Phone 用你自己的；國家選 **Taiwan**
5. 付 **$25 USD**（一次性、非訂閱）
6. **身份驗證**（拍身分證/護照 + 自拍），通常 1–3 個工作天審完

---

## 階段 2：在 Play Console 建立 App ⬜

> 在**網站** https://play.google.com/console/ 操作（身份驗證通過後）。

1. Play Console 首頁 → 右上角 **「Create app」**
2. 填表：

| 欄位（Console 英文）       | 填什麼                                                    |
| -------------------- | ------------------------------------------------------ |
| **App name**         | `寶貝學習樂園`                                               |
| **Default language** | `Chinese (Traditional) – zh-TW`                        |
| **App or game**      | **Game**（本 App 是遊戲化學習，選 Game 較貼，也可選 App；選 Game 會走遊戲分類） |
| **Free or paid**     | **Free**（免費下載，內含一個解鎖 IAP）                              |
| **Declarations** 兩個勾 | 都勾（內容政策同意 + 美國出口法規同意）                                  |

> 💡 App 還是 Game？本 App 是「學習遊戲」。選哪個都可上架；選 **Game → Educational（教育）** 對到幼兒教育最自然。若你偏好被歸到「教育類 App」也可選 App。本文件後面以 **Game / Educational** 為例。

3. 點 **Create app** → 進入 App 的 dashboard。

---

## 階段 3：上傳第一個 AAB 到 Internal testing ⬜

> 在**網站** Play Console 操作。
> **這步必須先做**——Play Console 在「上傳過任何 AAB 之前」會鎖住一堆功能（含 IAP 商品建立）。
> 
> ⚠️ 內部測試只是讓你自己先把 App 裝進手機跑 QA + 解鎖 IAP 設定，**不解鎖正式版**。解鎖正式版要的是封閉測試 12 人 / 14 天（階段 8）。同一包 AAB 兩個軌道都能用，建議內測上傳完、確認沒大問題，馬上把封測也開起來讓 14 天時鐘開跑。

### 3.1 找到 Internal testing 頁面

左側選單 **「測試及發布」→「測試」→「內部測試」**

### 3.2 建立第一個 release

1. 右上角 **Create new release**
2. 第一次會問 **Play App Signing** → 點 **Continue**（推薦讓 Google 幫你管理金鑰）
3. **App bundles** 區塊 **Upload** → 選本機：
   
   ```
   D:\IdeaProject\kids-learn-app\android\app\build\outputs\bundle\release\app-release.aab
   ```
4. 上傳完，**Release name** 自動填 `1 (1.0.0)`，保留就好
5. **Release notes** 填繁中：
   
   ```
   <zh-TW>
   首次上架。
   - 五大領域學習遊戲，全程國語語音導讀
   - 3-4 / 4-5 / 5-6 歲適齡分級、適性難度
   - 星星、扭蛋、貼紙、成就獎勵系統
   - 家長報告 + 家長鎖
   - 完全離線、不蒐集資料、無廣告
   </zh-TW>
   ```
6. 最下面 **Next** → **Save**（先別 Review release）

---

## 階段 4：填 App content（左側「政策與計畫 → 應用程式內容」一整串問卷）⬜

> 在**網站** Play Console 操作。
> 📍 **位置（2026 zh-TW）**：左側選單 **「政策與計畫」→「應用程式內容」**。進去有「需要處理 / 已處理」兩分頁，把「需要處理」清空就對了。
> ℹ️ 畫面上有什麼就填什麼，沒出現的就跳過。**🧸 兒童 App 三大關鍵：4.5 目標對象、4.8 Data safety、4.4 內容分級——填錯會下架/退件**。

### 4.1 Privacy policy（隱私政策）🧸 必填

點 **應用程式內容 → 隱私政策**，貼上隱私政策網址（**目前還沒有，見下方「附錄 A：隱私政策」先把網頁架好**）：

```
https://k120575.github.io/kids-learn-app/privacy.html
```

（網址依你 GitHub Pages 實際路徑調整）→ **Save**

### 4.2 App access（App 存取限制）

點 **應用程式內容 → App access**

本 App 無帳號登入、全功能對所有人開放（付費關卡屬於「付費」不是「特殊存取」）：

- 選 **All functionality is available without any special access**
- **Save**

### 4.3 Ads（廣告）🧸

點 **應用程式內容 → Ads**

- 選 **No, my app does not contain ads**（本 App 無任何廣告 SDK）
- **Save**

### 4.4 Content ratings（內容分級）🧸

點 **應用程式內容 → Content ratings → Start questionnaire**

1. **Email**：`k120575@gmail.com`
2. **Category**：選 **Reference, News, or Educational**（教育類）
3. 問卷全部答 **No**：

| 問題             | 答案                            |
| -------------- | ----------------------------- |
| 暴力             | No                            |
| 性內容 / 裸露       | No                            |
| 不雅言論           | No                            |
| 受管制物質（菸酒毒賭）    | No                            |
| 賭博（真實/模擬）      | No                            |
| 使用者產生內容 / 線上互動 | No                            |
| 分享使用者位置        | No                            |
| 蒐集個資           | No（本 App 完全不蒐集）               |
| 數位購買（App 內購買）  | **Yes**（有一個解鎖 IAP）→ 會問是否揭露，照實 |

4. **Submit** → Google 自動評為 **IARC「適合所有人 / 3+」**等級

> 💡 「App 內購買」那題據實答 Yes（本 App 有 `full_unlock_family`）；這不影響「適合所有人」分級，因為購買有家長鎖。

### 4.5 Target audience and content（目標對象與內容）🧸🧸 **最關鍵**

點 **應用程式內容 → Target audience and content**

> ⚠️ **這裡跟一般成人 App 完全相反**：一般 App 選 18+ 規避兒童法規；**本 App 目標就是兒童，必須勾兒童年齡層**。

1. **Target age groups（目標年齡層）**：勾 **Ages 5 and under**（核心 3–6 歲落在此組；6 歲那段可一併勾 **Ages 6-8**）
   - 年齡組選項全集：`Ages 5 and under` / `6-8` / `9-12` / `13-15` / `16-17` / `18 and over`
2. **Appeal to children / 主要面向兒童**：據實 **Yes**（App 設計、視覺、內容都面向幼兒）
3. 接著 Google 會說明：**此 App 須遵守 Families Policy**，照做填完
4. **Store presence 確認**：商店素材是卡通幼兒風 → 因為已勾兒童，**一致、不會被退**
5. **Save**

來源：[Manage target audience and app content settings](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en)、[Google Play Families Policies](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)

### 4.6 Data safety（資料安全申報）🧸🧸 **填錯會下架**

點 **應用程式內容 → Data safety → Start**

> **本 App v1.0 完全離線、不蒐集任何資料**（無 INTERNET 權限、無網路呼叫、無任何 SDK；全部資料只存本機 SQLite / shared_preferences）。所以這份是「兒童 App 裡最乾淨的申報」。

#### 情境 A：v1.0 不含 Google Drive 同步（目前現況，建議）

| 題目                                                                  | 答案     |
| ------------------------------------------------------------------- | ------ |
| Does your app collect or share any of the required user data types? | **No** |
| （選 No 後，後續資料類型表全部跳過）                                                | —      |

接著仍會問安全做法/兒童承諾：

| 題目                                                            | 答案                               |
| ------------------------------------------------------------- | -------------------------------- |
| Is all data encrypted in transit?                             | N/A（無資料傳輸）/ 依表單預設                |
| Users can request data deletion?                              | **Yes**（解除安裝即刪除全部本機資料）           |
| **Have you committed to the Google Play Families Policy?** 🧸 | **Yes** ← **與一般 App 相反，務必選 Yes** |

> 資料刪除說明欄可填（英文）：
> 
> ```
> This app stores all data only on the device (local SQLite). It makes no
> network requests and collects no data. Uninstalling the app permanently
> deletes all data. No personal information from children is collected,
> and no advertising identifiers, location, or device IDs are transmitted.
> ```

#### 情境 B：若這版**就要含** Google Drive 進度同步（Phase 2，目前尚未實作）

> 只有當你真的在 v1.0 把 `docs/PLAN_billing_sync.md` §3 的同步功能做出來、且會上線，才照這個填。否則用情境 A。

| 題目                                   | 答案                                                                                   |
| ------------------------------------ | ------------------------------------------------------------------------------------ |
| Does your app collect or share data? | **Yes**                                                                              |
| 勾哪些資料類型                              | **Files and docs**（進度快照 JSON 存到家長的 Drive appDataFolder）；不勾任何 Personal info / 位置 / ID |
| Collected or shared?                 | **Collected**（只存到家長自己的 Drive，不分享第三方）                                                 |
| 用途（purpose）                          | 只勾 **App functionality**（備份/還原進度）                                                    |
| 必填或可選                                | **Optional**（家長手動開啟）                                                                 |
| Encrypted in transit                 | **Yes**（Google Drive API 走 HTTPS）                                                    |
| Users can request deletion           | **Yes**（家長可在設定關閉同步、刪除 Drive 內檔案）                                                     |
| **Committed to Families Policy** 🧸  | **Yes**                                                                              |

> 🧸 兒童 App 申報 Drive 同步的重點：**身份用「家長」的 Google 帳號**（不是兒童帳號）、用途=「使用者進度備份」、不分享第三方、可刪除。隱私政策也要對應補上（見附錄 A）。詳見 `docs/PLAN_billing_sync.md` §5。

### 4.7 Financial features / Government / Health 等其他問卷

逐項照實填（本 App 都選「沒有」）：

- **Financial features**：My app doesn't have any financial features（IAP 不算金融功能）→ Save
- **Government apps**：No → Save
- **Health**：No → Save
- 其餘出現的雜項一律「沒有 / No」

---

## 階段 5：填 Main store listing（商店頁面文案 + 圖）⬜

> 在**網站** Play Console 操作。
> 📍 **位置（2026 zh-TW）**：左側選單 **「拓展使用者數量」→「商店發布」→「主要商店資訊」**。

### 5.1 App 基本文案（直接複製貼上）

| 欄位                           | 內容       |
| ---------------------------- | -------- |
| **App name**（≤30 字）          | `寶貝學習樂園` |
| **Short description**（≤80 字） | 見 5.2    |

**Short description（≤80 字，複製貼上）：**

```
專為 3-6 歲設計的中文學習樂園，全程語音導讀，五大領域玩中學，適齡分級又安心。
```

### 5.2 Full description（長描述，≤4000 字，整段複製貼上）

```
🌈 寶貝學習樂園 —— 專為 3 到 6 歲設計的中文啟蒙學習樂園

孩子還不會自己看字，沒關係。
寶貝學習樂園「全程國語語音導讀」，每一題都念給孩子聽，
小手點一點就能玩，爸爸媽媽不用一直在旁邊讀題目。
把螢幕時間，變成真正在「學」的時間。

━━━━━━━━━━━━━━━━━━━━━━━━

🧠 五大領域，玩中學

🗣️ 語文　　認國字、注音、量詞、反義詞、跟我念，打好聽說讀的底子
🔢 邏輯數學　數數、加減、比大小、乘法魔法，數字一點都不可怕
🧩 空間　　形狀配對、拼圖、走迷宮、對稱鏡像，建立空間感
🎵 音樂　　樂器配對、高低快慢、音波記憶，培養音感與專注
🧠 動腦　　找規律、記憶翻牌、找不同、數獨小將，越玩越靈光

近 50 種小遊戲，內容會跟著年齡長大。

━━━━━━━━━━━━━━━━━━━━━━━━

🎚️ 適齡分級 + 適性難度

🐣 3-4 歲、🐤 4-5 歲、🦅 5-6 歲三個年齡段，題目深淺不同。
系統會「看孩子表現自動調整難度」——全對就升級、卡關就降回來，
讓孩子永遠待在「跳一下就搆得到」的甜蜜區，有成就感、不挫折。

━━━━━━━━━━━━━━━━━━━━━━━━

🎁 滿滿獎勵，越學越想學

⭐ 星星：每關表現給 1-3 顆星，還能存進「星星錢包」
🥚 扭蛋：用星星轉扭蛋，蒐集 60 多款可愛玩具圖鑑
🏅 貼紙與成就獎盃：銅、銀、金三階，集滿好有成就感
📅 每日簽到：連續登入有額外星星，養成天天學的好習慣

━━━━━━━━━━━━━━━━━━━━━━━━

👨‍👩‍👧 給爸媽的安心設計

📊 家長學習報告：今天玩多久、近兩週每日時間長條圖、各遊戲表現一覽，
　 哪個遊戲常出錯會自動標記 🚩，孩子的強項弱項一看就懂。
🔒 家長鎖：報告與付費都藏在「家長閘門」（需算一題乘法）後面，
　 孩子點不進去，不會誤觸購買。
👧👦 多個寶貝檔案：一台平板給好幾個孩子用，進度各自獨立。

━━━━━━━━━━━━━━━━━━━━━━━━

🛡️ 隱私與安全（這是兒童 App，我們很認真）

• 完全離線：不需要網路、不需要註冊、不需要登入
• 不蒐集任何個人資料、不要求任何敏感權限
• 沒有廣告、沒有外部連結、沒有第三方追蹤
• 符合 Google Play 家庭政策（Families Policy）

━━━━━━━━━━━━━━━━━━━━━━━━

💎 收費方式（透明、不綁訂閱）

• 免費下載，3-4 歲全部關卡免費玩
• 4-5、5-6 歲每個領域都有免費試玩關
• 想解鎖 4-5、5-6 歲全部關卡 + 完整家長報告，
　 一次買斷 NT$350，「不是訂閱、不會自動扣款」，買一次永久解鎖。
• 購買前需通過家長鎖，孩子不會自己亂買。

把學習變成孩子每天期待的事。
寶貝學習樂園，陪孩子快樂長大。 🌟
```

> ⚠️ 文案提到的「一次買斷 NT$350」**前提是 Billing 已串好且商品已上架**（見「先讀」⚠️ 一）。
> 若 v1.0 先不含付費，請把「💎 收費方式」整段改寫或刪除，避免商店描述與實際功能不符（Google 會比對）。

### 5.3 圖片素材（規格 + 哪些已有 / 要做）

| 欄位                           | 規格                                                        | 狀態 / 怎麼準備                                                                                                                                   |
| ---------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **App icon（商店圖示）**           | **512 x 512 PNG**（32-bit、含 alpha）                         | ⬜ **要做**。源檔已有 `assets/icon/app_icon.png`、`app_icon_foreground.png`（那是 launcher icon），但**商店用的 512x512 要單獨匯出一張**。用源檔縮放/補滿到 512x512 即可（見附錄 B）。 |
| **Feature graphic（主視覺橫幅）**   | **1024 x 500 PNG/JPG**（無 alpha）                           | ⬜ **要做**（見附錄 C 的生圖 prompt）。                                                                                                                 |
| **Phone screenshots（手機截圖）**  | 至少 2 張、建議 **4–8 張**；直式，最短邊 ≥320px、最長邊 ≤3840px、16:9 或 9:16 | ⬜ **要拍/做**（見 5.4）。                                                                                                                          |
| **Tablet screenshots（平板截圖）** | 7" 與 10" 各建議幾張；同上尺寸規則                                     | 🧸 **建議做**：本 App 是**平板 App**（pubspec 描述「平板學習 App」），用平板截圖最能展示真實體驗、也對「兒童/教育類」更專業。                                                             |

> 🧸 **為何兒童 App 建議放平板截圖**：本 App 為平板設計、UI 是 RWD。商店上**平板截圖 + 手機截圖都放**，家長在平板上瀏覽會看到對應預覽，下載轉換更好。至少手機截圖必放（商店硬性要求 2 張起跳）。

### 5.4 截圖清單（要截哪些畫面 + 建議標語）

> 🧸 **政策提醒**：Google 要求截圖**反映真實 App 體驗**，「畫面是 App 裡實際沒有的設計」會被退件。下面每張請對照真實畫面截，或做行銷圖時嚴格照真實 UI。

| #   | 畫面                | 怎麼到                               | 建議標語（疊在圖上）        |
| --- | ----------------- | --------------------------------- | ----------------- |
| 1   | **年齡選擇首頁**        | 開 App 第一頁，三個年齡段 🐣🐤🦅            | **3-6 歲，挑對年齡再開始** |
| 2   | **領域選擇（世界地圖）**    | 選年齡後的五大領域畫面                       | **五大領域，玩中學**      |
| 3   | **遊戲進行中（語音導讀）**   | 進任一遊戲，題目顯示中（建議挑視覺好看的：拼圖/找不同/數數）   | **每一題都念給孩子聽**     |
| 4   | **答對回饋 / 得星**     | 答對的星星動畫瞬間                         | **答對了，給你三顆星 ⭐**   |
| 5   | **扭蛋 / 玩具圖鑑**     | 家長區或獎勵入口 → 扭蛋畫面或玩具收藏              | **轉扭蛋，蒐集可愛玩具**    |
| 6   | **成就 / 貼紙牆**      | 成就獎盃頁                             | **集滿獎盃，超有成就感**    |
| 7   | **家長學習報告儀表板**     | 設定 → 過家長鎖 → 學習報告（含 14 天長條圖、各遊戲表現） | **家長報告，看見孩子的進步**  |
| 8   | **家長鎖 / 付費牆（擇一）** | 設定過鎖畫面，或鎖關卡 + 付費牆                 | **家長鎖，孩子不會亂買**    |

> 建議 1、2、3、4、7 為**必放**（最能說明 App 在做什麼）。
> 疊標語可用 [Photopea](https://www.photopea.com/)（免費網頁版）或 Canva；不疊純截圖也能上架。
> 鎖關卡 / 付費牆截圖只有在「v1.0 含付費」時才放，否則跳過 #8 的付費那半。

### 5.5 商店設定（類別 / 標籤 / 聯絡資訊）

📍 **「拓展使用者數量」→「商店發布」→「商店設定」**：

- **App category（類別）**：`Educational`（教育）—— 若階段 2 選 Game，類別走 **Educational**；若選 App，可選 **Education**
- **Tags（標籤，最多 5）**：幼兒教育、注音、學齡前、認知學習、親子（依 Console 可選標籤挑最接近的）
- **Contact details（聯絡資訊）**：
  - Email：`k120575@gmail.com`
  - Phone：可留空
  - Website：可留空，或填 `https://k120575.github.io/kids-learn-app/`

---

## 階段 6：設定 1 個解鎖 IAP 商品（managed product / 非消耗型）⬜

> 在**網站** Play Console 操作。對應 App 內 `full_unlock_family` 解鎖商品。
> **必須先完成階段 3（上傳 AAB）** 才能進這頁。
> ⚠️ 再次提醒（先讀 ⚠️ 一）：建好商品**只是 Play Console 端**，App 端還要把 `StubGateway` 換成 `PlayBillingGateway` 才能真的賣。

### 6.1 開 In-app products 頁面

📍 **「透過 Google Play 營利」→「產品」→「應用程式內商品」**。

> ⚠️ 沒先把**付款資料/商家帳戶**連結好，「建立商品」按鈕會是**灰色**。先去把商家帳戶（merchant account）設好、審核過，再回來建商品。

### 6.2 建立解鎖商品（只建 1 個，非消耗型）

點 **Create product**，填：

| 欄位                             | 內容                                           |
| ------------------------------ | -------------------------------------------- |
| **Product ID**（建好不能改、大小寫/底線敏感） | `full_unlock_family`                         |
| **Name**（≤70 字）                | 完整版解鎖                                        |
| **Description**（≤200 字）        | 解鎖 4-5、5-6 歲全部關卡，以及完整家長學習報告。一次買斷、非訂閱、不會自動扣款。 |
| **Default price**              | **NT$350**                                   |

> ⚠️ **Product ID 必須一字不差是 `full_unlock_family`**——這對應 `lib/core/entitlement_service.dart` 的 `kFullUnlockSku = 'full_unlock_family'`。拼錯一個字，App 就抓不到商品。
> ⚠️ **這是「非消耗型 managed product」，不是訂閱、不是消耗型**。Play Console 的 in-app product 預設就是 managed product；只要**不**去建 subscription 即可。App 端用 `buyNonConsumable()`。

### 6.3 價格本地化（auto-convert）

商品價格欄旁 **「Set prices for other countries」** → 選 **「Auto-convert prices based on default」**，讓 Google 用匯率自動換算其他國家價格。

### 6.4 設為 Active

商品建好預設 **Inactive** → 點商品 → 右上角 **Activate**。**必須 Active，App 才抓得到。**

### 6.5 設定 License testers（測試購買不扣錢）🧸

> ⚠️ 不做這步，拿自己手機買解鎖會**真的扣 NT$350**。

1. **帳戶層級設定**：回到左上角切「所有應用程式 / All apps」→ **「設定」→「授權測試（License testing）」**（找不到就用選單頂端搜尋框打「授權測試」）
2. **Email addresses** 加 `k120575@gmail.com`（及任何要測購買的帳號）
3. **License response** 選 **`RESPOND_NORMALLY`**
4. **Save**

加完後，這些帳號在內測軌道購買時會顯示「This will not be charged. You are using a test account.」。

> 🧸 **兒童 App 額外注意**：購買流程**前面已有家長鎖**（乘法題 parent gate），符合 Families Policy「避免兒童誤觸購買」。測試時請從 App 內「設定 → 過家長鎖 → 付費牆」走完整流程，確認鎖有擋住、過鎖後才看得到價格。

---

## 階段 7：把自己加進 Internal testing → 實機安裝 + QA ⬜

> 在**網站** Play Console + 用**平板/手機**安裝。

### 7.1 加測試者

📍 **「測試及發布」→「測試」→「內部測試」→「測試人員」分頁**

1. **建立電子郵件名單** → 取名 `寶貝測試組`
2. 貼進 `k120575@gmail.com`（+ 想測的親友帳號）
3. **儲存變更**

### 7.2 拿加入連結

同頁往下捲到 **「測試人員加入測試的方式」** → 複製 **「分享連結」**（像 `https://play.google.com/apps/internaltest/...`）

### 7.3 用平板/手機安裝

1. 確認裝置已用 `k120575@gmail.com` 登入
2. Chrome 開分享連結 → **接受邀請** → **前往 Google Play 下載** → **安裝**

> ⚠️ 第一次推送可能要等 **2–4 小時**才出現在 Play Store，耐心等。

### 7.4 實機 QA 一輪（兒童 App 重點）

| 測試項             | 怎麼測       | 預期                          |
| --------------- | --------- | --------------------------- |
| 開 App           | 點 icon    | 進年齡選擇頁，不黑屏                  |
| 語音導讀            | 進任一遊戲     | 國語語音念出題目（先 baked 語音、缺則 TTS） |
| 玩一關             | 答題        | 對/錯回饋音效、得星、難度自動調整           |
| 離開關卡停語音         | 遊戲中途返回    | 語音立刻停（不會退出後還在念）             |
| 扭蛋/獎勵           | 領星 → 轉扭蛋  | 扣星、抽到玩具、重複退星                |
| 🧸 家長鎖          | 設定 → 學習報告 | 跳乘法題，答對才進得去                 |
| 家長報告            | 過鎖後       | 顯示今天/近兩週時間、長條圖、各遊戲表現        |
| 多寶貝檔案           | 新增第二個孩子   | 進度各自獨立                      |
| 🧸 付費牆擋孩子       | 鎖關卡點下去    | 先語音提示 → 家長鎖 → 過鎖才到付費牆       |
| 購買（若已串 Billing） | 付費牆 → 解鎖  | 跳「測試購買」dialog（不扣錢）、購買後關卡解鎖  |

> ⚠️ 若 App 端**還是 StubGateway**（Billing 未串），付費牆會顯示「暫時無法購買」——這是預期的，代表你還沒做「先讀 ⚠️ 一」的 ②。

---

## 階段 8：封閉測試 12 人 / 14 天 → 申請正式版 → 上架 ⬜

> ⚠️ 整個上架**最耗時、最容易卡死**的關卡。新個人帳號必須先過封測才能碰正式版，內測不算數。**越早開始 14 天時鐘越好。**

### 8.1 建立封閉測試版本

📍 **「測試及發布」→「測試」→「封閉測試」**

1. 進「封閉測試」→ Google 預設有一條軌道 → 點進去 → **建立新版本**
2. **App Bundle** 區塊：沿用已上傳的那包 AAB（「Add from library」選 `1 (1.0.0)`），不用重傳
3. 填繁中版本資訊（同 3.2）→ **下一步 → 儲存**

### 8.2 加 ≥12 位測試人員 + 發加入連結

1. 同頁 **「測試人員」分頁** → **建立電子郵件名單** → 取名 `寶貝封測組`
2. 貼進 **至少 12 個真人 Google 帳號**（每個都要能收信、能在手機點連結加入）
3. **儲存變更** → 往下捲複製 **「分享連結」**
4. 發給這 12 人：**用手機點連結 → 接受邀請 → 從 Play 商店安裝 → 裝著別退出，撐滿 14 天**

> ⚠️ **14 天要「連續」**：測試人員中途退出（opt-out）就重算。請他們裝了就放著別動。
> 💡 湊不滿 12 人：可找「測試互助」社群互換測試（品質參差，自行評估）。

### 8.3 這 14 天同時把上架必填補完（平行作業）

- [ ] 階段 4：應用程式內容全部問卷（**4.5 目標對象勾兒童、4.6 Data safety committed-to-Families = Yes**）
- [ ] 階段 5：主要商店資訊（文案 + **512 icon + 1024x500 feature graphic + ≥2 張截圖**）
- [ ] 階段 6：解鎖 IAP（要等商家帳戶審核過）
- [ ] 階段 7：實機跑完整 QA
- [ ] 附錄 A：隱私政策網頁上線

### 8.4 滿 14 天 + 12 人 → 申請發布正式版

達標後（Dashboard 會顯示已符合資格）：

1. App **「資訊主頁」** → **「申請發布正式版」** 卡片 → 點進去
2. 回答 **3 段問卷**：封閉測試怎麼測的/收到什麼回饋、App 介紹、正式版完備性說明
3. 送出 → Google 審查**約 7 天**

### 8.5 取得正式版權限 → 送上架

📍 **「測試及發布」→「正式版」**

1. **建立新版本** → 從版本庫選那包 AAB → 填繁中版本資訊
2. **下一步 → 確認沒錯誤 → 儲存 → 審查版本 → 開始發布到正式版**

### 8.6 等 App 審核

- App 審核 **1–3 天**（少數到 7 天）→ 通過收 email → 出現在 Play Store。
- 🧸 兒童 App 審核可能較嚴（會看 Families Policy 合規），確保 4.5 / 4.6 填對。

---

## 階段 9（選擇性）：申請進「兒童專區 / Designed for Families」⬜

> **非上架必需**。上面階段 0–8 做完就能正常上架。
> 「Designed for Families」是讓 App 額外出現在 Play 商店「**兒童（Kids）專區**」的計畫，曝光更多，但審查更嚴、要再填一份「主要面向兒童宣告（Primarily Child-Directed Declaration）」。

- 入口：Play Console → **「政策與計畫」→「家庭（Families）」**
- 2026 規定更新：Google 於 2026/04/15 起更新該計畫與「主要面向兒童宣告」規則（禁止虛報目標年齡），給開發者至少 30 天合規期。**加入前再查當下的官方要求**。
- 建議：**第一版先不申請**，正式版上架穩定後再評估要不要進兒童專區。

來源：[Families | Google Play Console](https://play.google.com/console/about/programs/families/)、[Announcements](https://support.google.com/googleplay/android-developer/announcements/13412212?hl=en)

---

## 「你必須做、我（Claude）無法代勞」的後台清單 🛠️

> 這些都要用**你的 Google 帳號**在 Play Console / Google Cloud 後台操作，或本機改密碼/金鑰，我做不了。對應 `docs/PLAN_billing_sync.md` §7。

**本機（程式碼/金鑰）**

- [ ] 階段 0：跑 `keytool` 產 release keystore、建 `key.properties`、改 `build.gradle.kts`、打 AAB、**備份金鑰**
- [ ] （要真的賣才需要）把 `StubGateway` 換成 `PlayBillingGateway`、加 `in_app_purchase` 依賴（程式碼工作，可請我做；但需要你開好 Play Console 商品後才能測）

**Play Console（網站）**

- [ ] 階段 1：註冊開發者帳號 + 身份驗證 + 付 $25
- [ ] 階段 2：建立 App
- [ ] 階段 6：設定商家帳戶（merchant account）並通過審核
- [ ] 階段 6：建立 managed product `full_unlock_family`、NT$350、Activate
- [ ] 階段 6.5：設定 License testing 測試帳號
- [ ] 階段 4.5：目標對象勾兒童 / 4.6 Data safety committed-to-Families = **Yes**
- [ ] 階段 8：封閉測試湊 12 人、連續 14 天、申請正式版

**素材（要你決定/製作）**

- [ ] 512x512 商店圖示、1024x500 feature graphic、手機/平板截圖（附錄 B、C）
- [ ] 隱私政策網頁上線（附錄 A）

**Google Cloud Console（只有「要做 Drive 同步」才需要，目前 Phase 2 規劃中）**

- [ ] 建 OAuth Client（Android）、填 release keystore SHA-1（+ debug SHA-1）
- [ ] OAuth consent screen、加 scope `drive.appdata`、啟用 Drive API

---

## 上架前最後 checklist

| Check                                                      | 對應階段            | 做到了嗎 |
| ---------------------------------------------------------- | --------------- | ---- |
| Release keystore 產出 + `key.properties` + build.gradle 簽署設定 | 階段 0            | ⬜    |
| Keystore **備份到雲端 + 密碼進密碼管理器**                              | 階段 0.5          | ⬜    |
| AAB 用 release keystore 簽過、versionCode=1                    | 階段 0.4          | ⬜    |
| Play 開發者帳號註冊 + 驗證通過                                        | 階段 1            | ⬜    |
| Console 建好 App（zh-TW、Game/Educational、Free）                | 階段 2            | ⬜    |
| AAB 上傳到 Internal testing                                   | 階段 3            | ⬜    |
| 隱私政策 URL 填好（網頁已上線）                                         | 階段 4.1 / 附錄 A   | ⬜    |
| Ads = No ads 🧸                                            | 階段 4.3          | ⬜    |
| 內容分級問卷填完（教育、IAP=Yes）🧸                                     | 階段 4.4          | ⬜    |
| **目標對象勾「Ages 5 and under」、appeal to children = Yes** 🧸🧸  | 階段 4.5          | ⬜    |
| **Data safety 填完、committed-to-Families = Yes** 🧸🧸        | 階段 4.6          | ⬜    |
| App name / 短描述 / 長描述                                       | 階段 5.1-5.2      | ⬜    |
| 512 icon + 1024x500 feature graphic 上傳                     | 階段 5.3 / 附錄 B、C | ⬜    |
| ≥2 張手機截圖（建議再加平板）上傳                                         | 階段 5.4          | ⬜    |
| 解鎖 IAP `full_unlock_family` 建好 + Active（NT$350）            | 階段 6            | ⬜    |
| License testers 加自己                                        | 階段 6.5          | ⬜    |
| （要真的賣）App 端 PlayBillingGateway 串好                          | 先讀 ⚠️ 一         | ⬜    |
| 實機跑完整 QA、家長鎖有擋、語音正常                                        | 階段 7.4          | ⬜    |
| **封閉測試開好 + ≥12 人連續測滿 14 天**                                | 階段 8.1-8.2      | ⬜    |
| **申請發布正式版（3 段問卷）+ 審查通過**                                   | 階段 8.4          | ⬜    |

---

## 常見錯誤排查

| 症狀                                             | 原因                                     | 解法                                                  |
| ---------------------------------------------- | -------------------------------------- | --------------------------------------------------- |
| `flutter build appbundle` 報 keystore not found | `key.properties` 路徑用了反斜線 / 檔案沒放對       | 路徑改正斜線 `/`、確認 `android/key.properties` 存在           |
| 上傳 AAB 被擋「signed with debug key」               | build.gradle 還在用 debug signingConfig   | 回階段 0.3 確認改成 `signingConfigs.getByName("release")`  |
| 上傳 AAB 後 Internal testing 看不到 App              | Google 推送 lag                          | 等 2–4 小時、重開 Play Store / 清快取                        |
| **目標對象沒勾兒童卻用卡通素材被退** 🧸                        | 行銷素材與目標年齡不一致                           | 回階段 4.5 勾 Ages 5 and under（本 App 本來就該勾兒童）           |
| **Data safety 退件**                             | committed-to-Families 沒選 Yes / 申報與實際不符 | 回階段 4.6，本 App 完全離線就照「情境 A」填、Families = Yes          |
| 付費牆按下去「暫時無法購買」                                 | App 端還是 StubGateway，Billing 未串         | 這是預期；要真的賣需完成「先讀 ⚠️ 一」的 ②                            |
| App 內抓不到價格 / 商品                                | Product ID 拼錯 / 沒 Activate / 商家帳戶沒過    | Product ID 必須是 `full_unlock_family`、Activate、商家帳戶審核 |
| 買 IAP 顯示真實價格不是「測試購買」                           | 帳號沒加 License testers / 裝的不是內測版         | 回階段 6.5                                             |
| 一直無法進正式版                                       | 沒滿封測 12 人 / 14 天                       | 這是新個人帳號硬規則，沒有捷徑（階段 8）                               |

---

## 之後要做的事（上架後）

- **追蹤 crash**：Play Console → 品質 → Android vitals（本 App 無第三方 crash SDK，靠 Play 內建）
- **看下載/留存**：Play Console → 數據分析
- **回應評論**：Ratings and reviews（兒童 App 家長很看重回覆，建議每則都回）
- **更新版本**：改 code → `pubspec.yaml` version `+1`（如 `1.0.1+2`）→ 重打 AAB → 上內測 → 推正式版
- **Phase 2**：若要做付費 Billing 真正串接 + Google Drive 同步，照 `docs/PLAN_billing_sync.md`，同步上線時記得回頭更新 Data safety（情境 B）與隱私政策。

---

# 附錄 A：隱私政策網頁（兒童 App 必備，目前還沒有）🧸

Play Console **強制要填隱私政策 URL**。本 App 還沒有，要先架一頁。最省事用 **GitHub Pages**（免費）：

1. 在 GitHub repo（或新 repo）開啟 Settings → Pages，從某分支/資料夾發佈
2. 放一個 `privacy.html`，網址會像 `https://k120575.github.io/kids-learn-app/privacy.html`
3. 把這網址填回階段 4.1

**兒童 App 隱私政策該寫什麼（重點，繁中即可，務必如實）：**

- **我們是誰**：寶貝學習樂園，開發者 Kevin，聯絡 `k120575@gmail.com`
- **適用對象**：本 App 面向 3–6 歲兒童，遵守 Google Play Families Policy 與兒童隱私相關法規（COPPA / GDPR-K 精神）
- **我們蒐集什麼**：**v1.0 完全不蒐集任何個人資料**。所有學習進度只存在裝置本機，不上傳。
- **權限**：不要求網路以外的敏感權限；不存取相機/麥克風/位置/通訊錄。
- **廣告與追蹤**：**無廣告、無第三方分析、無追蹤、不傳輸廣告 ID/裝置 ID**。
- **購買**：App 內有一個一次性解鎖商品，由 Google Play 結帳系統處理；購買前需通過家長閘門。
- **兒童資料**：不向兒童蒐集個資、不要求兒童登入帳號。
- **資料刪除**：解除安裝即永久刪除所有本機資料。
- **（若未來上線 Drive 同步）** 補一段：進度備份使用「家長」的 Google Drive 私有 appDataFolder，僅供備份/還原，不分享第三方，家長可隨時關閉並刪除。
- **政策變更與生效日期**。

> 可參考同作者另一 App 的格式（`https://k120575.github.io/coupon-manager/privacy.html`），改寫成兒童版即可。
> `[⚠️ 需 Kevin 決定最終網址路徑]`

---

# 附錄 B：512x512 商店圖示怎麼做

- **規格**：512 x 512 px、PNG、32-bit、含 alpha。
- **現況**：launcher 圖示源檔已有 `assets/icon/app_icon.png` 與 `assets/icon/app_icon_foreground.png`（adaptive icon 前景 + 背景 `#90CAF9`）。
- **做法（最省事）**：用 `app_icon.png`（已是方形 LOGO）在任何看圖軟體 / Photopea 縮放或補滿到 **正好 512x512**、去背或填滿背景色 `#90CAF9`、匯出 PNG。
- ⚠️ 商店圖示**不要留透明邊造成內容偏小**；內容要佔滿、四角可圓角（Play 會自動套圓角遮罩）。

---

# 附錄 C：1024x500 Feature Graphic 生圖 prompt（含中文）

> **目標**：Play Store 主視覺，**正好 1024 x 500 px**。
> **平台**（依中文渲染力排序）：🟢 Gemini 2.5 / Imagen 4 / Nano Banana、🟢 ChatGPT GPT Image、🟡 Canva AI、🔴 Midjourney/Flux（中文易鬼字，走文末 fallback）。

複製下方整段貼到支援中文渲染的 AI：

```
Generate a premium, joyful Feature Graphic for a children's learning app called
"寶貝學習樂園" (a Traditional Chinese early-learning app for ages 3-6).
EXACT canvas size: 1024 x 500 pixels, landscape composition.

═══════════ OVERALL MOOD ═══════════
Bright, warm, friendly, playful — like a premium preschool educational brand
(think Khan Academy Kids / Sago Mini quality). Soft rounded shapes, gentle
gradients, plenty of air. Background: a soft sky-blue to cream gradient
(#90CAF9 fading to #FFF8E1), with a few simple flat clouds and a subtle rainbow arc.
NOT cluttered, NOT neon, NOT dark.

═══════════ LEFT 55% — Brand Statement ═══════════
Traditional Chinese text, accurate characters, left-aligned with margin:

1. MAIN HEADLINE (large, very bold, deep navy #1A3C6E, ~64pt), two lines:
   寶貝學習樂園
2. SUBTITLE (medium, #4A6FA5, ~22pt, below headline):
   3-6 歲 · 玩中學 · 全語音導讀
3. A short row of five small rounded pastel icons representing the five domains,
   each a different soft color, with a tiny emoji-style glyph:
   🗣️ language, 🔢 numbers, 🧩 puzzle, 🎵 music, 🧠 brain.

═══════════ RIGHT 45% — Friendly Mascots ═══════════
Three cute, simple, rounded cartoon baby animals (a chick 🐣, a duckling 🐤,
and a little eagle/owl 🦅 — matching the app's three age mascots), smiling,
sitting among soft building blocks, stars, and a gift/capsule-toy (扭蛋) element.
Flat vector style, thick soft outlines, cheerful primary-pastel palette.
NO human faces, NO real children.

═══════════ DESIGN LANGUAGE ═══════════
Flat modern vector illustration, rounded corners everywhere, soft drop shadows,
warm and safe feeling. Colors: sky blue #90CAF9, cream #FFF8E1, sunny yellow
#FFD54F, coral #FF8A80, mint #A5D6A7, navy text #1A3C6E.

═══════════ CRITICAL ═══════════
✓ ALL Chinese text MUST be accurate Traditional Chinese (繁體中文 for Taiwan),
  NOT Simplified, NOT gibberish.
✓ Headline「寶貝學習樂園」must be clearly legible.
✓ Aspect ratio exactly 1024:500, output 1024 x 500 PNG, sRGB.
✗ NO real photos, NO human faces/children/hands, NO real-brand logos.
✗ NO Simplified Chinese, NO watermarks, NO call-to-action buttons,
  NO star ratings, NO "free" labels, NO app-store badges.
✗ Background MUST stay bright (NOT dark, NOT black).

請確保所有中文字為繁體中文且筆畫精確正確，標題「寶貝學習樂園」必須清晰可讀。
```

**Fallback（中文出鬼字時，Midjourney/Flux）**：把上面所有中文片段刪掉、改要求「completely empty of text, leave space for text」出純插畫底圖，再用 Canva/Figma 手動疊字。字型用 **Noto Sans TC / 思源黑體 Heavy**；標題 #1A3C6E、副標 #4A6FA5。Midjourney 結尾加 `--ar 1024:500 --v 7 --style raw`。

**出圖驗收**：尺寸正好 1024x500、每個中文字正確（繁體不亂碼）、標題清晰、整體明亮可愛、無真人臉、縮到 200px 寬仍看得懂。

---

## 我查證過的官方規定（來源）

- [App testing requirements for new personal developer accounts（封測 12 人/14 天）](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Manage target audience and app content settings（目標年齡層選項、含兒童即觸發 Families）](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en)
- [Google Play Families Policies（內容/廣告/購買家長閘門/SDK/兒童資料）](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)
- [Families Self-Certified Ads SDK Policy（兒童廣告須自我認證）](https://support.google.com/googleplay/android-developer/answer/12918983?hl=en)
- [Content rating requirements（IARC 內容分級）](https://support.google.com/googleplay/android-developer/answer/9859655?hl=en)
- [Families | Google Play Console（Designed for Families 計畫）](https://play.google.com/console/about/programs/families/)
- [Play Console Announcements（2026/04/15 起 DFF / 主要面向兒童宣告更新）](https://support.google.com/googleplay/android-developer/announcements/13412212?hl=en)
- [Purchase approvals on Google Play / Families（家長購買核准）](https://support.google.com/families/answer/7039872?hl=en)
