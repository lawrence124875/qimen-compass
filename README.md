# 奇門羅盤 Qimen Compass

奇門遁甲工具型 App（LC Lab）：把時家轉盤疊在現實方位上。Flutter，Android 優先。

- 規格與交接：[`docs/HANDOFF.md`](docs/HANDOFF.md)（每次工作先讀）
- 排盤引擎：`lib/engine/`（純 Dart，不依賴 UI）
- 測試盤：`test/golden/`（格式見該資料夾 README）
- 建置：GitHub Actions；APK／AAB 只發佈到私人 repo `qimen-content` 的 Releases
