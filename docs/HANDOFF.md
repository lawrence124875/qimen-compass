# 奇門羅盤 HANDOFF（規格＋交接）

> 每個新討論串、每次 Claude Code session 都先讀這份。完成的待辦直接刪除，只留現況。
> 工作分工：程式、文件、CI 都由 Claude Code 雲端 session 處理（commit 到 main）；chat 只做討論與後台設定。

## 0. 基本資料（暫定，可改）
- App 名稱：奇門羅盤（英文 Qimen Compass），開發者 LC Lab，package `com.lclab.qimen`
- Repo：`qimen-compass`（公開：程式碼＋本檔）／`qimen-content`（私人：判讀文句、規則 JSON、build Releases）
- 技術：Flutter，Android 優先，保留 iOS 相容；架構模組化
- 沿用現有資源、不額外花錢：GitHub、Play Console、Firebase 免費方案（與另外兩個 App 共用，Remote Config 用 `qm_` 前綴）、AdMob、RevenueCat
- **多語：11 語**，語言清單與 i18n 架構比照謙卦（見 iching-cards HANDOFF）。先做 zh-TW＋en，其餘依序補上（語言數優先於細修）。奇門術語（八門、九星、八神、宮名）在非中文介面一律保留中文，加上拼音與一句意譯，例如「生門 Sheng Men（Gate of Life）」；判讀文句庫照語言分檔
- **App 內不使用 AI**：全部用規則引擎＋模板文字，可以離線使用
- APK、AAB 絕對不放公開 repo 的 Artifacts；build 一律上傳到 `qimen-content` Releases（Secret `BUILDS_REPO_TOKEN`，做法比照謙卦）
- 機械性工作（下載、測試、建置）交給 GitHub Actions 執行，只回報摘要

## 1. 產品定位
奇門遁甲的「工具型」App，核心是把**排盤疊在現實方位上**：手機指南針加上八門，可以即時知道各門在哪個方向；居家用九宮對應到房間。
與謙卦（易經、梅花、紫微、八字）分開成兩個 App，彼此互相導流；謙卦內放一個入口連到本 App 的商店頁。

## 2. 版本路線
| 版本 | 內容 |
|---|---|
| V1 | 時家轉盤排盤、奇門羅盤、出行訣（走路、跑步、喝水計時）、吉時推播 |
| V1.5 | ~~擇時擇日、年盤、月盤~~（完成）、宅盤九宮（站中心點標記房間＋拍平面圖套用） |
| V2 | 事類占卜（求財、事業、感情、考試、失物、官司、健康）、失物方位接羅盤（✓ run 11） |
| V3 | 主客分析（宜先動或後動、宜攻或宜守）；日家盤 |
| 延伸（§12 P1–P8） | 地圖八門、目的地吉凶、搬家方位、辦公室九宮、床位朝向、尋人尋寵物、本命盤、流年流月、合盤、個人吉方、奇門黃曆、桌面小工具、分享圖卡、盤面點擊解說、增課 |

## 3. 排盤引擎（`lib/engine/`，純 Dart、不依賴 UI）
- 盤的時間單位做成參數：`PanUnit { hour, day, month, year }`，已實作 hour、month、year
- 曆法：使用 `lunar`（6tail）套件取得節氣與干支；包成 `CalendarService`，日後可以抽成共用套件
- 時家轉盤：
  - 陽遁：冬至到芒種；陰遁：夏至到大雪
  - 定元：預設**拆補法**，可以切換**置閏法**。拆補法以符頭（最近的甲日或己日）的地支決定：子午卯酉＝上元、寅申巳亥＝中元、辰戌丑未＝下元
  - 局數表（上／中／下元）：
    - 陽遁：冬至、驚蟄 1/7/4；小寒 2/8/5；大寒、春分 3/9/6；立春 8/5/2；雨水 9/6/3；清明、立夏 4/1/7；穀雨、小滿 5/2/8；芒種 6/3/9
    - 陰遁：夏至、白露 9/3/6；小暑 8/2/5；大暑、秋分 7/1/4；立秋 2/5/8；處暑 1/4/7；寒露、立冬 6/9/3；霜降、小雪 5/8/2；大雪 4/7/1
  - 地盤排三奇六儀 → 依時柱找旬首求出值符、值使 → 排天盤九星、人盤八門、神盤八神（陽遁順排、陰遁逆排）
  - 中五宮寄坤二宮
  - 輸出：每宮的天干（天盤、地盤）、九星、八門、八神，加上空亡、馬星、伏吟、反吟、門迫、擊刑、入墓的標記
- 時間設定：時區、**真太陽時**開關（依經度修正）、子時換日（早子時／晚子時）
- **驗證**：建立 `test/golden/`，至少 30 組測試盤（跨陰陽遁交界、節氣交界、子時），用 CI 跑；參考盤由 Lawrence 從他信任的排盤軟體提供

