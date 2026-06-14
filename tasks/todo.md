# 寶貝學習樂園 — 進度與 TODO

幼兒多元能力練習 App（Flutter / Android 平板 / 全離線 / 橫向）。
規格：`C:\Users\k1205\.claude\plans\abundant-honking-waffle.md`

## 環境
- Flutter 3.44.1 在 `C:\src\flutter`（已加 PATH）
- ffmpeg 在 `C:\src\ffmpeg\ffmpeg-8.1.1-essentials_build\bin\ffmpeg.exe`（裁音效、產生音階）
- edge-tts（python，已裝）：烤語音 `tool/gen_voice.py`
- 模擬器：Pixel_9_Pro_XL（adb 部署測試）
- Windows build 需 `android/gradle.properties` 的 `kotlin.incremental=false`

## 語音 / 音效（重要）
- **語音**：edge-tts `zh-TW-HsiaoChenNeural`，rate **-3%**、pitch **+30Hz**（年輕活潑）。
  - 烤成 `assets/voice/<md5(台詞)前16>.mp3`，雜湊集合在 `lib/content/voice_manifest.dart`。
  - **已移除裝置 TTS fallback**：沒烤到的台詞就「靜音」，絕不用裝置 TTS（會是外國爛中文且會疊音）。
  - 新增台詞 → 改 `gen_voice.py` 的 LINES/VOCAB → 跑 `python tool/gen_voice.py` 重烤。
- **音效 SFX**：全 **bigsoundbank CC0**（taira-komori 因禁止再散布已全部移除）。在 `assets/sfx/`。
  - 動物 18 種、樂器 5 種、`snare`(節奏鼓)、`success.mp3`(=ffmpeg 產生的**上行三音 chime**，答對音)。
- 三個獨立播放器：語音 / 題目音效 / 節奏鼓 / 歡呼，避免互相切斷。
- 多動作遊戲（找不同/記憶翻牌/拼拼圖/分類）：中途只輕點聲，**完成才放 chime**。

## 已完成

### 3-4 歲（10 個遊戲，全部 50 題庫/隨機版面）
- 語文：聽音指圖(50詞)、聲音尋寶(18 真實動物聲)
- 邏輯數學：數數點點(50)、顏色分類(隨機3回合)
- 空間：形狀配對、拼拼圖、走迷宮(9關抽5)
- 音樂：樂器配對(真實樂器聲)、節奏跟打(隨機2-4拍、不重複)
- 進階分類（顏色×形狀，3-4 與 5-6 共用）

### 5-6 歲（13 個遊戲；難度朝資優拉高）
- 語文：聽音指圖(進階50詞)、找不同類(odd-one-out)、反義詞
- 邏輯數學：加減法(20以內、**會念整題**)、比大小、進階分類
- 空間：走迷宮(硬，9×9 程序產生含死巷)、形狀配對、拼拼圖
- 音樂：樂器配對
- 🧠 動腦(新領域)：記憶翻牌、找不同(放大+多差異)、找規律(瑞文式)

### 系統
- 年齡段可選(3-4 / 5-6 開放；7-8 未開)、領域依齡過濾、SQLite 進度、貼紙簿、家長鎖、企企吉祥物(向量自繪)、答對慶祝(星星+企企)、橫向、全離線。
- `flutter analyze` 零問題、`flutter test` 全過。

### 家長/幼教強化（2026-06，家長+幼教 P0+P1）
- **背景音樂**：`tool/gen_bgm.py`（純 stdlib 合成五聲音階音樂盒循環 → ffmpeg）→ `assets/music/bgm.mp3`。
  - **Ducking**：`AudioService` 監聽語音/題目音效/鼓聲播放器狀態，講話時把 BGM 壓到 25%，講完延遲 350ms 恢復（避免兩段語音間抖動）。設定可開關 + 調音量。
