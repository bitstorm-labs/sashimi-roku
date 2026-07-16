#!/bin/bash
# Build, sideload, sign, and download a store-ready .pkg from the dev device.
# Signing REQUIRES a physical Roku (no offline signer exists) — this script is
# the "release" step; cloud CI only builds the unsigned zip artifact.
# Password comes from macOS Keychain (service: sashimi-roku-signing).
set -euo pipefail
DEVICE="${ROKU_DEV_TARGET:-192.168.86.30}"
DEVPW="${ROKU_DEV_PASSWORD:-1234}"
VERSION=$(grep -E "^(major|minor|build)_version" manifest | cut -d= -f2 | paste -sd. -)
SIGNPW=$(security find-generic-password -s sashimi-roku-signing -w)

echo "==> build + sideload"
npm run --silent package >/dev/null
curl -sf --digest -u "rokudev:$DEVPW" -F mysubmit=Replace -F archive=@sashimi.zip \
  "http://$DEVICE/plugin_install" | grep -q "Install Success" || { echo "sideload failed"; exit 1; }

echo "==> sign + package v$VERSION"
RESP=$(curl -sf --digest -u "rokudev:$DEVPW" \
  -F mysubmit=Package -F "app_name=Sashimi/$VERSION" \
  -F "passwd=$SIGNPW" -F "pkg_time=$(date +%s)000" \
  "http://$DEVICE/plugin_package")
PKGPATH=$(echo "$RESP" | grep -oE '"pkgPath":"[^"]+"' | head -1 | cut -d'"' -f4)
[ -z "$PKGPATH" ] && { echo "packaging failed:"; echo "$RESP" | grep -oE '"text":"[^"]*"' | head -3; exit 1; }

OUT="out/sashimi-signed-$VERSION.pkg"
curl -sf --digest -u "rokudev:$DEVPW" -o "$OUT" "http://$DEVICE/$PKGPATH"
echo "==> $OUT ($(stat -f%z "$OUT") bytes) — upload at developer.roku.com"
