# 奇門羅盤 圖示與名稱

- 名稱：奇門羅盤／Qimen Compass；圖示：九宮羅盤（2026-11-18 Lawrence 選定），謙卦「天玄地黃」配色。
- `make_icon.py` 產生 SVG：所有元素以 (54,54) 為中心對稱，主體在 108 中央 66 安全區內。`icon_foreground`／`background`／`monochrome`（Android 13 主題圖示）、`icon_full`（合成）、`icon_legacy`（裁掉外圈，給舊版圖示與商店 512）。
- `node branding/render_icons.js $PWD`（Playwright）輸出 `android/res/mipmap-*` PNG 與 `play_icon_512.png`。改圖後務必量測置中（像素外框中心與畫布中心差 ≤0.5px）。
- `android/res/`：自適應圖示＋舊版 PNG＋各語系 `app_name`（取自 ARB `appTitle`；印尼文資料夾是 `values-in`）。CI 的 `scripts/patch_android.sh` 複製到 `android/app/src/main/res/`，label 改成 `@string/app_name`。
- `play_icon_512.png` 也給謙卦／塔羅「其他 App」入口用（塔羅放 tarot-content `branding/other_apps/com.lclab.qimen.png`）。
