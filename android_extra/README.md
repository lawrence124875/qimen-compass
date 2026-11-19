# android_extra

CI 用 `flutter create` 產生 `android/` 後，`scripts/patch_android.sh` 把這裡的原生檔案複製進去：
- `kotlin/*.kt` → `android/app/src/main/kotlin/com/lclab/qimen_compass/`（namespace 為 flutter create 的 `com.lclab.qimen_compass`）
- `res/` → `android/app/src/main/res/`

桌面小工具（HANDOFF §12 P7）：`QimenWidgetProvider` 讀 `home_widget` 存的 `qm_widget_slots`（App 每次開啟預先算好 7 天的時辰），每 30 分鐘依目前時間挑出該時辰的吉方顯示。
