#!/usr/bin/env bash
# Bump version/code and version/name in ALL presets of export_presets.cfg.
#
# Godot's Android export presets duplicate version/code and version/name per
# preset (one block per preset, e.g. "Android Debug" and "Android Release").
# Bumping only the preset you're about to export leaves the other stale for
# next time — this script updates every occurrence in the file at once.
#
# Usage:
#   ./bump_version.sh <version_code> <version_name>
#   ./bump_version.sh 8 1.4.0
#
# Env vars:
#   PROJECT_DIR    Godot project root (default: .)
#   PRESETS_FILE   Path to the presets file, relative to PROJECT_DIR (default: export_presets.cfg)
set -euo pipefail

: "${PROJECT_DIR:=.}"
: "${PRESETS_FILE:=export_presets.cfg}"
CODE="${1:?Usage: bump_version.sh <version_code> <version_name>}"
NAME="${2:?Usage: bump_version.sh <version_code> <version_name>}"

cd "$PROJECT_DIR"
[[ -f "$PRESETS_FILE" ]] || { echo "$PRESETS_FILE not found in $PROJECT_DIR"; exit 1; }

cp "$PRESETS_FILE" "${PRESETS_FILE}.bak"

# BSD sed (macOS) requires -i '' as two args; GNU sed requires -i with none.
if sed --version >/dev/null 2>&1; then
  sed -i -E \
    -e "s/^version\/code=.*/version\/code=${CODE}/" \
    -e "s/^version\/name=\".*\"/version\/name=\"${NAME}\"/" \
    "$PRESETS_FILE"
else
  sed -i '' -E \
    -e "s/^version\/code=.*/version\/code=${CODE}/" \
    -e "s/^version\/name=\".*\"/version\/name=\"${NAME}\"/" \
    "$PRESETS_FILE"
fi

echo "==> Bumped version/code=${CODE} version/name=\"${NAME}\" in every preset of $PRESETS_FILE"
grep -n 'version/code=\|version/name=' "$PRESETS_FILE"
echo "Backup saved at ${PRESETS_FILE}.bak — export_presets.cfg is normally gitignored (keystore creds), diff/delete the backup manually."