- **休息提醒（真的會動）**：`core/screen_time.dart` `ScreenTimeManager`（WidgetsBindingObserver + Timer），只在前景累計使用秒數、寫進 `daily_time`，達設定分鐘數→企企跳出休息提醒並可回首頁。（舊版只存設定、從不觸發。）
- **家長鎖強化**：改成「兩位數×個位數」乘法（比 App 內 20 以內加減更難，5-6 歲也解不開）。
- **分級星星**：`finishGame(..., mistakes:)`→全對 3⭐ / 錯1~2 給2⭐ / 錯≥3 給1⭐（永不 0）。11 個遊戲已接錯誤計數（迷宮/數數/節奏無對錯→3⭐）。
- **適性難度**：`ProgressStore.levelFor/recordOutcome`（0~2，全對升、錯多降，每孩子每遊戲存 `difficulty` 表）。已接：聽圖選項數、數數量範圍、加減上限、比大小數量、記憶配對數、找不同差異數、找規律單位/長度、節奏拍數。
- **家長報告**：`screens/dashboard_screen.dart`（設定→學習報告）：今天/近兩週時間、遊玩次數、各遊戲次數/最佳星/累計錯誤、🚩常錯標記。資料表 `plays` + `daily_time`。
- **多孩子檔案**：`profiles` 表 + 每孩子分流 stars/stickers/plays/daily_time/difficulty。首頁可快速切換、設定→孩子檔案（家長鎖）可新增/改名/刪除。DB v1→v2 有 onUpgrade 遷移（舊資料歸 default 孩子）。
- **幼教內容**：`content/literacy_levels.dart` + 新遊戲：認國字(26 常見字, 聽詞點字)、注音開頭(音韻覺識, 聽詞辨聲母)、跟我念(親子共學短語, `games/read_aloud_game.dart`, 3-4 與 5-6 各一組)。
- 新台詞已加進 `gen_voice.py` 並重烤（+69 句，共 252 句）。

> ⚠️ DB 遷移與 BGM ducking 只在真機/模擬器才跑得到（`flutter test` 用記憶體後備、不碰 sqflite）。建議部署模擬器煙霧測試一次。

### 主題化 + 獎勵系統大改造（2026-06）
- **背景音樂改版**：`tool/gen_bgm.py` 重寫成「木琴主旋律＋彈跳貝斯＋鼓組(大鼓/拍手/hi-hat)」的 C 大調 120 BPM 歡樂兒歌（16s 循環）。舊版是慢速五聲音階單音（被嫌中國風又單調）。若要真人曲：Pixabay（CC0、免署名、可商用）下載後直接覆蓋 `assets/music/bgm.mp3` 重打包即可。
- **分齡主題探索地圖**：`content/themes.dart`。3-4=🎡歡樂遊樂園（領域→設施：故事屋/數字摩天輪/積木城堡/音樂馬戲團/鏡子迷宮）、5-6=🚀太空探險（領域→星球：文字星/數學星/積木星/音波星/謎題星）。`domain_select` 改成地圖：玩過的站點亮燈顯示⭐數、全 3 星亮✅。
- **星星變貨幣**：每場依表現賺 1-3 ⭐進「星星罐」(`wallet`)，可累積、可花用（不再只給家長看）。`ProgressStore.balance/earnedTotal/addEarnedStars/spendStars/refundStars`。
- **扭蛋機**：`core/rewards.dart` `drawGacha()`，花 15⭐ 抽玩具（`content/toys.dart` 32 個、分普通/稀有/傳說 70/25/5 權重），重複退 5⭐。`screens/gacha_screen.dart` + 收藏室圖鑑 `collection_screen.dart`（取代舊貼紙簿）。
- **成就獎盃**：`content/achievements.dart` 5 個成就×銅/銀/金（探索家/完美高手/星星收集家/玩具收藏家/天天來玩）。`evaluateAchievements()` 每場結束評估、新解鎖在慶祝框揭曉。`screens/trophy_screen.dart` 獎盃櫃顯示等級與進度條。
- **連續天數**：`dailyCheckIn()`（main 開場呼叫），連續天數＋每日 5⭐（滿 7 天倍數再 +10），首頁 SnackBar 顯示歡迎獎勵、🔥N 連續天數。
- **慶祝框改版**：`completion.dart` 顯示賺到的⭐、星星罐總額、新解鎖獎盃（取代舊貼紙揭曉）。舊自動貼紙機制已退役（`stickers` 表保留供遷移，sticker_book 不再使用）。
- **DB v3**：新增 `wallet/toys/achievements/streak` 表，v2→v3 遷移把現有星星總和轉成起始餘額。
- 測試：新增 `rewards_test.dart`（錢包/扭蛋/成就/簽到）。`analyze` 零問題、全部測試通過。模擬器實測遷移無誤、新首頁正常。

