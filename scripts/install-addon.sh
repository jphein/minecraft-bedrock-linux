#!/usr/bin/env bash
# Install Little Friends add-on to Minecraft Bedrock com.mojang directory.
# Symlinks packs into the development folders for hot-reload during dev.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BP_SRC="$SCRIPT_DIR/little-friends-bp"
RP_SRC="$SCRIPT_DIR/little-friends-rp"

COM_MOJANG="$HOME/Games/minecraft-bedrock-edition-lutris/prefix/pfx/drive_c/users/steamuser/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang"

DEV_BP="$COM_MOJANG/development_behavior_packs/little-friends-bp"
DEV_RP="$COM_MOJANG/development_resource_packs/little-friends-rp"

if [ ! -d "$COM_MOJANG" ]; then
    echo "ERROR: com.mojang not found at:"
    echo "  $COM_MOJANG"
    echo "Make sure Minecraft has been launched at least once."
    exit 1
fi

echo "Installing Little Friends add-on..."
echo ""

# Remove old symlinks/copies
rm -rf "$DEV_BP" "$DEV_RP"

# Symlink for development (auto-reload on changes)
ln -sf "$BP_SRC" "$DEV_BP"
ln -sf "$RP_SRC" "$DEV_RP"

echo "Behavior pack: $DEV_BP -> $BP_SRC"
echo "Resource pack: $DEV_RP -> $RP_SRC"
echo ""
echo "=== Installed ==="
echo ""
echo "Next steps:"
echo "  1. Launch Minecraft"
echo "  2. Create or edit a world"
echo "  3. In world settings, enable:"
echo "     - Beta APIs (under Experiments)"
echo "     - Little Friends (under Behavior Packs)"
echo "     - Little Friends Resources (under Resource Packs)"
echo "  4. Play! Your companions will arrive in ~30 seconds."
