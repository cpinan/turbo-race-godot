#!/usr/bin/env bash
# Package native .so debug symbols into the zip format Play Console requires,
# for upload under Release > App bundles > Native debug symbols.
#
# Two rules Play Console silently enforces and will reject on:
#   1. Zip root must be armeabi-v7a/ and arm64-v8a/ directly — NOT wrapped in a
#      lib/ folder. ("The native debug symbols contain an invalid directory lib")
#   2. Include ONLY device ABIs (armeabi-v7a, arm64-v8a) — never x86/x86_64
#      (those are emulator-only ABIs and bloat/pollute the symbol map).
#
# Also: zip APPENDS to an existing file rather than overwriting, so re-running
# this against a stale output produces a corrupt zip with duplicate entries.
# This script always deletes the destination first.
#
# Usage:
#   OUTPUT_ZIP=builds/app_v8_symbols.zip ./package_native_symbols.sh
#
# Env vars:
#   PROJECT_DIR   Godot project root (default: .)
#   FLAVOR         Gradle product flavor + build type, e.g. standardRelease (default)
#   TASK_DIR       Gradle task output dir name under merged_native_libs/<FLAVOR>/
#                  (default: mergeStandardReleaseNativeLibs — matches Godot's default
#                  "standard" product flavor; adjust if your project defines others)
#   OUTPUT_ZIP     Destination zip path, required
set -euo pipefail

: "${PROJECT_DIR:=.}"
: "${FLAVOR:=standardRelease}"
: "${TASK_DIR:=mergeStandardReleaseNativeLibs}"
: "${OUTPUT_ZIP:?Set OUTPUT_ZIP to the destination zip path, e.g. builds/app_v8_symbols.zip}"

cd "$PROJECT_DIR"
SYMBOLS_DIR="android/build/build/intermediates/merged_native_libs/${FLAVOR}/${TASK_DIR}/out/lib"

if [[ ! -d "$SYMBOLS_DIR" ]]; then
  echo "Symbols dir not found: $SYMBOLS_DIR"
  echo "Run the release AAB export first (build_release_aab.sh) — this is a Gradle build intermediate,"
  echo "not something Godot writes directly. If your AGP/Godot version differs, find the real path with:"
  echo "  find android/build/build/intermediates/merged_native_libs -maxdepth 4 -type d"
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_ZIP")"
OUTPUT_ZIP_ABS="$(cd "$(dirname "$OUTPUT_ZIP")" && pwd)/$(basename "$OUTPUT_ZIP")"

rm -f "$OUTPUT_ZIP_ABS"

pushd "$SYMBOLS_DIR" >/dev/null
ABIS=()
for abi in armeabi-v7a arm64-v8a; do
  [[ -d "$abi" ]] && ABIS+=("$abi")
done
if [[ ${#ABIS[@]} -eq 0 ]]; then
  echo "Neither armeabi-v7a nor arm64-v8a found under $SYMBOLS_DIR"
  popd >/dev/null
  exit 1
fi
zip -r "$OUTPUT_ZIP_ABS" "${ABIS[@]}"
popd >/dev/null

echo "==> Verifying zip root structure (should be armeabi-v7a/... and arm64-v8a/... at root):"
unzip -l "$OUTPUT_ZIP_ABS"
echo "==> Done: $OUTPUT_ZIP_ABS"