### 沉浸式主題地圖 + 音樂加長 + 修扭蛋溢出（2026-06）
- **沉浸式動畫背景**：`core/widgets/park_background.dart`（遊樂園：藍天/太陽/飄雲/綠丘/旋轉摩天輪/馬戲團帳篷/上升氣球）、`space_background.dart`（太空：漸層星空/閃爍星/月亮/土星環/星球/飛行火箭），皆 CustomPainter＋AnimationController。`theme_background.dart` 依年齡段選背景。`GameScaffold` 新增 `backgroundWidget`＋`foregroundColor`（深色主題標題轉白）。`domain_select`/`game_list` 套用；站點卡片改白底（`BigCard` 加 `solid`，深色背景上仍清楚）。模擬器實測兩張地圖渲染漂亮。
- **背景音樂加長**：`gen_bgm.py` 從 8 小節/16s → **16 小節/32s**，加入對比 B 段（vi–IV–I–V、較高音域），單次更長、更不重複。
- **修扭蛋結果溢出**（黃黑警戒線）：`gacha_screen` 結果區 SizedBox 放大到 230×250＋`FittedBox(scaleDown)`＋emoji 縮小，結構上不再溢出。
- 新增 `map_test.dart` 驗證兩張動畫地圖能建構繪製不丟例外。模擬器額外驗證：家長乘法鎖（13×5）、學習報告（時間/🚩常錯）皆正常。
- 註：此模擬器 `adb input tap` 用「畫面(橫向)座標」非 native（與舊筆記相反，新版 emulator 行為）。

### 客製插畫地圖（2026-06）—— 用 AI 生圖取代手繪向量
- 起因：向量 CustomPainter 場景被嫌「像 30 年前 HTML、陽春」。改用**童書插畫圖**當場景背景＋關卡入口。
- 生圖工具：`tool/gen_art.py`，用 **Gemini `gemini-2.5-flash-image`（Nano Banana）** 經 generateContent 出圖（Imagen 需付費方案、且當時 503/429 不穩）。金鑰讀 `tool/secrets.env`（**已 gitignore，用完即刪**）。產完用 ffmpeg 縮圖：tile→512²、bg→1280×720 cover。
- 產出 `assets/images/`：10 張圓形徽章關卡入口（storyhouse/ferris/castle/circus/mirror；planet_word/math/block/music/puzzle）＋ 2 張場景背景（park_bg/space_bg）。約 3.6MB。
- 接線：`themes.dart` 的 `Station.image` / `WorldTheme.bg` 帶檔名鍵；`theme_background.dart` 改用 `Image.asset(cover)`（缺圖 errorBuilder 退回原向量動畫背景）；`domain_select` 站點改成 `ClipOval(Image.asset)` 圓形插畫入口＋白底名稱條＋亮燈徽章（缺圖退回 emoji 圓牌）。`game_list` 沿用同背景。
- 模擬器實測：遊樂園/太空兩張地圖渲染漂亮，關卡入口為插畫徽章。
- ⚠️ 重生或新增圖：`tool/secrets.env` 放回 `GEMINI_API_KEY=...` → `python tool/gen_art.py`（`--force` 全部重生）。要換真人/自繪圖，直接覆蓋 `assets/images/<key>.png` 同名檔即可。
- 金鑰用完即刪（`tool/secrets.env` 已 gitignore + 刪除）。

### 體驗修正第二輪（2026-06）
1. **收藏/獎盃加量**：玩具 32→**65**（`toys.dart`）、成就 5→**7**（新增 遊戲達人/傳說獵人，新指標 `gamesPlayed`/`legendaryToys`；星星收集家上限拉到 500、玩具收藏家 10/30/60）。
2. **休息提醒真的會結束**：按「好，結束休息」改為 `SystemNavigator.pop()` 關閉 App（不再只回首頁還能繼續玩）。
3. **答對音重做**：`tool/gen_sfx.py` 合成「上行大三和弦琶音＋和弦收尾＋高音閃爍」鈴聲（含殘響、立體聲、1.35s），覆蓋 `assets/sfx/success.mp3`，取代原單音三聲 chime。
4. **找規律「？」置中**：hidden 格改用 `Icon(Icons.help_rounded)`（emoji 與文字基線不同會視覺偏移）。
5. **節奏跟打不再疊聲**：`_playDemo` 改成 `speak` ＋固定 1800ms 等待才示範（`speakAndWait` 的完成事件會提早返回導致鼓聲與語音重疊）。

