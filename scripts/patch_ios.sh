#!/usr/bin/env bash
# iOS 平台設定（比照謙卦 scripts/patch_ios.sh）：ios/ 由 CI 以 flutter create 產生，這裡套用 App 設定。
# 只在 macOS CI 執行（PlistBuddy）。目前只做不簽章建置（自用側載）；簽章與上架等 Apple 開發者帳號。
set -euo pipefail
PLIST=ios/Runner/Info.plist
PB=/usr/libexec/PlistBuddy
set_str() { $PB -c "Set :$1 $2" "$PLIST" 2>/dev/null || $PB -c "Add :$1 string $2" "$PLIST"; }

# Bundle ID 與 Android applicationId 相同
# Bundle ID 固定 com.lclab.qimen（2026-11-20 使用者決定：iOS 只裝私人版、覆蓋安裝保留資料；iOS 地圖金鑰也只限此 bundle）
BUNDLE=com.lclab.qimen; NAME="奇門羅盤"
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.lclab\.qimenCompass;/PRODUCT_BUNDLE_IDENTIFIER = ${BUNDLE};/" ios/Runner.xcodeproj/project.pbxproj
grep -q "PRODUCT_BUNDLE_IDENTIFIER = ${BUNDLE};" ios/Runner.xcodeproj/project.pbxproj

set_str CFBundleDisplayName "$NAME"

# 介面語言：少了這份清單 iOS 一律退回英文
$PB -c "Delete :CFBundleLocalizations" "$PLIST" 2>/dev/null || true
$PB -c "Add :CFBundleLocalizations array" "$PLIST"
i=0
for lang in zh-Hant zh-Hans en ja ko vi es pt-BR id th ar; do
  $PB -c "Add :CFBundleLocalizations:$i string $lang" "$PLIST"; i=$((i + 1))
done

# AdMob App ID（沒設定用 Google 官方 iOS 測試 ID；少了這個 SDK 啟動就會當掉）
set_str GADApplicationIdentifier "${ADMOB_IOS_APP_ID:-ca-app-pub-3940256099942544~1458002511}"

# 權限說明（少了會在要求權限時直接閃退）
set_str NSLocationWhenInUseUsageDescription "用概略位置計算磁偏角（真北），並在地圖八門顯示你的位置。"
set_str NSMotionUsageDescription "出行訣走路、跑步時計算步數。"
set_str NSCameraUsageDescription "拍攝住家平面圖，用來排宅盤九宮。"
set_str NSPhotoLibraryUsageDescription "從相簿選擇住家平面圖，用來排宅盤九宮。"
set_str NSPhotoLibraryAddUsageDescription "把分享卡片存到相簿。"
set_str NSCalendarsUsageDescription "把擇時結果加入行事曆。"
set_str NSCalendarsWriteOnlyAccessUsageDescription "把擇時結果加入行事曆。"
set_str NSCalendarsFullAccessUsageDescription "把擇時結果加入行事曆。"

# 匯出備份檔時讓「檔案」App 看得到（file_picker／share_plus）
$PB -c "Add :UISupportsDocumentBrowser bool true" "$PLIST" 2>/dev/null || true

# 最低版本 15（Firebase、AdMob、RevenueCat、Google Maps）
if [ ! -f ios/Podfile ]; then
  cp "$(dirname "$(command -v flutter)")/../packages/flutter_tools/templates/cocoapods/Podfile-ios" ios/Podfile
fi
sed -i '' "s/^# *platform :ios, .*/platform :ios, '15.0'/" ios/Podfile
grep -q "^platform :ios, '15.0'" ios/Podfile
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/' ios/Runner.xcodeproj/project.pbxproj

APPDELEGATE=ios/Runner/AppDelegate.swift
# 吉時推播：App 在前景時也顯示通知（flutter_local_notifications）
if ! grep -q UNUserNotificationCenter "$APPDELEGATE"; then
  perl -0pi -e 's/import UIKit\n/import UIKit\nimport UserNotifications\n/; s/(\n\s*)(return super\.application\(application, didFinishLaunchingWithOptions)/$1UNUserNotificationCenter.current().delegate = self$1$2/' "$APPDELEGATE"
  grep -q 'UNUserNotificationCenter.current().delegate = self' "$APPDELEGATE"
fi
# 地圖八門：有 iOS 金鑰（Secret MAPS_IOS_API_KEY）才設定；沒有時 App 以 MAPS_ENABLED=false 建置，只留地址搜尋
if [ -n "${MAPS_IOS_API_KEY:-}" ]; then
  perl -0pi -e 's/import UIKit\n/import UIKit\nimport GoogleMaps\n/; s/(\n\s*)(return super\.application\(application, didFinishLaunchingWithOptions)/$1GMSServices.provideAPIKey("$ENV{MAPS_IOS_API_KEY}")$1$2/' "$APPDELEGATE"
  grep -q 'GMSServices.provideAPIKey' "$APPDELEGATE"
  MAPS="地圖金鑰已設"
else
  echo "::warning::未設定 MAPS_IOS_API_KEY，iOS 地圖八門只顯示地址搜尋"
  MAPS="無地圖金鑰"
fi

# App 圖示：單一 1024 不透明圖（branding/ios，來源 icon_legacy.svg）
ICONSET=ios/Runner/Assets.xcassets/AppIcon.appiconset
rm -rf "$ICONSET"
cp -R branding/ios/AppIcon.appiconset "$ICONSET"

echo "iOS 設定完成：${BUNDLE}、11 種介面語言、AdMob ${ADMOB_IOS_APP_ID:+正式}${ADMOB_IOS_APP_ID:-測試} App ID、權限說明、${MAPS}、App 圖示"
