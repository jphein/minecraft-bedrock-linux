#!/usr/bin/env bash
# Launch Minecraft Bedrock via WineGDK (plain Wine fork, no Proton)

set -euo pipefail

WINEGDK_DIR="${WINEGDK_DIR:-$HOME/Projects/WineGDK/install-clang23}"
GAME_DIR="${GAME_DIR:-$HOME/Games/minecraft-bedrock/game}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/minecraft-bedrock/prefix}"

WINE="$WINEGDK_DIR/bin/wine"
if [[ ! -x "$WINE" ]]; then
    echo "ERROR: wine not found at $WINE"
    echo "Build WineGDK first, or set WINEGDK_DIR to your install prefix."
    exit 1
fi

export WINEPREFIX="$PREFIX_DIR"

# DXVK: use native d3d11/dxgi (Vulkan backend, much faster than wined3d GL)
export WINEDLLOVERRIDES="d3d11,dxgi=n"

# Wine synchronization: esync + fsync for lower overhead
export WINEESYNC=1
export WINEFSYNC=1

# Patch graphics_mode to avoid deferred renderer crash.
# The game resets this to 2 each launch, so we patch every time.
OPTIONS_FILE="$PREFIX_DIR/drive_c/users/$(whoami)/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/minecraftpe/options.txt"
if [[ -f "$OPTIONS_FILE" ]]; then
    sed -i 's/^graphics_mode:[0-9]\+/graphics_mode:0/' "$OPTIONS_FILE"
fi

# MangoHUD: FPS overlay (disable with MANGOHUD=0)
if [[ "${MANGOHUD:-1}" == "1" ]] && command -v mangohud &>/dev/null; then
    export MANGOHUD=1
    export MANGOHUD_CONFIG="fps,frametime,gpu_temp,cpu_temp,ram,vram"
    exec mangohud "$WINE" "$GAME_DIR/Minecraft.Windows.exe"
else
    exec "$WINE" "$GAME_DIR/Minecraft.Windows.exe"
fi