## 4. 奇門羅盤（V1）
- 套件：`flutter_compass`（方位角）、`sensors_plus`（磁力計）
- 後天八卦九宮，每宮 45°：坎北、艮東北、震東、巽東南、離南、坤西南、兌西、乾西北
- 畫面：整個八門盤依 heading 反向旋轉，讓盤面對準現實方位；中央放固定指針，顯示「前方：○門（吉／平／凶）」
  - 吉：開、休、生；平：杜、景；凶：死、驚、傷
- 北方基準：預設**磁北**，可以切換**真北**（磁偏角用 WMM 計算，候選套件 `geomag`）
- 干擾偵測：磁場強度超出 25–65 μT 或抖動過大時，提醒使用者遠離金屬和家電；顯示精度等級；提示畫 8 字校準、手機要平放
- 「找吉門」：選一個門 → 箭頭引導使用者轉向
- 顯示下一個時辰的門位預覽，並倒數到換局

## 5. 出行訣（V1）
- 選擇事類 → 列出當下與接下來的吉時與吉方 → 用羅盤導航往吉方走
- 走路、跑步模式：15–30 分鐘計時加計步（`pedometer`）
- 喝水法：在吉方靜置水杯的計時提醒
- 吉時推播（`flutter_local_notifications`）

## 6. 宅盤九宮（V1.5）
- 找門位只需要「中心點＋正北」；坐向只影響宅命判讀
- 坐向定法讓使用者選：自家門（預設）、最大採光面、大樓坐向；透天厝用一樓大門。每個選項附一句說明
- 三種輸入方式：
  1. 站在中心點量北方，再把手機對準各個房間方向按「標記」，記錄角度後換算成所在宮位
  2. 拍平面圖：拖曳四角校正 → 設定北方（看圖上指北針，或手機貼牆量一次）→ 自動算中心（重心，可以手動微調）→ 套上九宮格
  3. 簡易手繪：拖拉長方形拼出房間
- 疊加的盤：年盤、月盤（看格局）；時盤（擇時佈局）
- 入宅時間、大裝修時間為選填：有填就顯示宅命盤；只填日期就用日盤；沒填就只看年盤
- 提醒使用者在干擾少的地方（門口、陽台）量北方，量完鎖定

## 7. 擇時擇日（V1.5）
- 掃描未來 N 天的時盤，依事類規則給每個時段打分數，列出前 5 名，可以加入手機行事曆
- 計分項目：用神門落宮旺相、無空亡、無門迫、無伏吟反吟、有吉格加分；可選擇加入使用者生辰（日干、年命）
- 情境：簽約、開幕、面試、相親、訂婚、遠行

## 8. 事類占卜（V2）
- 依提問時間起局 → 選事類 → 抓出用神 → 規則判斷 → 組合模板文句
- 用神對照表做成 JSON 設定檔，可以切換流派（例如感情看休門，或看六合、乙庚）
- 預設用神：求財看生門、感情看休門、事業看開門、考試看景門、失物看時干與六合
- 失物：直接接羅盤顯示方位
- 規則表與文句庫放在 `qimen-content`，分批累積
- 上架合規：官司、健康類問題要加「僅供參考」聲明

## 9. 主客分析（V3）
- 天盤為客、地盤為主，比較兩者旺衰 → 判斷宜先動或後動、宜攻或宜守
- 對照我方（日干）、對方（時干）、事情三方的生剋，輸出固定建議文句；不做開放式推演

## 10. 商業模式（待定，先比照謙卦）
- 免費：奇門羅盤、當下時盤、出行訣（有次數限制）、廣告
- 訂閱：擇時、宅盤、占卜解讀、去除廣告。Play 商品 `qm_premium_monthly`（基本方案 monthly，USD 3.99／TWD 99）、`qm_premium_yearly`（yearly，USD 24.99／TWD 590，優惠 `trial-7d-yearly` 7 天試用），與謙卦同價。RevenueCat 專案 `qimen`：權限 `premium`、Offering `default`（$rc_monthly、$rc_annual）

## 11. 待決事項
- [x] App 名稱：奇門羅盤／Qimen Compass（2026-11-18 定案）
- [x] 訂閱價格（2026-11-18 定案，同謙卦）
- [ ] 手機實測付費牆與測試購買（run42 起含 RevenueCat key）
- [ ] 封閉測試 12 人 × 14 天後才能上正式版（2026-11-19 已送審；審核通過後要找 12 位測試者加入，並連續 14 天）
- Play Console 現況（2026-11-19）：應用程式內容、商店資訊 14 語（含 pt-PT、es-ES、es-US）、內部測試 v1 已發布；即時開發人員通知主題 `projects/learning-english-5ea8b/topics/Play-Store-Notifications`（與謙卦共用）；RevenueCat 專案 `qimen` 服務帳戶與通知已連線。AAB 版本代碼 = run_number
- [ ] 測試盤的參考軟體由誰提供（請 Lawrence 指定）

