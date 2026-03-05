#!/usr/bin/env bash
# ============================================================================
# update.sh — Full update for Minecraft Bedrock on Linux via GDK-Proton
# ============================================================================
#
# Updates everything needed to run the latest Minecraft Bedrock version:
#
#   1. GDK-Proton    — downloads the latest release from GitHub
#   2. Game files    — re-extracts decrypted files from the Windows VM
#   3. XCurl.dll     — downloads the latest mingw curl from MSYS2
#   4. SSL certs     — refreshes the Mozilla CA bundle
#   5. Runtime DLLs  — copies xgameruntime.dll from the updated GDK-Proton
#   6. GameInputRedist — re-installs the MSI into the Wine prefix
#
# World saves are backed up before extraction and restored afterward.
#
# Prerequisites:
#   - Windows 11 VM running with SSH access (see Part 2 of README)
#   - Minecraft Bedrock updated in the Xbox App on the VM
#   - Game launched at least once in the VM after the update
#
# Usage:
#   ./scripts/update.sh <windows-user> <vm-ip>
#
# Environment variables (all optional, with sensible defaults):
#   GAME_DIR         — where game files live    (default: ~/vmshare/minecraft-bedrock)
#   PREFIX_DIR       — Wine prefix path         (default: ~/Games/MinecraftBedrock/prefix)
#   GDK_PROTON_DIR   — GDK-Proton install path  (default: ~/.steam/root/compatibilitytools.d/<latest>)
#   SKIP_VM          — set to 1 to skip VM extraction (re-setup only)
#   SKIP_GDK_UPDATE  — set to 1 to skip GDK-Proton update
# ============================================================================

set -euo pipefail

WIN_USER="${1:?Usage: $0 <windows-user> <vm-ip>}"
VM_IP="${2:?Usage: $0 <windows-user> <vm-ip>}"

GAME_DIR="${GAME_DIR:-$HOME/vmshare/minecraft-bedrock}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/MinecraftBedrock/prefix}"
COMPAT_DIR="$HOME/.steam/root/compatibilitytools.d"
SKIP_VM="${SKIP_VM:-0}"
SKIP_GDK_UPDATE="${SKIP_GDK_UPDATE:-0}"

TOTAL_STEPS=6
STEP=0

next_step() {
    STEP=$((STEP + 1))
    echo ""
    echo "[$STEP/$TOTAL_STEPS] $1"
}

echo "============================================"
echo "  Minecraft Bedrock — Full Update"
echo "============================================"
echo ""
echo "  Game dir:   $GAME_DIR"
echo "  Prefix:     $PREFIX_DIR"
echo "  Compat dir: $COMPAT_DIR"
echo "  VM:         $WIN_USER@$VM_IP"
echo ""

# --- Step 1: Update GDK-Proton -------------------------------------------

if [ "$SKIP_GDK_UPDATE" = "1" ]; then
    next_step "Skipping GDK-Proton update (SKIP_GDK_UPDATE=1)"
    # Use existing GDK_PROTON_DIR or find the latest installed
    GDK_PROTON_DIR="${GDK_PROTON_DIR:-$(ls -d "$COMPAT_DIR"/GDK-Proton* 2>/dev/null | sort -V | tail -1)}"
    if [ -z "$GDK_PROTON_DIR" ] || [ ! -d "$GDK_PROTON_DIR" ]; then
        echo "  ERROR: No GDK-Proton found in $COMPAT_DIR"
        exit 1
    fi
    echo "  Using: $GDK_PROTON_DIR"
