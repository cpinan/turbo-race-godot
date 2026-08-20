#!/usr/bin/env bash
# Build a slimmed Godot web export template for this game.
#
# Why: CrazyGames measures RAW bytes, not gzipped, and marks anything over
# 20 MB ineligible for their mobile homepage. The stock 4.7.1 nothreads
# template is ~39.5 MB of wasm on its own — the game's own .pck is only ~4 MB,
# so no asset work can reach that target. Only a smaller engine can.
#
#   tools/build_web_template.sh              # build
#   tools/build_web_template.sh --install    # build, then install into Godot's
#                                            # export template dir as a custom
#                                            # template for the web presets
#
# Prerequisites (one-off):
#   brew install scons
#   git clone --depth 1 https://github.com/emscripten-core/emsdk.git ~/src/emsdk
#   cd ~/src/emsdk && ./emsdk install 4.0.11 && ./emsdk activate 4.0.11
#   git clone --depth 1 --branch 4.7.1-stable \
#       https://github.com/godotengine/godot.git ~/src/godot-4.7.1
#
# The emscripten version is NOT arbitrary: 4.0.11 is what Godot 4.7.1's own
# .github/workflows/web_builds.yml pins (EM_VERSION). Using "latest" is how you
# get a build that compiles and then misbehaves at runtime.

set -euo pipefail

GODOT_SRC="${GODOT_SRC:-$HOME/src/godot-4.7.1}"
EMSDK_DIR="${EMSDK_DIR:-$HOME/src/emsdk}"
GODOT_VERSION="4.7.1.stable"
JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

[ -d "$GODOT_SRC" ] || { echo "Godot source not found at $GODOT_SRC" >&2; exit 1; }
[ -f "$EMSDK_DIR/emsdk_env.sh" ] || { echo "emsdk not found at $EMSDK_DIR" >&2; exit 1; }

# shellcheck disable=SC1091
source "$EMSDK_DIR/emsdk_env.sh" >/dev/null 2>&1
echo "emcc: $(emcc --version | head -1)"

# --- What is switched off, and why it is safe for THIS game -----------------
#
# Kept deliberately, do not "optimise" these away:
#   javascript_eval  — JavaScriptBridge depends on it. Turning it off silently
#                      breaks the whole portal SDK facade in web/head/.
#   module_mp3       — every music track and SFX in the game is an MP3.
#                      (The module is `mp3`; it was `minimp3` in older docs.)
#   module_freetype  — Carton_Six.ttf and the default theme font.
#   module_webp      — Godot uses WebP internally for lossy imported textures.
#   godot_physics_2d — 2D physics server.
#   regex / zip / mbedtls — small, and used indirectly.
#
# text_server_adv -> text_server_fb is the single biggest non-3D win: the
# advanced text server embeds ICU + HarfBuzz data for complex script shaping
# (Arabic, Devanagari, ...). This game renders Latin text only, and its
# localisation is store-listing copy, not in-game strings.
MODULES=(
	disable_3d=yes

	module_text_server_adv_enabled=no
	module_text_server_fb_enabled=yes

	# 3D / XR
	module_camera_enabled=no
	module_csg_enabled=no
	module_gridmap_enabled=no
	module_openxr_enabled=no
	module_webxr_enabled=no
	module_mobile_vr_enabled=no
	module_gltf_enabled=no
	module_fbx_enabled=no
	module_lightmapper_rd_enabled=no
	module_raycast_enabled=no
	module_xatlas_unwrap_enabled=no
	module_meshoptimizer_enabled=no
	module_vhacd_enabled=no
	module_jolt_physics_enabled=no
	module_navigation_2d_enabled=no
	module_navigation_3d_enabled=no

	# Networking — the web build is entirely offline
	module_webrtc_enabled=no
	module_websocket_enabled=no
	module_multiplayer_enabled=no
	module_enet_enabled=no
	module_upnp_enabled=no
	module_jsonrpc_enabled=no

	# Media the game does not ship: no .ogg, no video
	module_theora_enabled=no
	module_vorbis_enabled=no
	module_ogg_enabled=no
	module_interactive_music_enabled=no

	# Editor-side / unused authoring features
	module_visual_shader_enabled=no
	module_noise_enabled=no
	module_msdfgen_enabled=no
	module_svg_enabled=no
	module_objectdb_profiler_enabled=no
)

cd "$GODOT_SRC"
echo "==> scons -j$JOBS (this takes a while)"
scons platform=web target=template_release \
	threads=no \
	production=yes optimize=size lto=full \
	javascript_eval=yes \
	"${MODULES[@]}" \
	-j"$JOBS"

ARTIFACT="$GODOT_SRC/bin/godot.web.template_release.wasm32.nothreads.zip"
[ -f "$ARTIFACT" ] || { echo "expected artifact missing: $ARTIFACT" >&2; exit 1; }

echo
echo "==> built: $ARTIFACT"
unzip -l "$ARTIFACT" | awk '/godot\.(wasm|js)/ {printf "    %-34s %10.2f MB\n", $4, $1/1048576}'

if [ "${1:-}" = "--install" ]; then
	DEST="$HOME/Library/Application Support/Godot/export_templates/$GODOT_VERSION"
	cp "$ARTIFACT" "$DEST/web_nothreads_release_slim.zip"
	echo "==> installed to $DEST/web_nothreads_release_slim.zip"
	echo "    Point the web presets' custom_template/release at it, then rebuild"
	echo "    and RE-TEST: this is a different engine binary than the one the"
	echo "    published builds were verified against."
fi
