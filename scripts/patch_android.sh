#!/usr/bin/env bash
# CI 產生 android/ 後套用 App 設定：桌面名稱、套件名稱、不鎖方向、上傳金鑰簽署（比照謙卦 iching-cards）。
# 上傳金鑰的四個 Secrets 尚未設定時，改用除錯金鑰簽署（只能自己側載測試）。
set -euo pipefail

MANIFEST="android/app/src/main/AndroidManifest.xml"
GRADLE="android/app/build.gradle.kts"
APP_ID="com.lclab.qimen"
APP_LABEL="奇門羅盤"

sed -i "s/android:label=\"[^\"]*\"/android:label=\"${APP_LABEL}\"/" "$MANIFEST"
# 套件名稱（Play 身分，上傳後不能改）：只改 applicationId，namespace 維持 flutter create 的值
sed -i "s/applicationId = \"[^\"]*\"/applicationId = \"${APP_ID}\"/" "$GRADLE"
grep -q "applicationId = \"${APP_ID}\"" "$GRADLE" && echo "套件名稱：${APP_ID}" || { echo "::error::套件名稱設定失敗"; exit 1; }

# 羅盤真北：只要概略位置（不要求精確位置，配合 2027 位置權限新規）
grep -q ACCESS_COARSE_LOCATION "$MANIFEST" || sed -i 's#<application#<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>\n    <application#' "$MANIFEST"
grep -q ACCESS_COARSE_LOCATION "$MANIFEST" && echo "權限：ACCESS_COARSE_LOCATION" || { echo "::error::位置權限設定失敗"; exit 1; }

# 不鎖方向、不限制調整大小（Play Console 對大螢幕的要求）
sed -i -E 's/[[:space:]]*android:(screenOrientation|resizeableActivity)="[^"]*"//g' "$MANIFEST"

if [ -z "${ANDROID_KEYSTORE_BASE64:-}" ]; then
  echo "::warning::尚未設定上傳金鑰 Secrets，本次以除錯金鑰簽署（安裝新版前須先移除舊版）"
  echo "SIGNING=除錯金鑰" >> "$GITHUB_ENV"
  exit 0
fi

echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/upload-key.jks
cat > android/key.properties << PROPS
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyPassword=$ANDROID_KEY_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
storeFile=upload-key.jks
PROPS

python3 - "$GRADLE" << 'PYEOF'
import re, sys
path = sys.argv[1]
s = open(path, encoding="utf-8").read()
if "qimen_release_signing" not in s:
    s = "import java.util.Properties\nimport java.io.FileInputStream\n\n" + s
    s = s.replace("android {", '''// qimen_release_signing
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {''', 1)
    s = s.replace("    buildTypes {", '''    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }

    buildTypes {''', 1)
    new = re.sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
                 'signingConfig = signingConfigs.getByName("release")', s)
    if new == s:
        new = re.sub(r'(release\s*\{)', r'\1\n            signingConfig = signingConfigs.getByName("release")', s, count=1)
    s = new
open(path, "w", encoding="utf-8").write(s)
PYEOF

echo "SIGNING=上傳金鑰" >> "$GITHUB_ENV"
echo "已設定上傳金鑰簽署"
