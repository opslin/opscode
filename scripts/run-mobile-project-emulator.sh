#!/bin/sh
# Build a separately named debug app for the local fake relay; never changes the real app or Mac data.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TASK_TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/opscode-project-e2e.XXXXXX")
TASK_SERIAL=${OPSCODE_TEST_SERIAL:-emulator-5556}
TASK_ADB=${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}/platform-tools/adb
cleanup() {
  "$TASK_ADB" -s "$TASK_SERIAL" uninstall com.opscode.mobile.fixture >/dev/null 2>&1 || true
  rm -rf "$TASK_TMP_DIR"
}
trap cleanup EXIT HUP INT TERM
rsync -a --exclude .gradle --exclude build --exclude app/build "$ROOT/mobile/android/" "$TASK_TMP_DIR/"
python3 - "$TASK_TMP_DIR" <<'PY'
import pathlib,sys
r=pathlib.Path(sys.argv[1]); p=r/'app/build.gradle.kts'; p.write_text(p.read_text().replace('applicationId = "com.opscode.mobile"','applicationId = "com.opscode.mobile.fixture"'))
p=r/'app/src/main/java/com/opscode/mobile/Companion.kt'; p.write_text(p.read_text().replace('https://relay.shotlin.in','http://10.0.2.2:18799'))
p=r/'app/src/main/java/com/opscode/mobile/RelayConnection.kt'; p.write_text(p.read_text().replace('RELAY_URL.replace("https:", "wss:")','RELAY_URL.replace("https:", "wss:").replace("http:", "ws:")'))
p=r/'app/src/main/AndroidManifest.xml'; p.write_text(p.read_text().replace('android:usesCleartextTraffic="false"','android:usesCleartextTraffic="true"'))
p=r/'app/src/debug/AndroidManifest.xml'; p.parent.mkdir(parents=True,exist_ok=True); p.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application><activity android:name="com.opscode.mobile.DebugPairActivity" android:exported="true" /></application></manifest>')
p=r/'app/src/debug/java/com/opscode/mobile/DebugPairActivity.kt'; p.parent.mkdir(parents=True,exist_ok=True); p.write_text('''package com.opscode.mobile
import android.app.Activity
import android.content.Intent
import android.os.Bundle
class DebugPairActivity : Activity() {
 override fun onCreate(state: Bundle?) { super.onCreate(state); val invite=intent.getStringExtra("invite") ?: return finish(); Thread { try { val link=Desktop.pair(Invite.decode(invite)); Links.save(applicationContext,link); runOnUiThread { finish() } } catch (e:Exception) { android.util.Log.e("E2EPair",e.message ?: "pair failed"); runOnUiThread { finish() } } }.start() }
}
''')
PY
"$TASK_TMP_DIR/gradlew" -p "$TASK_TMP_DIR" :app:assembleDebug
"$TASK_ADB" -s "$TASK_SERIAL" install -r "$TASK_TMP_DIR/app/build/outputs/apk/debug/app-debug.apk"
node "$ROOT/scripts/test-mobile-project-emulator.mjs"
