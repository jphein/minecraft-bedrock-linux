#!/usr/bin/env bash
# Playable launch: builtin GameInput (clears error screen + menu) + hook GameInputRedist.dll
# (no GameInputInitialize export -> Create path; installs cohtml pointer-click hook).
set -uo pipefail
WINE=${WINEGDK_DIR:-$HOME/Projects/WineGDK/install-clang23}/bin/wine
GD=${GAME_DIR:-$HOME/Games/minecraft-bedrock/game}
PFX=${PREFIX_DIR:-$HOME/Games/minecraft-bedrock/prefix}
OPT="$PFX/drive_c/users/$(whoami)/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/minecraftpe/options.txt"
pkill -9 -f 'Minecraft\.Windows\.exe' 2>/dev/null || true; sleep 1
[ -f "$OPT" ] && sed -i 's/^graphics_mode:[0-9]\+/graphics_mode:0/; s/^gfx_fullscreen:[0-9]\+/gfx_fullscreen:1/' "$OPT"
export WINEPREFIX="$PFX" WINEESYNC=1 WINEFSYNC=1 WINEDEBUG=-all
export WINEDLLOVERRIDES="d3d11,dxgi=n;gameinput=b;dwmapi=n;api-ms-win-rtcore-ntuser-private-l1-1-1=n;ext-ms-win-ntuser-private-l1-1-1=n"
exec "$WINE" "$GD/Minecraft.Windows.exe"
