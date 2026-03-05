#!/usr/bin/env bash
# Re-download and replace XCurl.dll (run after game updates)

set -euo pipefail

GAME_DIR="${GAME_DIR:-$HOME/vmshare/minecraft-bedrock}"

# Update version as needed: https://repo.msys2.org/mingw/mingw64/ (search for mingw-w64-x86_64-curl)
CURL_PKG="mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar.zst"
CURL_URL="https://repo.msys2.org/mingw/mingw64/$CURL_PKG"

echo "Downloading mingw curl ($CURL_PKG)..."
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"
curl -sLO "$CURL_URL"
zstd -d "$CURL_PKG"
tar xf "${CURL_PKG%.zst}"

cp "$GAME_DIR/XCurl.dll" "$GAME_DIR/XCurl.dll.bak" 2>/dev/null || true
cp mingw64/bin/libcurl-4.dll "$GAME_DIR/XCurl.dll"
rm -rf "$WORK_DIR"

echo "XCurl.dll replaced. Backup saved as XCurl.dll.bak"