## 12. 下一步：延伸功能 P1→P8（2026-11-19 定案，一次做完才出正式版；完成一階段刪一階段）
原則：全部規則＋模板、不用 AI；新功能用 Remote Config `qm_feature_<id>` 開關（預設開）；進階功能接 `requirePremium`；新介面文字 11 語齊全；中途不出 APK，只在 P8 建版。
- [ ] P5 雙人合盤（兩人年命、日干生剋；合夥／婚配）；遠行、搬家方位（住家為中心，對照年盤、月盤）；尋人、尋寵物（問事新事類，接羅盤方位）
- [ ] P6 宅盤延伸：辦公室、店面九宮（座位、收銀台、大門）；床位、書桌朝向（羅盤量面向的門）；宅盤判讀文句；盤記補齊（擇時、目的地、本命盤可存紀錄＋應驗回饋）
- [ ] P7 桌面小工具（`home_widget`，「此刻吉門在東南」每時辰更新）；入門課增課（羅盤、地圖、擇時、宅盤、個人化）；iOS Info.plist 權限說明
- [ ] P8 翻譯檢查（`l10n.py check --strict`）→ 版本 1.0.0 → `store/release_notes.txt` 14 語 → 正式版 AAB 上傳 qimen-content Releases（版本資訊寫在 AAB 上方）

## 13. 現況（2026-11-17）
- CI 已打通：run 2 通過並發佈 qimen-content Release `qimen-android-run2`（0.1.0+1，APK／AAB 各約 44 MB，除錯金鑰簽署；上傳金鑰 `ANDROID_KEYSTORE_*` 等 Secrets 尚未設）
- Repo：`qimen-compass`（公開）、`qimen-content`（私人，放 build Releases，tag `qimen-android-run<N>`，只保留最近 5 個）
- CI：`check.yml`（分支：analyze＋test）、`build_android.yml`（main：analyze＋test → APK＋AAB → 上傳 qimen-content Releases）。Flutter 固定 3.47.9（比照謙卦）；`android/` 由 CI 用 `flutter create` 產生，`scripts/patch_android.sh` 設名稱、套件 `com.lclab.qimen`、簽署（上傳金鑰 Secrets 未設時用 qimen-content `signing/debug.keystore` 固定測試金鑰，APK 可覆蓋安裝保留紀錄；versionCode＝run_number。之後設正式上傳金鑰時簽章會變，使用者要再移除一次，先提醒）
- i18n：**11 語全部開放**（2026-11-17）：ARB 474 鍵齊全，課程、問事文句 11 語（qimen-content `app/course`、`app/divination/text`）。術語唯一來源 `tools/l10n/glossary.json`（帶聲調拼音，例「生門 Shēng Mén (Gate of Life)」；日韓越意譯用各自讀音）→ `l10n.py gen` 產生 `lib/l10n/terms_data.dart`；流程見 `tools/l10n/README.md`。已開放語言缺鍵測試會失敗，新增介面文字的串要通知翻譯補掃（或自行用 l10n.py 補）。簡中內容用 qimen-content `tools/to_hans.py`（乾不轉干）。字型：TC 主字型＋補字 QmFbSC／JP／KR／TH／AR（`build_fonts.py` FALLBACKS），日文漢字暫用 TC 字形
- 引擎 `lib/engine/`：
  - `CalendarService`：節氣用 `lunar`（北京時間→UTC），日柱以儒略日自算、時柱五鼠遁；時區、真太陽時（經度＋NOAA 均時差）、子時換日（`nextDay` 23 點換日預設／`lateZi` 晚子時）
  - `ShiJiaEngine`：拆補法（預設）／置閏法（芒種／大雪三元後，下一上元符頭距夏至／冬至 >9 日則閏；已對照 zyqmdj.com 公開盤例：2016 閏芒種、2015 大雪不閏、2024 閏大雪、2017-03-14 陽七、2028-10-03 陰四）；地盤、值符值使、九星（禽寄芮）、八門（值使依時干數走九宮，入中寄坤）、八神（陽順陰逆）、空亡、馬星、伏吟反吟、門迫、擊刑、入墓
  - `ChuXingPlanner`（`chuxing.dart`，出行訣）：事類→用神門（出行＝開休生取最佳、求財生、事業開、感情休、考試景）；每時辰以中點起局，基礎 4 分，門迫／空亡／伏吟／反吟／擊刑／入墓各 −1，吉神（值符、太陰、六合、九地、九天）+1、凶神（白虎、玄武、螣蛇）−1，格局（`geju.dart`：輔禽心、三遁 +1；蓬芮、四凶格、庚丙 −1，擇時與問事同樣計入）；五級 ≥5 大吉、4 吉、3 平、2 小阻、其餘阻；`dailyBest` 取每天設定時段內最佳 N 個且達「吉」者（推播：時段可全天、每天 1–6 則，ID 1100–1159；設定頁與出行訣頁共用 `travel_notify_options.dart`）。擇時同日筆數 1／2／3／5／不限（預設 2，避免前幾名擠在同一天），說明文字隨設定連動
  - 已有單元測試：日柱／時柱／節氣與 lunar 比對（1950–2060 抽樣）、地盤、結構不變量、九宮格 widget（深淺色、英文詳情、小尺寸）；盤面顯示起局依據（符頭、超神／接氣日數、閏局）；golden 35 組（拆補，來源 kinqimen 交叉比對，說明見 `test/golden/README.md`）

