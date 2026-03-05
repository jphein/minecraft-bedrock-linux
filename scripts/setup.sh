#!/usr/bin/env bash
# Setup script for Minecraft Bedrock on Ubuntu Linux via GDK-Proton
# Run this after copying game files from Windows to ~/vmshare/minecraft-bedrock/

set -euo pipefail

GAME_DIR="${GAME_DIR:-$HOME/vmshare/minecraft-bedrock}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/MinecraftBedrock/prefix}"
GDK_PROTON_DIR="${GDK_PROTON_DIR:-$HOME/.steam/root/compatibilitytools.d/GDK-Proton10-32}"
LUTRIS_RUNNER_DIR="$HOME/.var/app/net.lutris.Lutris/data/lutris/runners/wine"
LUTRIS_CONFIG_DIR="$HOME/.var/app/net.lutris.Lutris/config/lutris/games"
LUTRIS_DB="$HOME/.var/app/net.lutris.Lutris/data/lutris/pga.db"

echo "=== Minecraft Bedrock Linux Setup ==="
echo "Game dir:   $GAME_DIR"
echo "Prefix dir: $PREFIX_DIR"
echo "GDK-Proton: $GDK_PROTON_DIR"
echo ""

# Check game files exist
if [ ! -f "$GAME_DIR/Minecraft.Windows.exe" ]; then
    echo "ERROR: Minecraft.Windows.exe not found in $GAME_DIR"
    echo "Copy game files from Windows first (C:\\XboxGames\\Minecraft for Windows\\Content\\)"
    exit 1
fi

# Check GDK-Proton installed
if [ ! -d "$GDK_PROTON_DIR" ]; then
    echo "ERROR: GDK-Proton not found at $GDK_PROTON_DIR"
    echo "Download from https://github.com/Weather-OS/GDK-Proton/releases"
    exit 1
fi

# 1. Replace XCurl.dll
# Downloads mingw curl from MSYS2 repo. Update version as needed:
# https://repo.msys2.org/mingw/mingw64/ (search for mingw-w64-x86_64-curl)
CURL_PKG="mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar.zst"
CURL_URL="https://repo.msys2.org/mingw/mingw64/$CURL_PKG"
echo "[1/6] Replacing XCurl.dll with mingw curl..."
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"
curl -sLO "$CURL_URL"
zstd -d "$CURL_PKG"
tar xf "${CURL_PKG%.zst}"
cp "$GAME_DIR/XCurl.dll" "$GAME_DIR/XCurl.dll.bak" 2>/dev/null || true
cp mingw64/bin/libcurl-4.dll "$GAME_DIR/XCurl.dll"
rm -rf "$WORK_DIR"
echo "  Done."

# 2. SSL certificates
echo "[2/6] Setting up SSL certificates..."
mkdir -p "$(dirname "$GAME_DIR")/etc/ssl/certs/"
curl -sL -o "$(dirname "$GAME_DIR")/etc/ssl/certs/ca-bundle.crt" https://curl.se/ca/cacert.pem
echo "  Done."

# 3. Copy xgameruntime DLLs
echo "[3/6] Copying xgameruntime DLLs to game directory..."
cp "$GDK_PROTON_DIR/files/lib/wine/x86_64-windows/xgameruntime.dll" "$GAME_DIR/"
cp "$GDK_PROTON_DIR/files/lib/wine/x86_64-windows/xgameruntime.dll.threading" "$GAME_DIR/"
echo "  Done."

# 4. Create Wine prefix and install GameInputRedist
echo "[4/6] Creating Wine prefix and installing GameInputRedist..."
mkdir -p "$PREFIX_DIR"
if [ -f "$GAME_DIR/Installers/GameInputRedist.msi" ]; then
    WINEPREFIX="$PREFIX_DIR/pfx" \
        "$GDK_PROTON_DIR/files/bin/wine64" \
        msiexec /i "$GAME_DIR/Installers/GameInputRedist.msi" /qn 2>/dev/null || true
    echo "  Done."
else
    echo "  GameInputRedist.msi not found, skipping."
fi

# 5. Symlink GDK-Proton into Lutris runners
echo "[5/6] Setting up Lutris runner symlink..."
mkdir -p "$LUTRIS_RUNNER_DIR"
ln -sf "$GDK_PROTON_DIR" "$LUTRIS_RUNNER_DIR/GDK-Proton10-32"
echo "  Done."

# 6. Create Lutris game config
echo "[6/6] Creating Lutris game configuration..."
mkdir -p "$LUTRIS_CONFIG_DIR"
cat > "$LUTRIS_CONFIG_DIR/minecraft-bedrock.yml" << YAML
game:
  exe: $GAME_DIR/Minecraft.Windows.exe
  prefix: $PREFIX_DIR
  working_dir: $GAME_DIR
name: Minecraft Bedrock
runner: wine
slug: minecraft-bedrock
wine:
  version: GDK-Proton10-32
  runner_type: proton
system:
  env:
    STEAM_COMPAT_DATA_PATH: $PREFIX_DIR
    STEAM_COMPAT_CLIENT_INSTALL_PATH: $HOME/.steam/root
    PROTONPATH: $GDK_PROTON_DIR
    GAMEID: minecraft-bedrock
    STORE: none
YAML

# Add to Lutris DB if sqlite3 is available
if command -v sqlite3 &>/dev/null && [ -f "$LUTRIS_DB" ]; then
    # Check if already exists
    EXISTS=$(sqlite3 "$LUTRIS_DB" "SELECT COUNT(*) FROM games WHERE slug='minecraft-bedrock';")
    if [ "$EXISTS" -eq 0 ]; then
        # Escape single quotes in paths for SQL safety
        SAFE_GAME_DIR="${GAME_DIR//\'/\'\'}"
        sqlite3 "$LUTRIS_DB" \
            "INSERT INTO games (name, slug, runner, executable, directory, installed, configpath, platform) \
             VALUES ('Minecraft Bedrock', 'minecraft-bedrock', 'wine', \
             '${SAFE_GAME_DIR}/Minecraft.Windows.exe', '${SAFE_GAME_DIR}', 1, 'minecraft-bedrock', 'windows');"
        echo "  Added to Lutris database."
    else
        echo "  Already in Lutris database."
    fi
else
    echo "  sqlite3 not found or Lutris DB missing — add game manually in Lutris."
fi

echo ""
echo "=== Setup Complete ==="
echo "Launch Minecraft from Lutris, or run: ./scripts/launch.sh"
