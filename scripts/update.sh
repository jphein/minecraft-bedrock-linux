#!/usr/bin/env bash
# Update Minecraft Bedrock: re-extract from Windows VM and re-run setup
# Usage: ./scripts/update.sh <windows-user> <vm-ip>
#
# This script:
#   1. Re-extracts game files from the VM (handles encryption)
#   2. Re-applies XCurl.dll, SSL certs, xgameruntime DLLs, GameInputRedist
#
# Run this after updating Minecraft in the Xbox App on the VM.

set -euo pipefail

WIN_USER="${1:?Usage: $0 <windows-user> <vm-ip>}"
VM_IP="${2:?Usage: $0 <windows-user> <vm-ip>}"
GAME_DIR="${GAME_DIR:-$HOME/vmshare/minecraft-bedrock}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/MinecraftBedrock/prefix}"
GDK_PROTON_DIR="${GDK_PROTON_DIR:-$HOME/.steam/root/compatibilitytools.d/GDK-Proton10-32}"

echo "=== Minecraft Bedrock Update ==="
echo ""

# Get current version (if any)
if [ -f "$GAME_DIR/Minecraft.Windows.exe" ]; then
    OLD_SIZE=$(stat -c%s "$GAME_DIR/Minecraft.Windows.exe" 2>/dev/null || echo "unknown")
    echo "Existing install found at $GAME_DIR (exe size: $OLD_SIZE bytes)"
else
    echo "No existing install found — this will be a fresh extraction."
fi
echo ""

# Back up saves before overwriting
SAVES_DIR="$GAME_DIR/data/com.mojang/minecraftWorlds"
if [ -d "$SAVES_DIR" ]; then
    BACKUP_DIR="$HOME/vmshare/minecraft-bedrock-saves-backup-$(date +%Y%m%d-%H%M%S)"
    echo "[0/4] Backing up world saves to $BACKUP_DIR..."
    cp -r "$SAVES_DIR" "$BACKUP_DIR"
    echo "  Done."
fi

# Step 1: Re-extract from VM
echo "[1/4] Re-extracting game files from VM..."
DEST_DIR="$GAME_DIR" ./scripts/host-copy-from-vm.sh "$WIN_USER" "$VM_IP"
echo ""

# Step 2: Replace XCurl.dll
CURL_PKG="mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar.zst"
CURL_URL="https://repo.msys2.org/mingw/mingw64/$CURL_PKG"
echo "[2/4] Replacing XCurl.dll with mingw curl..."
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"
curl -sLO "$CURL_URL"
zstd -d "$CURL_PKG"
tar xf "${CURL_PKG%.zst}"
cp mingw64/bin/libcurl-4.dll "$GAME_DIR/XCurl.dll"
rm -rf "$WORK_DIR"
cd - >/dev/null
echo "  Done."

# Step 3: SSL certificates + xgameruntime DLLs
echo "[3/4] Updating SSL certs and xgameruntime DLLs..."
mkdir -p "$(dirname "$GAME_DIR")/etc/ssl/certs/"
curl -sL -o "$(dirname "$GAME_DIR")/etc/ssl/certs/ca-bundle.crt" https://curl.se/ca/cacert.pem
cp "$GDK_PROTON_DIR/files/lib/wine/x86_64-windows/xgameruntime.dll" "$GAME_DIR/"
cp "$GDK_PROTON_DIR/files/lib/wine/x86_64-windows/xgameruntime.dll.threading" "$GAME_DIR/"
echo "  Done."

# Step 4: Re-install GameInputRedist
echo "[4/4] Re-installing GameInputRedist..."
if [ -f "$GAME_DIR/Installers/GameInputRedist.msi" ]; then
    WINEPREFIX="$PREFIX_DIR/pfx" \
        "$GDK_PROTON_DIR/files/bin/wine64" \
        msiexec /i "$GAME_DIR/Installers/GameInputRedist.msi" /qn 2>/dev/null || true
    echo "  Done."
else
    echo "  GameInputRedist.msi not found, skipping."
fi

# Restore saves if they were backed up
if [ -n "${BACKUP_DIR:-}" ] && [ -d "$BACKUP_DIR" ]; then
    echo ""
    echo "Restoring world saves..."
    mkdir -p "$SAVES_DIR"
    cp -r "$BACKUP_DIR"/* "$SAVES_DIR/" 2>/dev/null || true
    echo "  Done. Backup kept at $BACKUP_DIR"
fi

# Show result
echo ""
echo "=== Update Complete ==="
if file "$GAME_DIR/Minecraft.Windows.exe" | grep -q "PE32+"; then
    echo "Minecraft.Windows.exe: VALID (decrypted)"
else
    echo "WARNING: Minecraft.Windows.exe may still be encrypted — re-run extraction"
fi
echo "Launch with: ./scripts/launch.sh"
