# 11 語翻譯（比照謙卦）

## 檔案
- `glossary.json`：**術語表唯一來源**。八門、九星、八神、九宮、標記、陰陽遁、三元、24 節氣（繁、簡、帶聲調拼音、9 語意譯），以及 `ui` 區（吉凶五級、方位、盤面標籤等 ARB 鍵的固定譯法）。
- `l10n.py`：工具（用法見檔頭）。`gen` 產生 `lib/l10n/terms_data.dart`（進 repo，本機不用跑 Python 也能建置）。
- ARB：`lib/l10n/app_<locale>.arb`，範本 `app_zh.arb`；簡中 `app_zh_Hans.arb` 由 `hans` 產生，不要手改。

## 術語原則
- 非中文介面一律「中文＋帶聲調拼音＋意譯」：`生門 Shēng Mén (Gate of Life)`；日、韓用全形括號。
- 日、韓、越的「意譯」用各自的漢字讀法（せいもん、생문、Sinh Môn），比照謙卦的 sino-reading。
- 盤面格內只放漢字（`QimenTerms.doorName` 等），簡中為簡體。
- 簡中不可自動轉專有名詞：`hans` 先鎖定術語表的詞（乾宮不會變干宮），再跑 OpenCC tw2sp，最後套 `HANS_FIX`（推播→推送）。
- 吉凶五級用「大吉／吉／平／小阻／阻」，不用「凶」字；文案避開保證、療效字眼。
- 泰、阿拉伯文標 `needsNativeReview`：開放該語言前請母語者校閱。

## 新增介面文字（其他功能串照做）
1. 只需改 `app_zh.arb`（含 `@鍵` 說明）與 `app_en.arb`；其他語言缺鍵時 CI 只出 warning（gen-l10n 以範本補上）。
2. 翻譯串掃描時：`apply` → `hans` → 各語 `missing`／`fill` → `gen` → `check --strict`。
3. 已開放（`AppLanguages` 的 `ready: true`）的語言缺鍵會讓測試失敗。

## 開放一個語言前
ARB 齊全（`check --strict`）＋內容（qimen-content）＋字型（日韓泰阿、簡中，比照謙卦 `build_fonts.py`）→ `ready: true`。
