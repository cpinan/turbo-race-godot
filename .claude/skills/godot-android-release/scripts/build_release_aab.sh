#!/usr/bin/env bash
# Build a signed Godot Android App Bundle (.aab) for a Play Store release.
#
# Usage:
#   OUTPUT_AAB=builds/app_v8_release.aab ./build_release_aab.sh
#
# Env vars:
#   GODOT_BIN        Path to the Godot editor binary (default: macOS .app location)
#   PROJECT_DIR       Godot project root (default: .)
#   EXPORT_PRESET    Name of the export preset in export_presets.cfg (default: "Android Release")
#   OUTPUT_AAB         Destination .aab path, required
#
# Before running: bump version/code AND version/name in ALL presets of
# export_presets.cfg (see bump_version.sh) — Godot does not do this for you,
# and it's easy to bump one preset and forget the other.
set -euo pipefail

: "${GODOT_BIN:=/Applications/Godot.app/Contents/MacOS/Godot}"
: "${PROJECT_DIR:=.}"
: "${EXPORT_PRESET:=Android Release}"
: "${OUTPUT_AAB:?Set OUTPUT_AAB to the destination .aab path, e.g. builds/app_v8_release.aab}"

cd "$PROJECT_DIR"
mkdir -p "$(dirname "$OUTPUT_AAB")"

echo "==> Exporting '$EXPORT_PRESET' -> $OUTPUT_AAB"
"$GODOT_BIN" --headless --export-release "$EXPORT_PRESET" "$OUTPUT_AAB"

echo "==> Done:"
ls -la "$OUTPUT_AAB"

echo
echo "Next: verify_release.sh to confirm the versionCode/versionName actually baked in,"
echo "then package_native_symbols.sh to build the matching symbols zip."
