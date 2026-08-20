#!/usr/bin/env bash
# Serve a web build locally for testing, over HTTP and HTTPS.
#
#   tools/serve_web.sh                       # builds/web on :8099 (http) + :8443 (https)
#   tools/serve_web.sh builds/web-crazygames # any variant
#
# Why HTTPS for a local test server: Godot's web export requires a browser
# "secure context" (AudioWorklet and crypto.subtle need one). Browsers grant
# that to localhost automatically but NEVER to a plain-HTTP LAN address, so
# opening http://192.168.x.x:8099 on a phone fails with
#
#   The following features required to run Godot projects on the Web are
#   missing: Secure Context - Check web server configuration (use HTTPS)
#
# That is a local-testing artifact only — itch.io and GitHub Pages are both
# HTTPS, so real players never hit it.
#
# Three ways to test, cleanest first:
#   desktop          http://localhost:8099
#   Android device   adb reverse tcp:8099 tcp:8099, then http://localhost:8099
#                    on the device — localhost is a secure context, no cert
#   any device/wifi  https://<lan-ip>:8443 and click through the cert warning

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="${1:-builds/web}"
HTTP_PORT="${HTTP_PORT:-8099}"
HTTPS_PORT="${HTTPS_PORT:-8443}"
CERT_DIR="${TMPDIR:-/tmp}/turborace-devcert"

cd "$REPO"
[ -f "$DIR/index.html" ] || { echo "no build at $DIR — run tools/build_web.sh first" >&2; exit 1; }

LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)"

# Throwaway cert, regenerated when the LAN IP changes so the SAN always matches.
mkdir -p "$CERT_DIR"
if [ ! -f "$CERT_DIR/cert.pem" ] || ! openssl x509 -in "$CERT_DIR/cert.pem" -noout -text 2>/dev/null | grep -q "$LAN_IP"; then
	echo "generating dev cert for $LAN_IP"
	openssl req -x509 -newkey rsa:2048 -keyout "$CERT_DIR/key.pem" -out "$CERT_DIR/cert.pem" \
		-days 30 -nodes -subj "/CN=$LAN_IP" \
		-addext "subjectAltName=IP:$LAN_IP,DNS:localhost,IP:127.0.0.1" 2>/dev/null
fi

cat > "$CERT_DIR/https_server.py" <<'PY'
import http.server, ssl, sys, functools
directory, port, cert, key = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=directory)
httpd = http.server.ThreadingHTTPServer(("0.0.0.0", port), handler)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(cert, key)
httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
httpd.serve_forever()
PY

cleanup() { kill 0 2>/dev/null || true; }
trap cleanup EXIT INT TERM

python3 -m http.server "$HTTP_PORT" --directory "$DIR" >/dev/null 2>&1 &
python3 "$CERT_DIR/https_server.py" "$REPO/$DIR" "$HTTPS_PORT" "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem" >/dev/null 2>&1 &

# Android devices/emulators: map the host port so the device can use localhost,
# which is a secure context and needs no certificate at all.
if command -v adb >/dev/null 2>&1; then
	for d in $(adb devices | awk 'NR>1 && $2=="device" {print $1}'); do
		adb -s "$d" reverse "tcp:$HTTP_PORT" "tcp:$HTTP_PORT" >/dev/null 2>&1 \
			&& echo "adb reverse set up on $d"
	done
fi

echo
echo "serving $DIR"
echo "  desktop        http://localhost:$HTTP_PORT"
echo "  android device http://localhost:$HTTP_PORT   (via adb reverse, no cert)"
echo "  phone on wifi  https://$LAN_IP:$HTTPS_PORT   (accept the cert warning)"
echo
echo "ctrl-c to stop"
wait
