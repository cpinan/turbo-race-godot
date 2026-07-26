#!/usr/bin/env bash
# Build a Godot Android debug APK, install it on the connected device, and launch it.
#
# Usage:
#   PACKAGE_NAME=com.example.app ./build_debug_install.sh
#
# Env vars (all but PACKAGE_NAME have sane defaults):
#   GODOT_BIN        Path to the Godot editor binary (default: macOS .app location)
#   PROJECT_DIR       Godot project root, i.e. the dir containing project.godot (default: .)
#   EXPORT_PRESET    Name of the export preset in export_presets.cfg (default: "Android Debug")
#   OUTPUT_APK        Where to write the built APK (default: /tmp/android_debug.apk)
#   PACKAGE_NAME       Android application id, required (e.g. com.example.app)
#   LAUNCH_ACTIVITY   Full activity class to launch (default: Godot's standard launcher)
set -euo pipefail

: "${GODOT_BIN:=/Applications/Godot.app/Contents/MacOS/Godot}"
: "${PROJECT_DIR:=.}"
: "${EXPORT_PRESET:=Android Debug}"
: "${OUTPUT_APK:=/tmp/android_debug.apk}"
: "${PACKAGE_NAME:?Set PACKAGE_NAME to the Android package id, e.g. com.example.app}"
: "${LAUNCH_ACTIVITY:=com.godot.game.GodotAppLauncher}"

cd "$PROJECT_DIR"

echo "==> Exporting '$EXPORT_PRESET' -> $OUTPUT_APK"
"$GODOT_BIN" --headless --export-debug "$EXPORT_PRESET" "$OUTPUT_APK"

echo "==> Installing on connected device"
if ! adb install -r "$OUTPUT_APK"; then
  cat <<EOF
Install failed. If this is INSTALL_FAILED_UPDATE_INCOMPATIBLE, a build signed with
a different key (usually a release-signed build from the Play Store) is already on
the device — debug builds use Godot's debug keystore, which never matches the
release keystore.

This is NOT auto-resolved by this script because it requires uninstalling the
existing app, which wipes its local data. If that's acceptable, run:
  adb uninstall $PACKAGE_NAME
then re-run this script.
EOF
  exit 1
fi

echo "==> Launching $PACKAGE_NAME/$LAUNCH_ACTIVITY"
adb shell am start -n "$PACKAGE_NAME/$LAUNCH_ACTIVITY"
