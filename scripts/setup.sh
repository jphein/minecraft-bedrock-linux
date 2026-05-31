#!/usr/bin/env bash
# Setup script for Minecraft Bedrock on Ubuntu Linux via WineGDK
# Run this after copying game files from Windows and building WineGDK from source.

set -euo pipefail

WINEGDK_DIR="${WINEGDK_DIR:-$HOME/Projects/WineGDK/install-clang23}"
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

# Verify game version (must be 1.26.21+, not the old 1.26.3)
EXE_SIZE=$(stat -c%s "$GAME_DIR/Minecraft.Windows.exe")
if [[ "$EXE_SIZE" -lt 200000000 ]]; then
    echo "WARNING: Minecraft.Windows.exe is only $(( EXE_SIZE / 1048576 ))MB."
    echo "Expected 230MB+ for version 1.26.21. You may have the old 1.26.3 binary."
    echo "Re-extract from the Windows VM with: scripts/host-copy-from-vm.sh"
fi

# 1. Replace XCurl.dll with mingw curl
CURL_PKG="mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar.zst"
CURL_URL="https://repo.msys2.org/mingw/mingw64/$CURL_PKG"
echo "[1/10] Replacing XCurl.dll with mingw curl..."
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
echo "[2/10] Downloading XCurl dependency DLLs from MSYS2..."

MSYS2_BASE="https://repo.msys2.org/mingw/mingw64"

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
echo "[3/10] Setting up SSL certificates..."
mkdir -p "$(dirname "$GAME_DIR")/etc/ssl/certs/"
curl -sL -o "$(dirname "$GAME_DIR")/etc/ssl/certs/ca-bundle.crt" https://curl.se/ca/cacert.pem
echo "  Done."

# 4. Copy xgameruntime.dll from WineGDK
echo "[4/10] Copying xgameruntime.dll to game directory..."
if [[ -f "$WINE_LIB/xgameruntime.dll" ]]; then
    cp "$WINE_LIB/xgameruntime.dll" "$GAME_DIR/"
    echo "  Done."
else
    echo "  WARNING: xgameruntime.dll not found in $WINE_LIB"
fi
# xgameruntime.dll.threading is the native Microsoft binary — must come from
# the Windows VM extraction, not from WineGDK. Check it exists.
if [[ ! -f "$GAME_DIR/xgameruntime.dll.threading" ]]; then
    echo "  WARNING: xgameruntime.dll.threading not found in $GAME_DIR"
    echo "  This native Microsoft DLL is required. Copy it from the Windows VM."
fi

# 5. Create Wine prefix
echo "[5/10] Creating Wine prefix..."
mkdir -p "$PREFIX_DIR"
WINEPREFIX="$PREFIX_DIR" "$WINE" wineboot -i 2>/dev/null
echo "  Done."

# 6. Install GameInput via msiextract (msiexec hangs under Wine)
echo "[6/10] Installing GameInput redistributable..."
if [[ -f "$GAME_DIR/Installers/GameInputRedist.msi" ]]; then
    if command -v msiextract &>/dev/null; then
        GITMP=$(mktemp -d)
        (cd "$GITMP" && msiextract "$GAME_DIR/Installers/GameInputRedist.msi" 2>/dev/null)
        find "$GITMP" -name '*.dll' -path '*/x64/*' -exec cp {} "$PREFIX_DIR/drive_c/windows/system32/" \;
        find "$GITMP" -name '*.exe' -path '*/x64/*' -exec cp {} "$PREFIX_DIR/drive_c/windows/system32/" \;
        rm -rf "$GITMP"
        WINEPREFIX="$PREFIX_DIR" "$WINE" reg add "HKLM\\SOFTWARE\\Microsoft\\GameInput" /v RedistDir /t REG_SZ /d "C:\\windows\\system32\\" /f 2>/dev/null
        WINEPREFIX="$PREFIX_DIR" "$WINE" reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\GameInputRedistService" /v ImagePath /t REG_SZ /d "C:\\windows\\system32\\GameInputRedistService.exe" /f 2>/dev/null
        WINEPREFIX="$PREFIX_DIR" "$WINE" reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\GameInputRedistService" /v Type /t REG_DWORD /d 16 /f 2>/dev/null
        WINEPREFIX="$PREFIX_DIR" "$WINE" reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\GameInputRedistService" /v Start /t REG_DWORD /d 3 /f 2>/dev/null
        echo "  Done."
    else
        echo "  WARNING: msiextract not found. Install with: sudo apt install msitools"
    fi
