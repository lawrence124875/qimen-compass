#!/usr/bin/env bash
# Wear OS 手錶羅盤（HANDOFF §12 1.3.0）：把 android_extra/wear 放進 CI 產生的 android/ 成為 :wear 模組。
# 外掛沿用 app 模組的 Android／Kotlin 外掛（不含 Flutter、Firebase），版本由 settings.gradle.kts 決定。
set -euo pipefail

rm -rf android/wear
cp -r android_extra/wear android/wear
# 圖示與各語系名稱沿用手機版
cp -r branding/android/res/. android/wear/src/main/res/

PLUGINS=$(python3 - << 'PYEOF'
import re
s = open("android/app/build.gradle.kts", encoding="utf-8").read()
block = re.search(r"plugins\s*\{(.*?)\}", s, re.S).group(1)
keep = [l.strip() for l in block.splitlines()
        if re.search(r'id\("(com\.android\.application|kotlin-android|org\.jetbrains\.kotlin\.android)"\)', l)]
print("\n".join("    " + l for l in keep))
PYEOF
)
[ -n "$PLUGINS" ] || { echo "::error::找不到 app 模組的 Android 外掛"; exit 1; }
python3 - "$PLUGINS" << 'PYEOF'
import sys
p = "android/wear/build.gradle.kts"
s = open(p, encoding="utf-8").read().replace("__PLUGINS__", sys.argv[1])
open(p, "w", encoding="utf-8").write(s)
PYEOF
grep -q 'include(":wear")' android/settings.gradle.kts || echo 'include(":wear")' >> android/settings.gradle.kts
echo "手錶模組已加入（外掛：$(echo $PLUGINS | tr -s ' ')）"