- 介面（`lib/app/`，羅盤等畫面請直接沿用）：
  - 主題 `theme/app_theme.dart`＋`theme/qm_palette.dart`：謙卦「天玄地黃」定案；`context.qm` 取色（深淺各一份 ThemeExtension，含吉平凶 `luck()`、五行 `element()`、圖上文字 `QmPalette.onImage`）；字型 `kSans`／`kSerif`（帶 fallback），盤面文字用 `serif()`。引擎的 `Element` 與 Flutter 撞名，UI 檔 import engine 時 `hide Element`
  - 盤面 `widgets/chart_board.dart`：`ChartBoard(chart, highlight: {宮}, onTapPalace:)`（上南下北）、`PalaceCell`、`showPalaceSheet`／`PalaceDetail`、`marksOf`、`kBoardLayout`
  - 首頁 `home_page.dart`：`ChartInfo` 盤頭＋九宮格＋前後時辰切換＋出行訣入口，橫式左右排；右上 ⓘ 重看引導、分享盤面卡片（`widgets/share_capture.dart`，share_plus，擷取時加 App 名與聲明）
  - 設定 `settings/app_settings.dart`（`AppSettings.instance`）：外觀；排盤：定元方法、子時換日、真太陽時（`settings/solar_city_picker.dart`：目前位置＝GPS 概略位置，`qm_solar_city`=-2、經度存 `qm_solar_lon`，啟動時靜默更新；或搜尋全球約 190 城 `settings/cities.dart`，前 22 個為舊索引勿改順序）。排盤一律用 `timeSettingsAt(instant)`＋`juMethod`；`TravelReminders.timeSettings` 已接上（出行訣 planner 尚未吃 `juMethod`）
  - 首次引導 `widgets/guide.dart`：`showGuide(context, id, [GuidePage×3], force:)`，看過記在 `qm_guide_seen_<id>`；新功能照此加
  - 比照謙卦共通功能（2026-11-17 完成）：
    - 服務層 `app/services.dart`（`AppServices.of(context)`；測試直接 `Services()`）：Firebase（`core/firebase/`，Analytics／Crashlytics／Remote Config，事件與參數 `qm_`）、意見回饋 Firestore `qm_feedback`、RevenueCat（權限 `premium`）、AdMob（`core/admob/`，單元 ID 由 CI dart-define；沒設定用測試 ID）、Play In-App Updates（`shared/widgets/update_prompt.dart` 包在首頁）
    - 免費版 `shared/premium/usage_gate.dart`：`ensureCanUse()`（出行訣每天 1 次＋獎勵 1 次，`qm_free_travel_per_day` 等）、`pauseBeforeResult()`（每日第一次插頁）、**`requirePremium(context, feature:)`：擇時、宅盤、問事等訂閱功能入口呼叫**（免費體驗一次，之後只看標題）；付費牆 `paywall_page.dart`；橫幅 `AdBanner` 放首頁、設定、紀錄列表
    - 紀錄＋應驗回饋 `features/records/`：**其他功能呼叫 `saveRecord(context, kind: RecordKind.xxx, chartAt:, summary:)`**；`records.json`（schemaVersion 1）、搜尋、種類／待回饋篩選、左滑刪除可復原、應驗統計、N 天後 20:00 回顧提醒（id 1100–1199）、備份還原（設定「備份與換手機」）；免費 30 則、只看近 30 天。問事紀錄已併入（`RecordKind.divination`，`meta` 帶 topic／school／verdict，舊 `qm_div_journal` 自動搬；問事不受免費 30 則限制）；`RecordListPage(initialKind:)` 可預先篩選；詳情頁「看解讀」重算
    - 每日提醒 `features/reminders/daily_reminder.dart`：預設開、8:00，排 7 天（id 1050–1056），內容為當天最佳吉時；設定頁另有吉時推播開關
    - 設定頁加：會員、備份與換手機、推薦給朋友（`features/share/share.dart` `shareApp`）、意見回饋、每日提醒、吉時推播、使用統計開關、廣告隱私、隱私權政策／使用條款（`docs/privacy.html`、`terms.html`，需開 GitHub Pages）、LC Lab 其他 App（謙卦、光穗塔羅，`app/links.dart`）
    - CI：`scripts/patch_firebase.sh`、`patch_ads.sh`；Secrets 皆已設（2026-11-18）：`GOOGLE_SERVICES_JSON_BASE64`、`ADMOB_APP_ID`、`ADMOB_BANNER/INTERSTITIAL/REWARDED_AD_UNIT_ID`、`REVENUECAT_ANDROID_API_KEY`、`ANDROID_KEYSTORE_*`；缺任一時建置照常（無 Firebase、測試廣告、訂閱「尚未開放」）
    - 謙卦 iching-cards PR #69、塔羅 tarot-cards PR #49：其他 App 加入奇門羅盤，預設隱藏；上架後 Remote Config 設 `qg_other_app_qimen`=1、`tr_other_app_com_lclab_qimen`=1（塔羅圖示放 tarot-content `branding/other_apps/com.lclab.qimen.png`）
  - 尚未做：夏令時扣回標準時
  - 圖示與各語系桌面名稱：`branding/`（見該資料夾 README），CI `patch_android.sh` 套用
  - i18n 對照：`l10n_ext.dart`（`l.luck()`、`l.palaceDirection()`、`l.markHint()`）；術語 `QimenTerms.palace()`、`mark()`、`markShort()`
  - 字型：`scripts/build_fonts.py` 從 noto-cjk tag（Sans2.004、Serif2.003）抓 TC 黑體／宋體，依 lib/ 內 .dart、.arb 用字做子集到 `assets/fonts/`（不進 repo，兩個 workflow 都先跑）；本機開發先 `pip install fonttools && python3 scripts/build_fonts.py`
