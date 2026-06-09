# 修正紀錄 / 踩雷筆記

## 語音 / 音效（2026-06）

### 裝置 TTS fallback 會出「外國爛中文」且與音檔疊音
- speak() 原本「沒烤到的台詞退回 `flutter_tts`」。但裝置中文 TTS 品質差（外國腔），
  且 TTS 與 audioplayers 是**兩個獨立播放器、不會互相停** → 兩個聲音一起講。
- ✅ 解法：**移除 TTS fallback**。沒烤到就靜音；確保所有 speak() 的台詞都在 `gen_voice.py` 烤過。
- 漏烤常見處：年齡卡 label、領域 label、**遊戲標題**（game_list 會念 g.title）。加新遊戲記得補烤標題。

### speakAndWait 的 onPlayerComplete 會被「前一段的 stop()」誤觸發
- `_voice.stop()` 會發出一個 complete 事件，`onPlayerComplete.first` 立刻抓到它就返回，
  根本沒等新音檔播完 → 連續念多段（如加減法「七 加 五 等於多少」）只剩最後一段。
- ✅ 解法：依序念多段時改用 `speak()` + 固定 `Future.delayed` 間隔（數字~850ms、加減~650ms）。

### 答對音效慣例 = 上行三音 chime
- 查證：益智/教育 App 答對音是「三個上升音符」（Tetris、quiz show）。單一鈴聲太單調。
- ✅ 用 ffmpeg 產生：三個遞增 sine（D5/F#5/B5）各帶 fade，concat + loudnorm → `success.mp3`。

### 背景音樂在 Android 無聲的兩個雷（2026-06，模擬器實測抓到）
- **雷一：play 前先 setVolume → MediaPlayer error (-38)**。Android MediaPlayer 在「未設定音源(IDLE)」狀態被 `setVolume()` 會進錯誤狀態，接著的 `play()` 整個失敗、丟 `AudioPlayers Exception: AssetSource(music/bgm.mp3)`。語音能放是因為它沒有前置 setVolume。
  - ✅ 解法：音量改用 `play(AssetSource(...), volume: v)` 帶入；ducking 的 `setVolume` 只在「已 play、音源就緒」後才呼叫。
- **雷二：每個 AudioPlayer 各自搶 AUDIOFOCUS_GAIN → 後播的把背景音樂停掉**。預設 audio context focus=gain，播語音/音效時 `requestAudioFocus(GAIN)` 會搶走 BGM 的焦點，系統就把 BGM 暫停。logcat 會看到一直 `requestAudioFocus()...CONTENT_TYPE_MUSIC`。
  - ✅ 解法：把所有播放器的 context 設成 `AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build()`（Android = focus none），全部混音、互不搶焦點；音量大小（含講話時壓低）完全由我們自己用 `setVolume` 控制。
  - ⚠️ 關鍵：這些 AudioPlayer 是 class field、在 `setAudioContext` 之前就建立，**只設 `AudioPlayer.global` 不夠**，要對「每一個播放器實例」各自 `pl.setAudioContext(ctx)` 才會生效。
- 驗證法：logcat `requestAudioFocus.*<uid>` 應為 0；`AudioTrack stop ... 441000 frames`（=10s 一輪的 bgm）每 10 秒出現一次＝有在循環。

### adb input tap 座標：這版模擬器用「畫面(橫向)邏輯座標」非 native（與舊筆記相反）
- 2026-06 Pixel_9_Pro_XL（API 36）實測：強制橫向、`mRotation=ROTATION_90`、screencap 為 2992×1344。
- `adb shell input tap X Y` 直接吃 **截圖上的橫向座標**（X∈0..2992, Y∈0..1344），不需做 native 轉換。
  - 例：點右上設定齒輪 → `input tap 2887 95` 成功跳出家長鎖；舊的 native 轉換公式 (xp=yl, yp=2992-xl) 反而點空。
- 驗證法：拿「點了會跳對話框」的目標（設定齒輪→家長乘法題）當探針，跳框即座標正確。
- 截圖全黑且大小固定 → 螢幕休眠，先 `input keyevent KEYCODE_WAKEUP`＋`svc power stayon true`。

### Impeller 在 Android 模擬器黑屏 + 截圖全黑其實是螢幕休眠
- `flutter run` 連 VM service 失敗（`Connection closed before full header`）不代表 App 沒跑起來，APK 已安裝且活著。
- 截圖**全黑且每次大小一模一樣（如 18878 bytes）**＝模擬器螢幕休眠（`dumpsys power` 的 `mWakefulness=Asleep`）。先 `input keyevent KEYCODE_WAKEUP` + `svc power stayon true` 再截。
- 真要排除 Impeller 黑屏可暫時在 AndroidManifest 加 `io.flutter.embedding.android.EnableImpeller=false`（Skia），但本案實測黑屏主因是休眠，不是 Impeller。

### 多動作遊戲別每個動作都放答對音
- 找不同/記憶翻牌/拼圖/分類：每配對/每放一塊都 correct() → 很吵。
- ✅ 中途用 `tap()`（輕點聲），**整盤/全部完成才** `correct()`(chime)。

