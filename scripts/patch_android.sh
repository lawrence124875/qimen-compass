#!/usr/bin/env bash
# CI 產生 android/ 後套用 App 設定：桌面名稱與圖示、套件名稱、不鎖方向、上傳金鑰簽署（比照謙卦 iching-cards）。
# 上傳金鑰的四個 Secrets 尚未設定時，改用除錯金鑰簽署（只能自己側載測試）。
set -euo pipefail

MANIFEST="android/app/src/main/AndroidManifest.xml"
GRADLE="android/app/build.gradle.kts"
APP_ID="com.lclab.qimen"
# 圖示與各語系桌面名稱：branding/android/res（由 branding/*.svg 產生，見 branding/README.md）
cp -r branding/android/res/. android/app/src/main/res/
sed -i 's/android:label="[^"]*"/android:label="@string\/app_name"/' "$MANIFEST"
grep -q 'android:label="@string/app_name"' "$MANIFEST" && [ -f android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml ] \
  && echo "圖示＋各語系名稱已套用" || { echo "::error::圖示或名稱設定失敗"; exit 1; }
# 套件名稱（Play 身分，上傳後不能改）：只改 applicationId，namespace 維持 flutter create 的值
sed -i "s/applicationId = \"[^\"]*\"/applicationId = \"${APP_ID}\"/" "$GRADLE"
grep -q "applicationId = \"${APP_ID}\"" "$GRADLE" && echo "套件名稱：${APP_ID}" || { echo "::error::套件名稱設定失敗"; exit 1; }

# 羅盤真北：只要概略位置（不要求精確位置，配合 2027 位置權限新規）
grep -q ACCESS_COARSE_LOCATION "$MANIFEST" || sed -i 's#<application#<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>\n    <application#' "$MANIFEST"
grep -q ACCESS_COARSE_LOCATION "$MANIFEST" && echo "權限：ACCESS_COARSE_LOCATION" || { echo "::error::位置權限設定失敗"; exit 1; }

# 地圖八門（google_maps_flutter）：目前位置要較精確（Android 12+ 使用者仍可只給概略位置）；
# Maps API key 來自 Secret MAPS_API_KEY，沒設時不寫入，App 端 MAPS_ENABLED=false 不建立地圖（否則 SDK 會當）
grep -q ACCESS_FINE_LOCATION "$MANIFEST" || sed -i 's#<application#<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n    <application#' "$MANIFEST"
if [ -n "${MAPS_API_KEY:-}" ]; then
  grep -q "com.google.android.geo.API_KEY" "$MANIFEST" || \
    sed -i "s#</application>#    <meta-data android:name=\"com.google.android.geo.API_KEY\" android:value=\"${MAPS_API_KEY}\"/>\n    </application>#" "$MANIFEST"
  grep -q "com.google.android.geo.API_KEY" "$MANIFEST" && echo "Maps API key 已寫入" || { echo "::error::Maps API key 寫入失敗"; exit 1; }
else
  echo "::warning::尚未設定 MAPS_API_KEY，地圖八門只保留地址搜尋"
fi

# 不鎖方向、不限制調整大小（Play Console 對大螢幕的要求）
sed -i -E 's/[[:space:]]*android:(screenOrientation|resizeableActivity)="[^"]*"//g' "$MANIFEST"

# 通知與計步（出行訣、吉時推播；比照謙卦的坑：兩個 receiver＋desugaring＋ProGuard 保留 Gson TypeToken，
# 否則 release 版排程「成功」卻不跳）。不加 SCHEDULE_EXACT_ALARM。
python3 - "$MANIFEST" "$GRADLE" << 'PYEOF'
import sys
manifest, gradle = sys.argv[1], sys.argv[2]
m = open(manifest, encoding="utf-8").read()
if "ScheduledNotificationReceiver" not in m:
    perms = "".join(f'    <uses-permission android:name="android.permission.{p}"/>\n' for p in
                    ["POST_NOTIFICATIONS", "RECEIVE_BOOT_COMPLETED", "ACTIVITY_RECOGNITION"])
    m = m.replace("    <application", perms + "    <application", 1)
    m = m.replace("    </application>", '''        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>''', 1)
    open(manifest, "w", encoding="utf-8").write(m)
g = open(gradle, encoding="utf-8").read()
if "isCoreLibraryDesugaringEnabled" not in g:
    g = g.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
    g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    open(gradle, "w", encoding="utf-8").write(g)
PYEOF
grep -q "ScheduledNotificationBootReceiver" "$MANIFEST" && grep -q "isCoreLibraryDesugaringEnabled" "$GRADLE" \
  && echo "通知設定：receiver＋desugaring 已加入" || { echo "::error::通知設定失敗"; exit 1; }
# 擇時擇日「加入行事曆」（add_2_calendar）：Android 11+ 需宣告可查詢新增行程的 intent
python3 - "$MANIFEST" << 'PYEOF'
import sys
p = sys.argv[1]
m = open(p, encoding="utf-8").read()
intent = ('        <intent>\n'
          '            <action android:name="android.intent.action.INSERT" />\n'
          '            <data android:mimeType="vnd.android.cursor.item/event" />\n'
          '        </intent>\n')
if "vnd.android.cursor.item/event" not in m:
    if "<queries>" in m:
        m = m.replace("<queries>\n", "<queries>\n" + intent, 1)
    else:
        m = m.replace("</manifest>", "    <queries>\n" + intent + "    </queries>\n</manifest>", 1)
    open(p, "w", encoding="utf-8").write(m)
PYEOF
grep -q "vnd.android.cursor.item/event" "$MANIFEST" && echo "行事曆 intent 已宣告" || { echo "::error::行事曆 intent 宣告失敗"; exit 1; }
cat >> android/app/proguard-rules.pro << 'PRO'
# flutter_local_notifications 以 Gson 存排程，release 混淆後需保留 TypeToken
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
PRO

if [ -z "${ANDROID_KEYSTORE_BASE64:-}" ]; then
  echo "::warning::尚未設定上傳金鑰 Secrets，本次以固定測試金鑰簽署（可覆蓋安裝）"
  echo "SIGNING=固定測試金鑰" >> "$GITHUB_ENV"
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