- 課程「奇門入門課」（`lib/features/course/`）：首頁按鈕 → 目錄（已讀進度）→ 單課（段落、重點、課末按鈕開功能、下一課）。內容在 qimen-content `app/course/<contentFolder>.json`（10 課，前 2 課 `free`；格式見該資料夾 README），CI 匯入到 `assets/content/course/`；找不到該語言退回 en → zh-Hant。`action.type` 目前 `chart`／`travel`，加新功能（羅盤、擇時、宅盤、占卜）時在 `CourseActionType` 加類型並可增課。付費牆：`CourseAccess.paywallEnabled` 目前 false（全開），接 RevenueCat 後改 true 並更新 `CourseAccess.premium`。`test/course/` 檢查各語結構與 zh-Hant 一致、禁用字。已完成 zh-Hant、en；其餘 9 語由翻譯串補
- 出行訣（`lib/features/travel/`）：首頁「出行訣」→ 事類切換、現在＋接下來 11 個時辰的吉方與等級、走路／跑步（15/20/30 分＋`pedometer` 計步）、喝水法（15/30/60 分）、`flutter_compass` 箭頭指向吉方；未來時辰可「提醒我」
- 吉時推播：`lib/services/notifications.dart`（`flutter_local_notifications`，一律 `inexactAllowWhileIdle`、不用精確鬧鐘權限）；`TravelReminders` 每次啟動與切換事類時重排 7 天、吉時前 N 分鐘通知（設定頁「推播設定」：提前 10／20／30／60 分、時段 `HourWindow`（預設 7–21，可全天；22–6 點標題加「夜間」）、每天 1–3 則；`TravelPrefs` 鍵 `travel_notify_lead／from／to／per_day`）；預設開、第一次進出行訣看到結果才請求權限，被拒時 SnackBar 開 App 設定（permission_handler `openAppSettings`；`app_settings` 套件 compileSdk 33 會讓建置失敗，已移除）。通知 id：1000–1019 每日、1020–1039 單次提醒、1040 計時結束。`patch_android.sh` 加 POST_NOTIFICATIONS／RECEIVE_BOOT_COMPLETED／ACTIVITY_RECOGNITION、兩個 receiver、desugaring、ProGuard Gson
- 年盤、月盤（`PanUnit.year／month`）：年家以 60 年為一元，1864 上元陰一、1924 中元陰四、1984 下元陰七（依立春換年）；月家依年支，子午卯酉陰七、寅申巳亥陰一、辰戌丑未陰四（依節換月）。一律陰遁，起局柱為年柱／月柱（`QimenChart.pivot`，旬首、空亡、馬星都依此柱）。首頁「時盤／月盤／年盤」切換，前後鈕依單位換時辰／月／年。日家盤仍排 V3
- 擇時擇日（`lib/engine/zeshi.dart`、`lib/features/zeshi/`）：六情境（簽約開門＋六合、開幕生開＋值符、面試開門＋九天、相親休門＋六合、訂婚休生＋六合、遠行開休生＋九天）；每時辰中點起局，基礎 4 分，加分：用神門旺相（宮生門或比和）、吉神（情境喜神另記）、三奇臨宮、青龍返首、飛鳥跌穴、年命逢吉門；扣分：用神受宮剋、門迫、空亡、伏吟、反吟、擊刑、入墓、凶神、年命逢空墓。五級 ≥7 大吉、≥5 吉、≥3 平、≥1 小阻。時段預設 7–21 點可調（`HourWindowPicker`，`lib/app/widgets/hour_window.dart`），範圍 7／14／30／90／180 天／1 年，前 5／10／20 名、同天最多 1–3 筆（`qm_zeshi_*`）；長範圍每 7 天一段 `scan` 後 `pick`，顯示進度；生日存 `qm_birth_date`。卡片點開看盤、`add_2_calendar` 加入行事曆（`patch_android.sh` 宣告 INSERT intent；iOS 上架前要加 `NSCalendarsUsageDescription`）。首次進入顯示說明，右上 ⓘ 重看
- 擇時待補（比照謙卦 §14）：擇時紀錄＋事後應驗回饋、付費牆（新功能免費完整體驗一次）
- 比照謙卦已補：首次 3 頁引導＋右上 ⓘ 重看、點通知直接開出行訣（`Notifications.routes`＋`navigatorKey`）、出行紀錄（完成即存，JSON 帶 schemaVersion，保留 30 則，左滑刪除可復原）
- 出行訣待補：iOS `NSMotionUsageDescription`（計步）、免費次數＋廣告（等廣告模組）、分享卡片、排盤設定（真太陽時等）接上設定頁後同步給 `TravelReminders.timeSettings`；需實機驗證 release 版通知會跳

