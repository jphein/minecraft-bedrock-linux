#!/usr/bin/env bash
# Re-download and replace XCurl.dll (run after game updates)

set -euo pipefail

GAME_DIR="${GAME_DIR:-$HOME/vmshare/minecraft-bedrock}"

echo "Downloading latest mingw curl..."
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
curl -sLO https://repo.msys2.org/mingw/mingw64/mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar.zst
zstd -d mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar.zst
tar xf mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar

cp "$GAME_DIR/XCurl.dll" "$GAME_DIR/XCurl.dll.bak" 2>/dev/null || true
cp mingw64/bin/libcurl-4.dll "$GAME_DIR/XCurl.dll"
rm -rf "$TMPDIR"

echo "XCurl.dll replaced. Backup saved as XCurl.dll.bak"