else
    echo "  GameInputRedist.msi not found, skipping."
fi

# 7. Build and install midlproxystub (fixes ObjectStublessClient4 crash)
echo "[7/10] Building and installing midlproxystub..."
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
fi

# 8. Install DXVK (Vulkan-based D3D11, much faster than wined3d OpenGL)
echo "[8/10] Installing DXVK..."
DXVK_VERSION="2.7.1"
DXVK_DIR="/tmp/dxvk-$DXVK_VERSION"
if [[ ! -d "$DXVK_DIR" ]]; then
    echo "  Downloading DXVK $DXVK_VERSION..."
    curl -sL "https://github.com/doitsujin/dxvk/releases/download/v$DXVK_VERSION/dxvk-$DXVK_VERSION.tar.gz" | tar xz -C /tmp/
fi
if [[ -f "$DXVK_DIR/x64/d3d11.dll" ]]; then
    cp "$DXVK_DIR/x64/d3d11.dll" "$PREFIX_DIR/drive_c/windows/system32/"
    cp "$DXVK_DIR/x64/dxgi.dll" "$PREFIX_DIR/drive_c/windows/system32/"
    WINEPREFIX="$PREFIX_DIR" "$WINE" reg add "HKCU\\Software\\Wine\\DllOverrides" /v d3d11 /t REG_SZ /d native /f 2>/dev/null
    WINEPREFIX="$PREFIX_DIR" "$WINE" reg add "HKCU\\Software\\Wine\\DllOverrides" /v dxgi /t REG_SZ /d native /f 2>/dev/null
    echo "  Done (DXVK $DXVK_VERSION)."
else
    echo "  WARNING: DXVK not found at $DXVK_DIR"
fi

# 9. Build and install GameInput stub (bypasses "missing required component" dialog)
echo "[9/11] Building GameInput stub..."
GAMEINPUT_DIR="$SCRIPT_DIR/../stubs/gameinput"
if command -v x86_64-w64-mingw32-gcc &>/dev/null; then
    (cd "$GAMEINPUT_DIR" && make clean && make)
    cp "$GAMEINPUT_DIR/GameInput.dll" "$PREFIX_DIR/drive_c/windows/system32/gameinput.dll"
    echo "  Done."
else
    echo "  WARNING: x86_64-w64-mingw32-gcc not found."
    echo "  Install with: sudo apt install gcc-mingw-w64-x86-64"
fi

# 10. Build and install Windows App Runtime bootstrapper stub
echo "[10/11] Building Windows App Runtime bootstrapper stub..."
BOOTSTRAP_DIR="$SCRIPT_DIR/../stubs/winappruntime-bootstrap"
BOOTSTRAP_DLL="Microsoft.WindowsAppRuntime.Bootstrap.dll"
if command -v x86_64-w64-mingw32-gcc &>/dev/null; then
    (cd "$BOOTSTRAP_DIR" && make clean && make)
    cp "$GAME_DIR/$BOOTSTRAP_DLL" "$GAME_DIR/$BOOTSTRAP_DLL.bak" 2>/dev/null || true
    cp "$BOOTSTRAP_DIR/$BOOTSTRAP_DLL" "$GAME_DIR/$BOOTSTRAP_DLL"
    echo "  Done."
else
    echo "  WARNING: x86_64-w64-mingw32-gcc not found."
    echo "  Install with: sudo apt install gcc-mingw-w64-x86-64"
fi

# 11. Patch graphics_mode to avoid deferred renderer crash
echo "[11/11] Patching graphics options..."
OPTIONS_FILE="$PREFIX_DIR/drive_c/users/$(whoami)/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/minecraftpe/options.txt"
if [[ -f "$OPTIONS_FILE" ]]; then
    sed -i 's/^graphics_mode:[0-9]\+/graphics_mode:0/' "$OPTIONS_FILE"
    echo "  Set graphics_mode:0 (Classic renderer)."
else
    echo "  options.txt not found yet (created on first launch). launch.sh patches it automatically."
fi

echo ""
echo "=== Setup Complete ==="
echo "Launch Minecraft with: ./scripts/launch.sh"