- 事類問事（V2，介面名「奇門問事」，避開「占卜」字眼）：引擎 `lib/engine/divination.dart`（`DivinationEngine`：用神落宮、月令旺相休囚死、宮生剋、空亡門迫擊刑入墓馬星伏反吟、同宮門神、日干與用神生剋 → 加總分五級；`factorWeight` 可調）；畫面 `lib/features/divination/`（事類＋流派選單、解讀頁、失物方位＋羅盤箭頭＋可能地點、官司／健康「僅供參考」聲明、問事紀錄＋應驗回饋＋左滑刪除可復原、首次 3 頁引導＋ⓘ、複製結果）。內容在 qimen-content `app/divination/`：`rules.json`（7 事類、流派 standard／liuhe／yigeng／wuzi）、`text/<語言>.json`（zh-Hant、en；缺語言退回 en）。CI 兩個 workflow 都把 qimen-content `app/` 複製到 `assets/content/`（課程共用），`build_fonts.py` 收這些 JSON 的字；`test/engine/divination_test.dart` 在 CI 檢查內容檔鍵值齊全
- 問事延伸解讀（`lib/engine/divination_more.dart`，`ReadingMore` extension）：決斷（可行／可行但有阻／宜緩／不宜，依五級與有無扣分）、把握度（加減分一致度：高／中／吉凶參半）、應期（用神落宮地支，逢空亡取空亡地支＝出空；快慢依馬星／反吟／旺相 vs 伏吟／入墓／囚死；快＝12 天內、中＝13–24 天、慢＝下個相符月支）、宜忌（同宮門、神、盤面標記 → 內容檔 `tips`，各取 3 條＋宜往／忌往：吉取用神宮、否則生開休門；忌取天盤庚，否則白虎）、我方與對方（relation 事類比較日干與主用神強弱）、盤面標示說明。應期與強弱算法請 Lawrence 依流派校對
- 事類問事待補：其餘 9 語文句檔（加語言時順便加 `text/<code>.json`）；分享卡片圖片；免費次數／付費牆（商業模式定案後）；用神與加權請 Lawrence 依流派校對

