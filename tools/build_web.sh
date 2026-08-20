#!/usr/bin/env bash
# Build a web variant and package it for upload.
#
#   tools/build_web.sh owned              # itch.io / GitHub Pages / your site
#   tools/build_web.sh crazygames         # CrazyGames (their SDK, no store link)
#   tools/build_web.sh gamedistribution   # GameDistribution (their SDK)
#   tools/build_web.sh all
#
# Output: builds/web[-variant]/ plus builds/turbo-race-web[-variant]-<ver>.zip
# with index.html at the zip root, which is what every HTML5 portal expects.
#
# See docs/WEB_PORTALS.md for what each variant is allowed to contain and why
# they cannot be one build.

set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

VERSION="$(sed -n 's/^version\/name="\(.*\)"$/\1/p' export_presets.cfg | head -1)"
[ -n "$VERSION" ] || { echo "could not read version/name from export_presets.cfg" >&2; exit 1; }

[ -x "$GODOT" ] || { echo "Godot not found at $GODOT (override with GODOT=...)" >&2; exit 1; }

build_one() {
	local variant="$1" preset outdir zip

	case "$variant" in
		owned)            preset="Web";                   outdir="builds/web" ;;
		crazygames)       preset="Web CrazyGames";        outdir="builds/web-crazygames" ;;
		gamedistribution) preset="Web GameDistribution";  outdir="builds/web-gamedistribution" ;;
		*) echo "unknown variant: $variant (owned|crazygames|gamedistribution|all)" >&2; return 1 ;;
	esac

	if [ "$variant" = "owned" ]; then
		zip="builds/turbo-race-web-${VERSION}.zip"
	else
		zip="builds/turbo-race-web-${variant}-${VERSION}.zip"
		# A stale shell silently ships the wrong SDK — catch it before export.
		python3 tools/gen_web_shells.py --check
	fi

	echo "==> $preset -> $outdir"
	rm -rf "$outdir"
	mkdir -p "$outdir"
	"$GODOT" --headless --path . --export-release "$preset" "$outdir/index.html" >/dev/null

	[ -f "$outdir/index.wasm" ] || { echo "export produced no wasm — check the preset" >&2; return 1; }

	rm -f "$zip"
	( cd "$outdir" && zip -q -9 -r "../../$zip" . -x "*.import" "*.DS_Store" )

	local raw gz
	raw=$(du -h "$zip" | cut -f1)
	gz=$(cat "$outdir"/index.wasm "$outdir"/index.pck "$outdir"/index.js | gzip -9 -c | wc -c | awk '{printf "%.1f MB", $1/1048576}')
	echo "    $zip  ($raw on disk, ~$gz transferred gzipped)"

	if [ "$variant" = "gamedistribution" ] && grep -q GD_GAME_ID_PLACEHOLDER "$outdir/index.html"; then
		echo "    WARNING: GD_GAME_ID_PLACEHOLDER is still in the shell — the SDK will serve nothing."
		echo "             Set the real game id in web/head/gamedistribution.html, regenerate, rebuild."
	fi
}

if [ "${1:-}" = "all" ]; then
	for v in owned crazygames gamedistribution; do build_one "$v"; done
elif [ $# -eq 1 ]; then
	build_one "$1"
else
	echo "usage: $0 owned|crazygames|gamedistribution|all" >&2
	exit 1
fi