### 體驗修正第三輪（2026-06）
1. **節奏示範時間（再修）**：實測「聽聽看，這樣拍」語音長 **2.69s**，原本只等 1.8s 仍疊聲。新增 `AudioService.speakForDuration()`：用 `setSource`+`getDuration` 取**實際語音長度**動態等待（+0.6s 緩衝），取不到時 fallback 2.8s。節奏示範改用它，徹底不疊聲。
2. **獎勵畫面主題背景**：新增 `core/widgets/reward_background.dart`（暖色漸層＋淡星星/彩帶），扭蛋機/收藏室/獎盃櫃皆套用。
3. **獎盃再加量**：7 → **12** 個（新增 稀有收藏家/星星大富翁/完美大師/毅力之星/圖鑑之王，新指標 `rareToys`）。玩具維持 65。模擬器實測收藏室顯示「1 / 65」、背景已主題化。

### 5-6 歲魔法學院插畫補齊（2026-06）
- 起因：3-4(遊樂園)、4-5(太空)兩段已有 AI 童書插畫地圖，但 **5-6 歲(`age5_6`)= 🪄 魔法學院**的 `magic_bg` + 5 站徽章從沒產，UI 一直退回 emoji。
- 用 `tool/gen_art.py`（同一組 `STYLE`＋`TILE_FRAME`，畫風自動與前兩段一致）新增 6 筆並產出：場景 `magic_bg`（巫師城堡、暮光紫金天空、燈籠/亮粉）＋ 5 個圓形徽章 `magic_spell`(咒語書)/`magic_alchemy`(鍊金藥水)/`magic_circle`(魔法陣)/`magic_sound`(金號角)/`magic_tower`(智慧之塔)。色系走暮光紫＋暖金＋sparkles，自成一套又同調。
- 不加 `--force` → **只產缺的 6 張，現有 12 張(遊樂園+太空)沒動**，金鑰只用 6 次呼叫；產完即從 `tool/secrets.env` 刪鑰。
- 程式端零改動：`themes.dart`/`worldBackground`/`domain_select` 的 `ClipOval` 入口本來就接好（`age5_6` 已有 `magic_*` 鍵與 `MagicBackground()` 向量退路），圖到位即自動顯示。alchemy 原圖黑角經 `ClipOval` 裁掉後露出暖金圓盤，毫不突兀。
- 模擬器實測：5-6 → 魔法學院地圖背景＋5 站徽章渲染漂亮、與前兩段一致。三段世界齊全：🎡遊樂園 / 🚀太空 / 🪄魔法學院。

### 動腦/空間補洞 + 適齡校正 + 什麼不見了記憶引導（2026-06-12）
- **補洞（各領域<3 遊戲的格子）**：
  - 3-4「動腦」本來**完全空（0 個）** → 新增 3 個**全新**遊戲（非難度變體，是三種不同認知動作）：
    - `find_same_game.dart` **找一樣**（感知辨識：看目標→點一樣的）
    - `whats_missing_game.dart` **什麼不見了**（Kim's game，短期工作記憶）
    - `next_in_row_game.dart` **接下去**（AB/AABB/ABC 重複規律延續）
  - 5-6「空間」2→3：`rotate_match_game.dart` **轉轉看**（心像旋轉；手性 polyomino，鏡像當干擾；**執行期驗證手性**確保不會「兩個選項都對」）。
- **找不同(4-5)** 差異處 `numDiff` 2→3：適性階梯原本 2/2/4（中間太平）→ **2/3/4**。
- **適齡校正（依發展研究查證，非憑感覺）**：
  - 什麼不見了：場上物件預設 4→**3**（3-4 歲工作記憶 span≈2-3），退階 2、挑戰 4、移除 5。
  - 轉轉看：預設只用 **4 格 tetromino**；5 格 pentomino＋鏡像是 MR 最難變體，只放「挑戰」階（連續全對才爬到）。依據：5-6 心像旋轉準確率仍低、個別差異大。
- **什麼不見了 記憶引導**（解決「顯示太短、3-4 記不住」）：
  - 記憶階段**逐一高亮＋念出每個物件**（替孩子做語音標記，對抗 3-4「production deficiency」＝不會自己默念）。
  - 開場句改用 `speakForDuration` 等實際音檔播完才念下一句（修「尾字被切」——固定延遲猜長度會被切）。
  - 右上喇叭＝**「再看一次」**：重播整段記憶序列，**不限次數**，`_showing` 旗標防重入。