- 奇門羅盤（V1，`lib/compass/`）：`compass_math.dart` 純計算（`palaceAtBearing`、`normalizeDeg`、`turnDelta`、`MagneticMonitor` 25–65 μT＋抖動、`GyroLock` 室內鎖定、`nextChartChange` 下個換盤時刻；宅盤串沿用，勿改簽章）；`compass_page.dart` 盤面依 heading 反向旋轉、前方門吉平凶、精度／干擾／平放提示、磁北⇄真北（`declination.dart`：geomag WMM2025＋geolocator 只要概略位置，`patch_android.sh` 加 `ACCESS_COARSE_LOCATION`）、室內鎖定（門口量北方後改陀螺儀）、找吉門箭頭、下個時辰預覽＋倒數；首次 3 頁引導＋ⓘ、記住北方基準（`qm_compass_*`）。排盤沿用 `AppSettings`。待辦：iOS 需 `NSLocationWhenInUseUsageDescription`；課程 `CourseActionType` 可加 compass
- 宅盤九宮（`lib/features/house/`，首頁與羅盤同一列）：§6 三種輸入完成
  - 站中心點標記（`mark_rooms_page.dart`）：用羅盤的 `GyroLock`／`MagneticMonitor`，包成 `HeadingTracker`（宅盤內共用，門口鎖定後走進屋內仍維持）
  - 拍平面圖（`plan_corners_page.dart`→`plan_editor_page.dart`）：`image_picker`（最大 2048px）存 App 文件夾；拖四角→單應矩陣 `Transform` 透視校正，長寬比自動估計可微調；北方轉箭頭對指北針或手機量；中心預設重心可拖曳
  - 手繪：同一編輯器，長方形拼房間（0.5 格對齊），中心＝房間聯集重心；含中心點的房間算中五宮，中宮半徑＝等面積正方形邊長 1/6
  - 九宮採 45° 扇區（中心＋正北），宅盤一律磁北；坐向四種定法＋量向；入宅時間選填
  - 疊盤：現在／指定時間時盤、年盤、月盤、宅命盤（有時間＝時盤、只填日期＝日盤、未填＝年盤）；引擎不支援的單位（目前日盤）捕捉 `UnsupportedError` 顯示「製作中」
  - 資料：SharedPreferences `qm_houses`（schemaVersion 1：current＋houses，每間帶 id、name；舊 `qm_house` 自動搬）；標題點開「我的房子」切換、新增、改名、刪除可復原（沒復原才刪平面圖照片）；引導用共用 `showGuide`（id `house`）；排盤沿用 App 排盤設定
  - 待補：其餘 9 語的 house* 鍵；iOS `NSCameraUsageDescription`／`NSPhotoLibraryUsageDescription`；宅盤判讀文句（qimen-content）；分享卡片；付費牆（§10 宅盤屬訂閱）；實機驗證陀螺儀鎖定漂移

- 延伸 P1（2026-11-19）：底部 4 分頁 `lib/app/main_shell.dart`（`MainTab`；羅盤離開即拆、其餘保留；`MainShell.select(tab)` 從推上去的頁面切分頁）；「我的」`lib/app/pages/me_page.dart`（`MePage.openPremium(context, feature, builder)` 開訂閱功能）；擇時分頁、宅盤、問事 `_start` 已接 `requirePremium`。盤面點擊解說：`PalaceDetail` 每個門／星／神／天干下方一行意義（`lib/features/meaning/`，qimen-content `app/meaning/`）。ARB 新增鍵用 `tools/l10n/add_keys.py`（一次 10 語）→ `l10n.py hans` → `check --strict`
- 延伸 P2（2026-11-19）：地圖八門 `lib/features/map/map_page.dart`（羅盤分頁右上「地圖八門」；真北扇區、半徑 1／3／5 km、點／長按放圖釘、`geocoding` 地址搜尋）；目的地吉凶 `destination_page.dart`（`DirectionPlanner`，`lib/engine/direction.dart`：基礎 3 分＋門吉凶 ±1，其餘同出行訣；訂閱體驗一次 `destination`）；`lib/compass/geo_math.dart`（方位角、距離、扇形）。Maps key：Secret `MAPS_API_KEY` → `patch_android.sh` 寫入 manifest、`--dart-define=MAPS_ENABLED`；沒設時不建立 GoogleMap（SDK 會當），只留搜尋。加 `ACCESS_FINE_LOCATION`。iOS 上架前要在 AppDelegate 設 Maps key
- 延伸 P3（2026-11-19）：今日奇門黃曆 `lib/engine/almanac.dart`（`DailyAlmanac.of`：子時起 12 時辰，一般出行規則，`best(3)` 吉時、`bestPalace` 吉方）＋`lib/features/almanac/`（盤面分頁頂端 `AlmanacTile`，點開可換日、分享）；分享圖卡外框 `lib/app/widgets/share_card.dart`（`ShareCardFrame`＋`shareBoundary`，黃曆、目的地已用）。ARB 通用鍵 `labelValue`（「標籤：值」，非中文用半形冒號）
- 延伸 P4（2026-11-19）：「我的」→「我的奇門」`lib/features/personal/`（訂閱體驗一次 `personal`）。個人資料 `profile.dart`：生日沿用擇時的 `qm_birth_date`、出生時間 `qm_birth_time`（分鐘，選填；未填以 12:00 起局並提示）。引擎 `lib/engine/personal.dart`：`stemPalace`、`PersonalEngine.natal`（本命時盤、年命宮＋日干宮以 `DirectionPlanner.judge` 評級）、`fortune`（年盤／月盤上的年命宮）、`luckyHours`（7 天內年命宮達吉的時辰，方位＝年命宮）。解說沿用 `MeaningContent`。坑：簡中「日干宮」會變「日干宫」被 l10n 檢查當成乾→干誤轉，繁中改寫成「日干所落的宮」
## 14. 沿用謙卦／光穗塔羅的經驗（2026-11-17 整理；細節見 iching-content `HANDOFF.md`、`docs/REFERENCE.md`，tarot-content `HANDOFF.md`）
### 配色與 UI（配色已定案，見 §13 介面）
- 謙卦「天玄地黃」：深色 玄墨 #1C1B22 底、玄灰 #26242E 卡片、地黃 #C9A45C 主色、稻金 #D8B56A 點綴、山褐 #7E6A52 框線、淡金 #E8D9B0 文字；淺色 宣紙 #F3ECDD 底、地黃 #946C2A。塔羅為晨光奶油＋琥珀金＋暮光紫。奇門建議沿用謙卦色系（同屬東方、利於互相導流），八門吉／平／凶用五行色標示，深淺色模式從第一版就做（設定「外觀」跟隨系統／淺／深；顏色用 getter，不放 const；圖上文字用固定 `onImage`）。
- 字體：思源黑體＋宋體子集（CI 用 `build_fonts.py` 從固定 commit 產生，不進 repo）；日韓泰阿換主字型，簡中用 SC 補字；`fontFamily: kSerif` 一定要帶 fallback。泰文、阿拉伯文不可加字距。
- 置中短提示語不加標點，逗號處換行；按鈕全 App 同一樣式；首頁一屏顯示完；不鎖方向，橫放／平板由版面處理（`adaptive_layout`）。
- 架構：功能模組化＋功能註冊表、遠端開關（Remote Config，`qm_` 前綴）、資料 JSON 帶 `schemaVersion`、core 不放介面文字（介面一律經 `terms.dart`／ARB）。

