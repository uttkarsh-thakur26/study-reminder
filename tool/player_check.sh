#!/usr/bin/env bash
# Runs integration_test/player_check_test.dart on the emulator, taking a
# screenshot every 5 seconds and keeping the WebView's console log.
set -u
out=player-check
mkdir -p "$out"
adb logcat -c || true
( while true; do
    adb exec-out screencap -p > "$out/shot-$(date -u +%H%M%S).png" 2>/dev/null
    sleep 5
  done ) &
shots=$!
flutter test integration_test/player_check_test.dart -d emulator-5554 \
  --reporter expanded 2>&1 | tee "$out/test.log"
kill $shots || true
adb logcat -d -v time > "$out/logcat.txt" || true
grep -iE "chromium|console|youtube|flutter" "$out/logcat.txt" | tail -400 > "$out/logcat-web.txt" || true
# Artifacts can't always be fetched, so the log carries what matters.
echo "===== crashes ====="
grep -E "FATAL|AndroidRuntime|DEBUG   :|SIGSEGV|SIGABRT|backtrace|Abort message|Process .* has died|died, pid|lowmemorykiller|ANR in" "$out/logcat.txt" | head -150 || true
echo "===== flutter and web console ====="
grep -E " I/flutter| E/flutter|chromium|Console" "$out/logcat.txt" | grep -v "^--" | tail -250 || true
echo "===== screenshots ====="
ls "$out" | grep shot || true
exit 0