else
    next_step "Updating GDK-Proton to latest release..."

    # Fetch latest release info from GitHub
    RELEASE_JSON=$(curl -sL https://api.github.com/repos/Weather-OS/GDK-Proton/releases/latest)
    RELEASE_TAG=$(echo "$RELEASE_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['tag_name'])")
    RELEASE_NAME=$(echo "$RELEASE_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")
    TARBALL_URL=$(echo "$RELEASE_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['assets'][0]['browser_download_url'])")

    GDK_PROTON_DIR="$COMPAT_DIR/$RELEASE_NAME"

    if [ -d "$GDK_PROTON_DIR" ]; then
        echo "  Already up to date: $RELEASE_NAME ($RELEASE_TAG)"
    else
        echo "  Downloading $RELEASE_NAME ($RELEASE_TAG)..."
        mkdir -p "$COMPAT_DIR"
        WORK_DIR=$(mktemp -d)
        curl -sL -o "$WORK_DIR/gdk-proton.tar.gz" "$TARBALL_URL"
        tar xf "$WORK_DIR/gdk-proton.tar.gz" -C "$COMPAT_DIR/"
        rm -rf "$WORK_DIR"
        echo "  Installed to: $GDK_PROTON_DIR"
    fi
fi

# --- Step 2: Back up saves and re-extract game files from VM ---------------

next_step "Extracting game files from VM..."

# Back up world saves before overwriting
BACKUP_DIR=""
SAVES_DIR="$GAME_DIR/data/com.mojang/minecraftWorlds"
if [ -d "$SAVES_DIR" ]; then
    BACKUP_DIR="$HOME/vmshare/minecraft-bedrock-saves-backup-$(date +%Y%m%d-%H%M%S)"
    echo "  Backing up world saves to $BACKUP_DIR..."
    cp -r "$SAVES_DIR" "$BACKUP_DIR"
fi

if [ "$SKIP_VM" = "1" ]; then
    echo "  Skipping VM extraction (SKIP_VM=1)"
else
    if [ -f "$GAME_DIR/Minecraft.Windows.exe" ]; then
        OLD_SIZE=$(stat -c%s "$GAME_DIR/Minecraft.Windows.exe" 2>/dev/null || echo "?")
        echo "  Existing exe: $OLD_SIZE bytes"
    fi
    DEST_DIR="$GAME_DIR" ./scripts/host-copy-from-vm.sh "$WIN_USER" "$VM_IP"
fi

# --- Step 3: Replace XCurl.dll with latest mingw curl ----------------------

next_step "Updating XCurl.dll (latest mingw curl from MSYS2)..."

# Auto-detect the latest curl package version from the MSYS2 repo
CURL_PKG=$(curl -sL "https://repo.msys2.org/mingw/mingw64/" \
    | grep -oP 'mingw-w64-x86_64-curl-[\d.]+-\d+-any\.pkg\.tar\.zst(?=")' \
    | sort -V | tail -1)

if [ -z "$CURL_PKG" ]; then
    echo "  WARNING: Could not detect latest curl package, using fallback"
    CURL_PKG="mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar.zst"
fi

CURL_URL="https://repo.msys2.org/mingw/mingw64/$CURL_PKG"
echo "  Package: $CURL_PKG"

WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"
curl -sLO "$CURL_URL"
zstd -d "$CURL_PKG"
tar xf "${CURL_PKG%.zst}"
cp mingw64/bin/libcurl-4.dll "$GAME_DIR/XCurl.dll"
rm -rf "$WORK_DIR"
cd - >/dev/null
echo "  Done."

# --- Step 4: Refresh SSL certificates -------------------------------------

next_step "Refreshing SSL CA certificates..."
SSL_DIR="$(dirname "$GAME_DIR")/etc/ssl/certs"
mkdir -p "$SSL_DIR"
curl -sL -o "$SSL_DIR/ca-bundle.crt" https://curl.se/ca/cacert.pem
echo "  Updated: $SSL_DIR/ca-bundle.crt"

# --- Step 5: Copy xgameruntime DLLs from GDK-Proton -----------------------

next_step "Copying xgameruntime DLLs from GDK-Proton..."
SRC_DLL_DIR="$GDK_PROTON_DIR/files/lib/wine/x86_64-windows"
cp "$SRC_DLL_DIR/xgameruntime.dll" "$GAME_DIR/"
cp "$SRC_DLL_DIR/xgameruntime.dll.threading" "$GAME_DIR/"
echo "  Copied from: $SRC_DLL_DIR"

# --- Step 6: Re-install GameInputRedist ------------------------------------

next_step "Installing GameInputRedist..."
if [ -f "$GAME_DIR/Installers/GameInputRedist.msi" ]; then
    mkdir -p "$PREFIX_DIR"
    WINEPREFIX="$PREFIX_DIR/pfx" \
        "$GDK_PROTON_DIR/files/bin/wine64" \
        msiexec /i "$GAME_DIR/Installers/GameInputRedist.msi" /qn 2>/dev/null || true
    echo "  Done."
else
    echo "  GameInputRedist.msi not found in game files, skipping."
fi

# --- Restore world saves ---------------------------------------------------

if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    echo ""
    echo "Restoring world saves..."
    mkdir -p "$SAVES_DIR"
    cp -r "$BACKUP_DIR"/* "$SAVES_DIR/" 2>/dev/null || true
    echo "  Restored. Backup kept at: $BACKUP_DIR"
fi

# --- Summary ----------------------------------------------------------------

echo ""
echo "============================================"
echo "  Update Complete"
echo "============================================"
echo ""
echo "  GDK-Proton:  $(basename "$GDK_PROTON_DIR")"
echo "  XCurl:       $CURL_PKG"

if file "$GAME_DIR/Minecraft.Windows.exe" | grep -q "PE32+"; then
    NEW_SIZE=$(stat -c%s "$GAME_DIR/Minecraft.Windows.exe" 2>/dev/null || echo "?")
    echo "  Game exe:    VALID (decrypted, $NEW_SIZE bytes)"
else
    echo "  Game exe:    WARNING — may still be encrypted, re-run extraction"
fi

echo ""
echo "Launch with: ./scripts/launch.sh"