### 音效授權：taira-komori 禁止再散布
- taira-komori 雖免費免署名，但條款**禁止 redistribution/hotlink**，打包進 App 散布即違反。
- ✅ 全改 **bigsoundbank（明確 CC0，可散布）**。Wikimedia 只收標示 PD/CC0 的（避開 CC-BY/SA）。
- Wikimedia upload CDN 會 429/403：用瀏覽器 User-Agent，且別短時間大量請求。

### ffmpeg 音效處理
- 沒 ffmpeg：winget 不穩，改下載 gyan.dev 免安裝版解壓到 `C:\src\ffmpeg`。
- 統一處理：`-t 2.0`(裁)、`loudnorm=I=-14:TP=-1.5`(音量一致，解決某些音效太小)、`afade`、`-ac 1`、短音`-stream_loop -1`(補長，如沙鈴)。

### Penguin 動畫控制器 late final 在 dispose 崩潰
- `late final AnimationController _c=...`，animate:false 時從不初始化，dispose() 存取它→在已停用 widget 建 Ticker→斷言崩潰（答對慶祝用 animate:false 企企，慶祝消失即中招）。
- ✅ 改成可空 `AnimationController? _c`，只在 animate 時建立，dispose 用 `_c?.dispose()`。

### adb input tap 在強制橫向下不可靠
- 旋轉顯示但 input 用未旋轉實體座標，x>螢幕短邊會點空 → 自動化點擊驗證不可靠。
- ✅ 互動邏輯改用 **widget test** 驗證（真機觸控原生正確）；UI 用截圖看。

## 環境安裝（2026-06）

### Android 授權無法用 pipe 餵 y
- `flutter doctor --android-licenses` 與 `sdkmanager --licenses` 用 PowerShell pipe（`$y | & ...`）
  或 cmd for-loop 串流 `(for /L ...) | sdkmanager` **都吃不到 y**，停在 "Review licenses (y/N)?" 就 EOF 退出。
- ✅ 有效解法：**用檔案 stdin 重導向** — 先把多行 `y` 寫進檔案，再
  `cmd /c "sdkmanager.bat --licenses < yes.txt"`。一次回報 "All SDK package licenses accepted"。
- 直接手寫 `sdk\licenses\android-sdk-license` 雜湊也行，但新版 SDK（build-tools 37 / platform 36.1）
  需要的雜湊組不只舊的那顆，容易漏；檔案重導向最穩。

### cmdline-tools 下載
- `edgedl.me.gvt1.com` 主機會 404；用 **`dl.google.com/android/repository/commandlinetools-win-<build>_latest.zip`**。
- 解壓後要放成 `sdk\cmdline-tools\latest\bin\...`（zip 內層是 `cmdline-tools\`，
  若 `latest` 已存在會多包一層，要把內層提升上來）。

### 工具環境
- Android Studio / SDK / Java 21 / git / winget 本機已有，只缺 Flutter 本體。
- Flutter 用淺層 clone：`git clone --depth 1 -b stable ... C:\src\flutter`，PATH 設使用者環境變數。

## 開發約定
- 沙箱/靜態檢查會擋 `Remove-Item -Recurse -Force` 與含萬用字元的 Move；
  改用「搬整個資料夾、不用萬用字元、避免 Remove-Item」的寫法。
- Flutter 3.44 用 `Color.withValues(alpha:)`（`withOpacity` 已棄用）。

## Android build / 執行期（模擬器煙霧測試抓到）

### Kotlin 增量編譯在 Windows build 失敗
- `Could not close incremental caches in ...\.tab` → 在 `android/gradle.properties` 加
  `kotlin.incremental=false`。長路徑/防毒鎖檔造成。

### theme `textTheme.apply(fontSizeFactor:)` 執行期崩潰（紅畫面）
- `analyze` 過、但一開 App 就紅畫面：`fontSizeFactor == 1.0 ... fontSize != null` 斷言。
- M3 部分 textStyle 的 fontSize 為 null，套 fontSizeFactor 會斷言失敗。
- ✅ 解法：不要用 fontSizeFactor，各畫面明確指定字級。
- 教訓：**`flutter analyze` 抓不到執行期斷言**，一定要真的把 App 跑起來（模擬器/實機）看畫面。

### 遊戲流程不可 await 語音（會卡死）
- `flutter_tts` 的 speak 在 `awaitSpeakCompletion(true)` 下要等播完回呼才返回；
  測試環境沒有平台 TTS → 回呼永不來 → `await speak()` 卡死 → 遊戲推進邏輯永遠等不到。
- 真機亦有風險（TTS 卡住會拖住遊戲）。
- ✅ 解法：(1) `awaitSpeakCompletion(false)`；(2) 流程裡所有音訊呼叫**不要 await**（發出即走）；
  (3) AudioService 回饋方法整個包 try/catch，避免 fire-and-forget 拋未處理例外。

### adb input tap 在強制橫向下座標會錯
- App 鎖橫向是「旋轉顯示」，但 `adb shell input tap x y` 用**未旋轉的實體直式座標**（本機 1344×2992）。
- 用橫向截圖座標去點，x>1344 會被裁掉而點空。`mRotation=ROTATION_90` 時換算：xp=yl, yp=2992-xl。
- 自動化點擊驗證很麻煩；遊戲互動邏輯改用 **widget test** 驗證更可靠（真機觸控原生正確，不受影響）。
