#!/usr/bin/env bash
# Setup script for Minecraft Bedrock on Ubuntu Linux via WineGDK
# Run this after copying game files from Windows and building WineGDK from source.

set -euo pipefail

WINEGDK_DIR="${WINEGDK_DIR:-$HOME/Projects/WineGDK/install}"
GAME_DIR="${GAME_DIR:-$HOME/Games/minecraft-bedrock/game}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/minecraft-bedrock/prefix}"

WINE="$WINEGDK_DIR/bin/wine"
WINE_LIB="$WINEGDK_DIR/lib/wine/x86_64-windows"

echo "=== Minecraft Bedrock Linux Setup ==="
echo "WineGDK:    $WINEGDK_DIR"
echo "Game dir:   $GAME_DIR"
echo "Prefix dir: $PREFIX_DIR"
echo ""

# Preflight checks
if [[ ! -f "$GAME_DIR/Minecraft.Windows.exe" ]]; then
    echo "ERROR: Minecraft.Windows.exe not found in $GAME_DIR"
    echo "Copy game files from Windows first (C:\\XboxGames\\Minecraft for Windows\\Content\\)"
    exit 1
fi
if [[ ! -x "$WINE" ]]; then
    echo "ERROR: wine not found at $WINE"
    echo "Build WineGDK first, or set WINEGDK_DIR to your install prefix."
    exit 1
fi

# 1. Replace XCurl.dll
# Downloads mingw curl from MSYS2 repo. Update version as needed:
# https://repo.msys2.org/mingw/mingw64/ (search for mingw-w64-x86_64-curl)
CURL_PKG="mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar.zst"
CURL_URL="https://repo.msys2.org/mingw/mingw64/$CURL_PKG"
echo "[1/7] Replacing XCurl.dll with mingw curl..."
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"
curl -sLO "$CURL_URL"
zstd -d "$CURL_PKG"
tar xf "${CURL_PKG%.zst}"
cp "$GAME_DIR/XCurl.dll" "$GAME_DIR/XCurl.dll.bak" 2>/dev/null || true
cp mingw64/bin/libcurl-4.dll "$GAME_DIR/XCurl.dll"
rm -rf mingw64
echo "  Done."

# 2. Download XCurl dependency DLLs from MSYS2
# WineGDK is plain Wine -- it does NOT bundle the mingw runtime libraries that
# the MSYS2 curl DLL (now XCurl.dll) links against. We download each dependency
# package from the MSYS2 mingw64 repository and copy the needed DLLs into GAME_DIR.
#
# To update versions: browse https://repo.msys2.org/mingw/mingw64/ and look for
# each package name. If a DLL filename changes (e.g. libngtcp2-17.dll), update
# both the package line AND the dll name in XCURL_DEPS below.
echo "[2/7] Downloading XCurl dependency DLLs from MSYS2..."

MSYS2_BASE="https://repo.msys2.org/mingw/mingw64"

# Format: "package-filename.tar.zst|dll1,dll2,..."
XCURL_DEPS=(
    "mingw-w64-x86_64-libiconv-1.19-1-any.pkg.tar.zst|libiconv-2.dll,libcharset-1.dll"
    "mingw-w64-x86_64-brotli-1.1.0-2-any.pkg.tar.zst|libbrotlidec.dll,libbrotlicommon.dll"
    "mingw-w64-x86_64-libidn2-2.3.7-2-any.pkg.tar.zst|libidn2-0.dll"
    "mingw-w64-x86_64-libunistring-1.3-1-any.pkg.tar.zst|libunistring-5.dll"
    "mingw-w64-x86_64-nghttp2-1.65.0-1-any.pkg.tar.zst|libnghttp2-14.dll"
    "mingw-w64-x86_64-nghttp3-1.7.0-1-any.pkg.tar.zst|libnghttp3-9.dll"
    "mingw-w64-x86_64-ngtcp2-1.22.1-1-any.pkg.tar.zst|libngtcp2-16.dll,libngtcp2_crypto_ossl-0.dll"
    "mingw-w64-x86_64-libpsl-0.21.5-3-any.pkg.tar.zst|libpsl-5.dll"
    "mingw-w64-x86_64-libssh2-1.11.1-2-any.pkg.tar.zst|libssh2-1.dll"
    "mingw-w64-x86_64-zstd-1.5.7-1-any.pkg.tar.zst|libzstd.dll"
    "mingw-w64-x86_64-openssl-3.4.1-1-any.pkg.tar.zst|libcrypto-3-x64.dll,libssl-3-x64.dll"
    "mingw-w64-x86_64-zlib-1.3.1-1-any.pkg.tar.zst|zlib1.dll"
    "mingw-w64-x86_64-gettext-runtime-0.23.1-1-any.pkg.tar.zst|libintl-8.dll"
    "mingw-w64-x86_64-gcc-libs-15.1.0-1-any.pkg.tar.zst|libgcc_s_seh-1.dll"
    "mingw-w64-x86_64-libwinpthread-git-12.0.0.r747.g1a99f8514-1-any.pkg.tar.zst|libwinpthread-1.dll"
)

