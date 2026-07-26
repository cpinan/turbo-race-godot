#!/usr/bin/env bash
# Confirm the versionCode/versionName actually baked into a Gradle-built AAB/APK
# match what you intend to upload. Catches "uploaded the wrong/stale file" and
# "forgot to bump one of the two presets" mistakes before Play Console does.
#
# Usage:
#   ./verify_release.sh                    # checks standardRelease
#   FLAVOR=standardDebug ./verify_release.sh
#
# Env vars:
#   PROJECT_DIR   Godot project root (default: .)
#   FLAVOR         Gradle product flavor + build type to check (default: standardRelease)
set -euo pipefail

: "${PROJECT_DIR:=.}"
: "${FLAVOR:=standardRelease}"

cd "$PROJECT_DIR"

MANIFEST=$(find android/build/build/intermediates/merged_manifests -iname "AndroidManifest.xml" -path "*${FLAVOR}*" 2>/dev/null | head -1)

if [[ -z "${MANIFEST:-}" ]]; then
  echo "Could not find a merged manifest for flavor '$FLAVOR' under android/build/build/intermediates/merged_manifests."
  echo "Run the export first (build_release_aab.sh / build_debug_install.sh), or check the flavor name with:"
  echo "  find android/build/build/intermediates/merged_manifests -maxdepth 2 -type d"
  exit 1
fi

echo "==> $MANIFEST"
grep -o 'versionCode="[0-9]*"' "$MANIFEST"
grep -o 'versionName="[^"]*"' "$MANIFEST"
