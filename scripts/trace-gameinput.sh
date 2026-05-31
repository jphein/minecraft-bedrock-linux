#!/bin/bash
# Trace GameInput loading to debug "missing required component" dialog
WINEGDK_DIR="${WINEGDK_DIR:-$HOME/Projects/WineGDK/install-clang23}"
GAME_DIR="${GAME_DIR:-$HOME/Games/minecraft-bedrock/game}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/minecraft-bedrock/prefix}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$SCRIPT_DIR/../logs/gameinput-trace.log"

export WINEPREFIX="$PREFIX_DIR"
export WINEDLLOVERRIDES="d3d11,dxgi=n"
export WINEESYNC=1
export WINEFSYNC=1
export WINEDEBUG=+loaddll,+module,+ginput

OPTIONS_FILE="$PREFIX_DIR/drive_c/users/$(whoami)/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/minecraftpe/options.txt"
[ -f "$OPTIONS_FILE" ] && sed -i 's/^graphics_mode:[0-9]\+/graphics_mode:0/' "$OPTIONS_FILE"

echo "Tracing GameInput loading..."
echo "Log: $LOG"
"$WINEGDK_DIR/bin/wine" "$GAME_DIR/Minecraft.Windows.exe" >"$LOG" 2>&1