MISSING=0
for entry in "${XCURL_DEPS[@]}"; do
    pkg="${entry%%|*}"
    dlls="${entry##*|}"

    if ! curl -sfLO "$MSYS2_BASE/$pkg"; then
        echo "  WARNING: Failed to download $pkg"
        echo "           Version may have changed -- check $MSYS2_BASE/"
        MISSING=1
        continue
    fi
    zstd -dq "$pkg"
    tar xf "${pkg%.zst}"
    rm -f "$pkg" "${pkg%.zst}"

    IFS=',' read -ra DLL_LIST <<< "$dlls"
    for dll in "${DLL_LIST[@]}"; do
        if [[ -f "mingw64/bin/$dll" ]]; then
            cp "mingw64/bin/$dll" "$GAME_DIR/"
        else
            echo "  WARNING: $dll not found in $pkg"
            MISSING=1
        fi
    done
    rm -rf mingw64
done

if [[ "$MISSING" -eq 1 ]]; then
    echo "  Done (with warnings -- check above)."
else
    echo "  Done."
fi

# 3. SSL certificates
echo "[3/7] Setting up SSL certificates..."
mkdir -p "$(dirname "$GAME_DIR")/etc/ssl/certs/"
curl -sL -o "$(dirname "$GAME_DIR")/etc/ssl/certs/ca-bundle.crt" https://curl.se/ca/cacert.pem
echo "  Done."

# 4. Copy xgameruntime DLLs
echo "[4/7] Copying xgameruntime DLLs to game directory..."
for f in xgameruntime.dll xgameruntime.dll.threading; do
    if [[ -f "$WINE_LIB/$f" ]]; then
        cp "$WINE_LIB/$f" "$GAME_DIR/"
    else
        echo "  WARNING: $f not found in $WINE_LIB, skipping."
    fi
done
echo "  Done."

# 5. Create Wine prefix and install GameInputRedist
echo "[5/7] Creating Wine prefix and installing GameInputRedist..."
mkdir -p "$PREFIX_DIR"
if [[ -f "$GAME_DIR/Installers/GameInputRedist.msi" ]]; then
    WINEPREFIX="$PREFIX_DIR" "$WINE" msiexec /i "$GAME_DIR/Installers/GameInputRedist.msi" /qn 2>/dev/null || true
    echo "  Done."
else
    echo "  GameInputRedist.msi not found, skipping."
fi

# 6. Build and install midlproxystub (fixes ObjectStublessClient4 crash)
# Wine's PE-only mode fails to resolve combase.dll's forwarders to rpcrt4.dll.
# GameInputRedist.dll imports ObjectStublessClient3/4 from the
# api-ms-win-core-com-midlproxystub API set, which maps to combase.dll,
# which has broken forwarders -> crash.
# Fix: provide a real DLL that Wine loads directly.
echo "[6/7] Building and installing midlproxystub (ObjectStublessClient fix)..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUBS_DIR="$SCRIPT_DIR/../stubs/midlproxystub"
MIDL_DLL="api-ms-win-core-com-midlproxystub-l1-1-0.dll"
if command -v x86_64-w64-mingw32-gcc &>/dev/null; then
    (cd "$STUBS_DIR" && make clean && make)
    mkdir -p "$PREFIX_DIR/drive_c/windows/system32"
    cp "$STUBS_DIR/$MIDL_DLL" "$PREFIX_DIR/drive_c/windows/system32/$MIDL_DLL"
    echo "  Done."
else
    echo "  WARNING: x86_64-w64-mingw32-gcc not found."
    echo "  Install with: sudo apt install gcc-mingw-w64-x86-64"
    echo "  Then re-run or manually: cd $STUBS_DIR && make && make deploy"
fi

# 7. Patch graphics_mode to avoid deferred renderer crash
# Minecraft's Deferred Rendering (graphics_mode:2) has a race condition under Wine:
# rendering threads access MaterialDefinition objects before they are fully initialized,
# causing a NULL pointer crash. The game auto-resets this to 2 on each launch, so
# launch.sh patches it every time too.
echo "[7/7] Patching graphics options (disable deferred renderer)..."
OPTIONS_FILE="$PREFIX_DIR/drive_c/users/$(whoami)/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/minecraftpe/options.txt"
if [[ -f "$OPTIONS_FILE" ]]; then
    sed -i 's/^graphics_mode:[0-9]\+/graphics_mode:0/' "$OPTIONS_FILE"
    echo "  Set graphics_mode:0 (Classic renderer) to avoid material crash."
else
    echo "  options.txt not found yet (will be created on first launch)."
    echo "  launch.sh will patch it automatically."
fi

echo ""
echo "=== Setup Complete ==="
echo "Launch Minecraft with: ./scripts/launch.sh"
