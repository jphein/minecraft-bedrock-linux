#!/usr/bin/env bash
# Launch Minecraft Bedrock via WineGDK (plain Wine fork, no Proton)

set -euo pipefail

WINEGDK_DIR="${WINEGDK_DIR:-$HOME/Projects/WineGDK/install}"
GAME_DIR="${GAME_DIR:-$HOME/Games/minecraft-bedrock/game}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/minecraft-bedrock/prefix}"

export WINEPREFIX="$PREFIX_DIR"
# Force Wine to use WineGDK's builtin gameinputredist.dll instead of
# Microsoft's redistributable, which crashes under Wine.
export WINEDLLOVERRIDES="GameInputRedist=b"

WINE="$WINEGDK_DIR/bin/wine"
if [[ ! -x "$WINE" ]]; then
    echo "ERROR: wine not found at $WINE"
    echo "Build WineGDK first, or set WINEGDK_DIR to your install prefix."
    exit 1
fi

# Work around a race condition in Minecraft's Deferred Rendering / PBR pipeline:
# When graphics_mode is set to 2 (Deferred/RTX), rendering threads may access
# MaterialDefinition objects before they are fully initialized, causing a crash.
# Setting graphics_mode:0 (Classic) avoids the deferred material paths entirely.
# The game auto-resets graphics_mode to 2 each launch, so we must patch every time.
OPTIONS_FILE="$PREFIX_DIR/drive_c/users/$(whoami)/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/minecraftpe/options.txt"
if [[ -f "$OPTIONS_FILE" ]]; then
    sed -i 's/^graphics_mode:[0-9]\+/graphics_mode:0/' "$OPTIONS_FILE"
fi

exec "$WINE" "$GAME_DIR/Minecraft.Windows.exe"