- 語音：新增 27 個物件名 + 9 句指示/標題，重烤共 **641 句**。
- 測試：新增 `test/new_games_test.dart`（5 測試：4 遊戲建構/運行 + 重播鈕）。`analyze` 零問題、全測試通過、**Pixel Tablet** 模擬器實測 4 遊戲與重播皆正常。
- 註：本輪用 **Pixel_Tablet**(2560×1600 原生橫向、API 35) 部署，`adb input tap` 直接吃橫向座標、無需旋轉換算。

### 音樂域補完（2026-06-14）—— 每段 +2，依發展研究排序
- 起因：每年齡段音樂原本只有 1 個（音色：樂器配對 / 音波記憶）。補互補能力到各 3 個。
- **依發展研究修正了原排序**（research agent 查證 Trehub/Bobin-Bègue/Feinstein/Stalinski/Trainor 等）：
  原 todo 把「大聲小聲」放 3-4、「快快慢慢」放 4-5；但**速度辨識 3-4 就可靠、力度標記要 5-6 才可靠** →
  把兩者對調。音高方向/走音確認是 5-6 技能。最終：
  - **3-4**：`快快慢慢`(速度) + `高高低低`(音高，限大音程約兩個八度，🐦上/🐘下縱向)
  - **4-5**：`大聲小聲`(力度) + `音的長短`(時值 ta/ti-ti，辨識非跟拍)
  - **5-6**：`音往哪裡走`(音高方向上行/下行，⬆️/⬇️縱向) + `哪個音不對`(熟悉曲走音，一音升三全音)
- 共用引擎 **`lib/games/listen_choose_game.dart`**（聽一段音→點固定屬性卡，含一次性開場引導、
  沿用 PickGame 的音訊時序/慶祝/重播/分級星星）。題庫在 `content/music_levels.dart`、註冊在 registry。
- 音效管線 **`tool/gen_tones.py`**（ffmpeg + numpy → `assets/sfx/tone_*.mp3`、`melody_*.mp3`）。
  ⚠️ **大聲小聲那組不可做 loudnorm**（音量本身是答案），且 loud/soft 整組共用同一縮放係數才保得住相對響度。
- 語音：標題 + 引導 + 4 首歌名都已加進 `gen_voice.py` 並重烤（共 657 句）。標題用字經查證**已全在 lib/subset 內、不需重跑字型**。
- 測試 `test/music_games_test.dart`（7 測試）通過、`analyze` 零問題、全套 26 測試過。

### 後續修正（2026-06-15）
- **離開關卡語音續播 bug（全關卡）**：退出後語音會「念到結束」。修法：`speakAfterVoice` 用 epoch 自我取消（13 關零改動）＋ pick_game/listen_choose/whats_missing/sound_memory/arithmetic/multiplication/read_aloud 在 `await waitUntilVoiceIdle()` 後加 `if(!mounted)return`。見記憶 [[audio-stop-on-exit]]。
- **標題渲染錯位（全頁）**：BrandTitle 雙層 Text 描邊被 Impeller 算錯位。改單一 Text + 8 向硬陰影。見 [[title-outline-single-text]]。
- **RWD 全面稽核**：37 檔的寫死字級/圖示/長寬/間距改 `context.s`（圓角/邊框/陰影維持裝飾性不縮放）；共用 widget 在呼叫點縮放、StarsRow 內部自縮放；rotate_match 包 scroll 防溢出。見 [[rwd-no-hardcoded-sizes]]。
- **這首對嗎**（原「哪個音不對」改名，名實相符：整首對不對的二選一）：每題先**念出+顯示歌名**（小星星/兩隻老虎/小蜜蜂/生日快樂）當參照。
- **音的長短**：長音原本誤含兩次敲擊（來源窗跨過 C5 重敲）→ 來源窗縮到單次敲擊；長音再用回授梳狀殘響把延音拉長。
- 音波記憶🎶 / 音往哪裡走↕️ / 這首對嗎🎼 圖示已區隔。

