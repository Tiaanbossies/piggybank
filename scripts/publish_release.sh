#!/usr/bin/env bash
# Publishes an already-built release APK (see scripts/build_release.sh) to the
# production server's Tailscale-only download endpoint, so it can be
# installed on a phone remotely without a USB cable or Play Store listing.
#
# Ships two copies on the server:
#   - piggybank-v<version>.apk   (versioned, kept for history/rollback)
#   - piggybank-latest.apk       (overwritten each run -- what the phone opens)
# plus latest.json (version/build/date) alongside them, for a future in-app
# "update available" check -- not consumed by anything yet.
#
# Requires: scripts/build_release.sh already run for this version, and SSH
# access to mcp@100.121.165.7 (same host as piggybank-backend).
set -euo pipefail

cd "$(dirname "$0")/.."

SERVER="mcp@100.121.165.7"
REMOTE_DIR="~/piggybank-backend/downloads"
# Plain HTTP on the Tailscale MagicDNS name (falls back to the raw Tailscale
# IP below), not the fynboscreative.co.za domain -- that domain's public DNS
# points to an unrelated server (see lib/core/api/api_config.dart's comment
# on this same fact), so Caddy can never get a TLS cert for it here. Caddy's
# /downloads site block (piggybank-backend's Caddyfile) matches both
# addresses. This matches how the app itself already talks to the backend
# (http://100.121.165.7:8000/api).
DOWNLOAD_HOST="http://tiaanbossies-h81m-ds2.tail886b94.ts.net/downloads"
DOWNLOAD_HOST_IP_FALLBACK="http://100.121.165.7/downloads"

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)
BUILD_NUMBER=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f2)
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

if [ ! -f "$APK_PATH" ]; then
  echo "error: $APK_PATH not found -- run scripts/build_release.sh first" >&2
  exit 1
fi

VERSIONED_NAME="piggybank-v${VERSION}+${BUILD_NUMBER}.apk"
BUILT_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "Publishing ${VERSIONED_NAME} (version ${VERSION}, build ${BUILD_NUMBER})..."

ssh "$SERVER" "mkdir -p ${REMOTE_DIR}"
scp "$APK_PATH" "${SERVER}:${REMOTE_DIR}/${VERSIONED_NAME}"
ssh "$SERVER" "cp ${REMOTE_DIR}/${VERSIONED_NAME} ${REMOTE_DIR}/piggybank-latest.apk"
ssh "$SERVER" "cat > ${REMOTE_DIR}/latest.json" <<EOF
{
  "version": "${VERSION}",
  "buildNumber": "${BUILD_NUMBER}",
  "filename": "${VERSIONED_NAME}",
  "publishedAt": "${BUILT_AT}"
}
EOF

echo
echo "Done. On the phone (connected to Tailscale), open in a browser:"
echo "  ${DOWNLOAD_HOST}/piggybank-latest.apk"
echo "  (fallback if MagicDNS doesn't resolve: ${DOWNLOAD_HOST_IP_FALLBACK}/piggybank-latest.apk)"
echo "Tap the downloaded file to install (enable \"install unknown apps\" for the browser if prompted)."
