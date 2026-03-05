#!/usr/bin/env bash
# Uninstall Minecraft Bedrock from Linux
# Handles both Lutris installer and manual setup.sh installations

set -euo pipefail

echo "=== Minecraft Bedrock Linux Uninstaller ==="
echo ""

# Detect installations
LUTRIS_INSTALL="$HOME/Games/minecraft-bedrock-edition-lutris"
MANUAL_GAME_DIR="${GAME_DIR:-$HOME/vmshare/minecraft-bedrock}"
MANUAL_PREFIX="${PREFIX_DIR:-$HOME/Games/MinecraftBedrock}"
STEAM_COMPAT="$HOME/.steam/root/compatibilitytools.d/GDK-Proton10-32"

# Lutris paths (Flatpak and native)
if [ -d "$HOME/.var/app/net.lutris.Lutris" ]; then
    LUTRIS_CONFIG_DIR="$HOME/.var/app/net.lutris.Lutris/config/lutris/games"
    LUTRIS_DB="$HOME/.var/app/net.lutris.Lutris/data/lutris/pga.db"
    LUTRIS_RUNNER_DIR="$HOME/.var/app/net.lutris.Lutris/data/lutris/runners/wine"
else
    LUTRIS_CONFIG_DIR="$HOME/.config/lutris/games"
    LUTRIS_DB="$HOME/.local/share/lutris/pga.db"
    LUTRIS_RUNNER_DIR="$HOME/.local/share/lutris/runners/wine"
fi

found=0

# Check what exists
[ -d "$LUTRIS_INSTALL" ] && echo "  Found: Lutris install ($LUTRIS_INSTALL)" && found=1
[ -d "$MANUAL_PREFIX" ] && echo "  Found: Manual prefix ($MANUAL_PREFIX)" && found=1
[ -d "$STEAM_COMPAT" ] && echo "  Found: GDK-Proton in Steam compat ($STEAM_COMPAT)" && found=1
[ -L "$LUTRIS_RUNNER_DIR/GDK-Proton10-32" ] && echo "  Found: GDK-Proton runner symlink" && found=1
ls "$LUTRIS_CONFIG_DIR"/minecraft-bedrock* &>/dev/null && echo "  Found: Lutris game config(s)" && found=1

if [ "$found" -eq 0 ]; then
    echo "Nothing to uninstall."
    exit 0
fi

echo ""
read -rp "Remove all Minecraft Bedrock files? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# 1. Remove Lutris install directory
if [ -d "$LUTRIS_INSTALL" ]; then
    rm -rf "$LUTRIS_INSTALL"
    echo "Removed $LUTRIS_INSTALL"
fi

# 2. Remove manual setup prefix
if [ -d "$MANUAL_PREFIX" ]; then
    rm -rf "$MANUAL_PREFIX"
    echo "Removed $MANUAL_PREFIX"
fi

# 3. Remove GDK-Proton from Steam compat
if [ -d "$STEAM_COMPAT" ]; then
    rm -rf "$STEAM_COMPAT"
    echo "Removed $STEAM_COMPAT"
fi

# 4. Remove GDK-Proton runner symlink
if [ -L "$LUTRIS_RUNNER_DIR/GDK-Proton10-32" ]; then
    rm "$LUTRIS_RUNNER_DIR/GDK-Proton10-32"
    echo "Removed runner symlink"
fi

# 5. Remove Lutris game configs
for cfg in "$LUTRIS_CONFIG_DIR"/minecraft-bedrock*; do
    [ -f "$cfg" ] && rm "$cfg" && echo "Removed config: $(basename "$cfg")"
done

# 6. Remove Lutris DB entries
if command -v sqlite3 &>/dev/null && [ -f "$LUTRIS_DB" ]; then
    sqlite3 "$LUTRIS_DB" "DELETE FROM games WHERE slug LIKE 'minecraft-bedrock%';"
    echo "Removed Lutris database entries"
fi

echo ""
echo "=== Uninstall Complete ==="

# Note about source files
if [ -d "$MANUAL_GAME_DIR" ]; then
    echo ""
    echo "Note: Source game files still at $MANUAL_GAME_DIR"
    echo "Delete manually if no longer needed: rm -rf $MANUAL_GAME_DIR"
fi