### ⚠️ 待優化 / 未完成
- **鋼琴音色品質（最想改）**：目前音色取自桌面那首 Bach C 大調前奏曲，但該曲整首是 C 大調琶音和弦＋踏板、**沒有乾淨單音**，只能用 FFT 諧波篩硬挖一個 C5 出來再 pitch-shift → 音色偏悶、起音不自然，已是此來源的天花板（使用者也覺得不夠好）。**根本解＝換來源素材**：一段「一個一個分開彈、音間有空隙」的鋼琴單音/音階錄音（CC0 或自彈自錄皆可），甚至只要一個乾淨的中音 C 單音，就能用同一套 `gen_tones.py` 取樣器 pitch-shift 出全部音高，音色立刻真實很多。拿到素材後設 `PIANO_SRC` 環境變數指過去、重跑即可。
- **適性難度（音樂 6 關）**：目前固定難度。要做需在 gen_tones 增「較小音程/較近速度差/微離調」的 hard 變體 clip，再讓 ListenChooseGame 依 `ProgressStore.levelFor` 選題池（clip 架構已留好）。
- **真人手感**：什麼不見了記憶節奏、轉轉看難度、各音樂關長短/快慢/走音對比是否夠清楚 → 待給孩子實玩回饋。

## TODO（下次）
- [ ] **跨裝置取回進度（備份／還原，非即時同步）**
  - 目的：**只**為「外出帶別的裝置、換新平板、怕掉資料」時取回進度。**同一時間只有一台在玩**，不是雙裝置同時操作。
  - 因此可丟掉所有同步重活：❌ 衝突合併／CRDT、❌ outbox／增量游標／墓碑、❌ PowerSync、❌ wallet 雙計數。規則只剩一句：**整包快照、時間戳最新者贏（LWW）**。
  - 身分：**家長帳號**（Email / Apple / Google，接現有 `showParentGate`）；孩子端不碰帳號／零個資（COPPA）。可「匿名先玩 → 要跨裝置時再綁定」降註冊牆。
  - 方案 B（建議，自動）：Supabase 一張表 `backups(家長uid, snapshot jsonb, updated_at)` + RLS（只能讀寫自己那列）。`AppDb` 加 `exportSnapshot()` / `importSnapshot()`（per-profile 序列化成 JSON、整包覆蓋還原）。約一兩百行 + 登入 UI。
  - 方案 A（可當 v0，零後端）：設定頁「匯出／匯入進度」檔案，走系統分享（Drive/iCloud/Email）。核心 serialize 邏輯與 B 共用，先做 A 升級 B 不白工。
  - **上傳觸發**：任何 DB 寫入 → 立刻標記 `dirty`（絕不靠程式判斷「是否重大」）；實際上傳用 **debounce 3~5s 合併**連續變動；切背景／暫停／關閉 **強制立即 flush**；離線或失敗保持 `dirty`、回前景或網路恢復時重試。整包快照無增量，合併掉的只是重複的中間狀態，零遺失。
  - **還原防呆**：開 app 時若**雲端比本機新**就先拉回（避免在主平板用舊資料蓋掉雲端較新的快照）。
- [ ] **手感待真人/你確認**：什麼不見了記憶節奏（每物件 1400ms、開場 extra 300ms，皆在 `whats_missing_game.dart` 可調）；轉轉看難度是否仍偏難。
- [ ] **（商業，另一條線，非程式）**：定價策略討論結論＝freemium 一次解鎖 NT$390、免費開放「一個年齡段+每領域 1 關」、加家長學習報告當付費鉤子、補 iOS（幼兒平板大宗是 iPad）。要做再開。
- [ ] 7-8 歲段（之後）：學科型（注音正式學/符號運算/閱讀），玩法不同。
- [ ] App 圖示、release 簽章、上架前隱私政策。
- [ ] 真平板實測（目前都在模擬器；桌面有舊 release APK，需重打包最新版）。
- [ ] 真人驗證：給孩子玩，回饋記 `lessons.md`。

## 擴充方式（架構）
- 加遊戲 = 寫 `games/<id>` + `content/registry.dart` 加 `GameDef`（標 ageBands）。
- 加齡段 = `models/age_band.dart` 設 enabled + 補該齡 GameDef；領域頁會自動依齡過濾。
- 共用引擎：PickGame(聽提示點圖/找不同類/樂器/動物)、DragMatchGame(分類/拼圖，支援隨機產生器+多回合)、MazeGame(支援程序產生)、CountTap/Rhythm/Arithmetic/NumberCompare/Memory/SpotDifference/PatternMatrix/Opposite。