### 功能與課程（可比照）
- 免費版模式：每天免費次數＋獎勵廣告加次（載入失敗仍給該次）、每日第 1 次結果前播一則插頁（前置過場「靜心片刻…」，逾時 3 秒直接顯示）、橫幅只放首頁與列表；付費牆價格用 RevenueCat 當地價格字串、年繳 7 天試用；新功能「免費完整體驗一次，之後只看標題」。
- 紀錄（卦記／日記）：免費 30 則、只顯示近 30 天，分類、搜尋、左滑刪除可復原、備份還原。奇門可用於「擇時紀錄＋事後應驗回饋」。
- 課程：課程 JSON 分語言、前 1–2 課免費、課末按鈕直接開對應功能；首次進功能顯示 3 頁引導，右上 ⓘ 可重看。
- 每日提醒：預設開、早上 8 點，一次排 7 天一次性通知；**不請求精確鬧鐘權限**（`SCHEDULE_EXACT_ALARM` 已被兩個 App 移除）；啟動時不要求通知權限，第一次看到結果才要求，被拒後開系統通知設定。吉時推播照此做。
- App 內更新提示（Play In-App Updates）每版保留；設定頁「LC Lab 其他 App」；意見回饋表單（Firestore 集合 `qm_feedback`）；分享卡片。
- 交叉解讀規則：五級（大吉／吉／平／小阻／阻，不用「凶」字）、應期只給區間、ar／id 不顯示應期；文案避開占卜、保證、療效字眼（商店也是）。

### 已知坑
- pubspec 的資料夾 asset 不含子資料夾：assets/content 下每個子資料夾都要另列（run 11–25 問事文句沒打包；`divination_test` 已檢查）。
- Flutter 固定 3.47.9（3.50.0 release lint 在 JDK 17 崩潰）；要升先加 `setup-java` 21。
- 第三方套件 lintVital 可能在 lint 內部崩潰：只停用非 app 子專案的 lintVital（塔羅做法）。
- 容器讀不到完整 CI 日誌：錯誤轉成 annotation，讀 check-runs annotations。
- Release 清理依 run 編號排序，不用 createdAt。
- 通知：`flutter_local_notifications` 要兩個 receiver＋desugaring＋ProGuard 保留 Gson TypeToken，否則 release 版排程「成功」卻不跳。
- iOS：少 `GADApplicationIdentifier` 啟動即當、少 `CFBundleLocalizations` 一律英文。
- 夏令時：時辰用當地標準時間（扣回夏令時）；真太陽時讓使用者選城市、不取位置權限（謙卦 `SolarTime`）。奇門羅盤若要用定位算磁偏角，需注意 2027-01-27 位置權限新規（最小範圍）。
- 簡中不可自動繁轉簡專有名詞（例：「乾」變「干」），奇門術語（乾宮、天沖等）同理要人工對照。
- 版本資訊：改版本號前先寫 qimen-content `store/release-notes/<版本>.txt`，Release 說明才會帶入。
- 政策：2027-02-01 前交易者身分申報；2027-02 起記憶體品質門檻；AAB 瘦身（兩個 App 都約 110–120 MB）。
