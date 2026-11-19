#!/usr/bin/env bash
# 私人解鎖版（FORCE_PREMIUM）改成獨立套件 com.lclab.qimen.personal，可與免費版同時裝在同一支手機
# （2026-11-19 使用者要求）。在建好免費版 APK、上架 AAB 之後才執行（會改 android/ 內容）。
# 桌面名稱加「私」；google-services.json 複製一份本 App 的設定給新套件（統計併入同一個 Firebase App）。
set -euo pipefail
PKG="com.lclab.qimen.personal"
GRADLE="android/app/build.gradle.kts"

sed -i "s/applicationId = \"com.lclab.qimen\"/applicationId = \"${PKG}\"/" "$GRADLE"
grep -q "applicationId = \"${PKG}\"" "$GRADLE" || { echo "::error::私人版套件名稱設定失敗"; exit 1; }

# 各語系桌面名稱：中文加「私」，其他語言加 " P"
for f in android/app/src/main/res/values*/app_name.xml; do
  case "$f" in
    *values-zh*|*values-b+zh*) sed -i -E 's#(<string name="app_name">)([^<]*)(</string>)#\1\2私\3#' "$f" ;;
    *) sed -i -E 's#(<string name="app_name">)([^<]*)(</string>)#\1\2 P\3#' "$f" ;;
  esac
done

JSON="android/app/google-services.json"
if [ -f "$JSON" ]; then
  python3 - "$JSON" "$PKG" << 'PYEOF'
import copy, json, sys
path, pkg = sys.argv[1], sys.argv[2]
d = json.load(open(path, encoding="utf-8-sig"))
pk = lambda c: c.get("client_info", {}).get("android_client_info", {}).get("package_name")
if not any(pk(c) == pkg for c in d["client"]):
    src = next(c for c in d["client"] if pk(c) == "com.lclab.qimen")
    c = copy.deepcopy(src)
    c["client_info"]["android_client_info"]["package_name"] = pkg
    d["client"].append(c)
json.dump(d, open(path, "w", encoding="utf-8"))
print("google-services.json：已加入 " + pkg)
PYEOF
fi
echo "私人版：${PKG}"
