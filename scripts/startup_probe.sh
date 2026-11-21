#!/usr/bin/env bash
# 被 startup_probe.yml 呼叫：安裝 APK、冷啟動 5 次、把耗時與 logcat 重點寫成 annotation。
set -uo pipefail
APK="$1"
PKG=com.lclab.qimen
ACT="$PKG/com.lclab.qimen_compass.MainActivity"
adb install -r "$APK" >/dev/null || { echo "::error::安裝失敗"; exit 1; }
# 第 1 次（首次安裝後）與之後的冷啟動
for i in 1 2 3 4 5; do
  adb shell am force-stop $PKG; sleep 3
  adb logcat -c
  out=$(adb shell am start -W -n $ACT)
  t=$(echo "$out" | grep -E 'TotalTime' | awk '{print $2}')
  sleep 12
  log=$(adb logcat -d -v time)
  pid=$(adb shell pidof $PKG | tr -d '\r')
  st=$(echo "$log" | grep -m1 -E "qm_startup" | sed 's/.*qm_startup/qm_startup/')
  disp=$(echo "$log" | grep -m1 -E "Displayed $PKG" | sed 's/.*Displayed/Displayed/')
  full=$(echo "$log" | grep -m1 -E "Fully drawn $PKG" | sed 's/.*Fully drawn/Fully drawn/')
  skip=$(echo "$log" | grep -E "Skipped [0-9]+ frames" | sed 's/.*Skipped/Skipped/' | head -3 | tr '\n' ' ')
  echo "::notice title=冷啟動 $i::am TotalTime=${t}ms | $disp | $full | $st | $skip"
  if [ $i -eq 2 ]; then
    # 第 2 次的 App 行程 log（時間戳記）前 80 行，找空白期
    echo "$log" | grep -E "\( *$pid\)" | grep -vE "chatty|eglCodecCommon|EGL_emulation|gralloc" | head -80 > /tmp/applog.txt
    awk '{print substr($0,1,250)}' /tmp/applog.txt | while IFS= read -r l; do echo "::notice title=log::$l"; done | head -60
  fi
done
exit 0
