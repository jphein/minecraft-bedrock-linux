#!/usr/bin/env bash
# VANILLA bare-WineGDK launch. Usage: launch-vanilla-winegdk.sh <install_dir> <variant> [wait]
#   e.g. launch-vanilla-winegdk.sh ~/Projects/winegdk-vanilla/install-vanilla-lukas lukas 150
#
# Vanilla = the runtime's OWN builtin graphics (wined3d) and OWN builtin gameinput.
# NOT applied (so it's vanilla): DXVK, custom GameInput stub, WM_POINTER patch, exe NOP.
# Minimal game-side setup only (see SETUP_VANILLA.md): GameConfigHelper (game dir),
# midlproxystub (prefix system32), GameInputRedist forced to builtin. graphics_mode:0.
set -uo pipefail
INSTALL="${1:?install dir}"; VAR="${2:?variant name}"; WAIT="${3:-150}"
WINE="$INSTALL/bin/wine"
REPO=/home/jp/Projects/minecraft-bedrock-linux
GAME_DIR="${GAME_DIR:-$HOME/Games/minecraft-bedrock/game}"
PFX="$HOME/Games/vanilla-prefixes/winegdk-$VAR"
OUT="/tmp/mctest/vanilla-winegdk-$VAR"; mkdir -p "$OUT" "$PFX"
LOG="$OUT/launch.log"; EXE="$GAME_DIR/Minecraft.Windows.exe"
export DISPLAY="${DISPLAY:-:0}"

[ -x "$WINE" ] || { echo "ERROR: wine missing at $WINE"; exit 1; }
echo "=== VANILLA WineGDK [$VAR] ==="; echo "wine: $WINE"; "$WINE" --version 2>&1 | head -1
echo "game: $EXE"; echo "prefix: $PFX"

pkill -9 -f 'Minecraft\.Windows\.exe' 2>/dev/null; sleep 2

export WINEPREFIX="$PFX"
export WINEESYNC=1 WINEFSYNC=1
# builtin GameInput redist (skip MS redist's Legacy.Gaming.Input WinRT crash); builtin graphics.
export WINEDLLOVERRIDES="GameInputRedist=b"
export WINEDEBUG="${WINEDEBUG:-+loaddll,+module}"

# init prefix if new
if [ ! -d "$PFX/drive_c/windows/system32" ]; then
  echo "initializing prefix (wineboot)..."; WINEDEBUG=-all "$WINE" wineboot -i >/dev/null 2>&1; sleep 3
fi
# minimal launch-enabling stubs (documented)
cp -f "$REPO/stubs/gameconfighelper/GameConfigHelper.dll" "$GAME_DIR/GameConfigHelper.dll" 2>/dev/null && echo "deployed GameConfigHelper.dll -> game dir"
MIDL="api-ms-win-core-com-midlproxystub-l1-1-0.dll"
cp -f "$REPO/stubs/midlproxystub/$MIDL" "$PFX/drive_c/windows/system32/$MIDL" 2>/dev/null && echo "deployed midlproxystub -> prefix system32"

# graphics_mode:0 if options exist
OPT="$PFX/drive_c/users/$(whoami)/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/minecraftpe/options.txt"
[ -f "$OPT" ] && { sed -i 's/^graphics_mode:[0-9]\+/graphics_mode:0/' "$OPT"; sed -i 's/^gfx_fullscreen:[0-9]\+/gfx_fullscreen:1/' "$OPT"; echo "patched graphics_mode:0 + gfx_fullscreen:1 (for capture focus)"; }

echo "launching (log: $LOG)..."
"$WINE" "$EXE" >"$LOG" 2>&1 &
PID=$!
echo "pid $PID; capturing for ${WAIT}s..."
bash "$REPO/scripts/capture-game.sh" "$OUT" "$WAIT" Minecraft

{
  echo "### GameInput / required-component / WinRT"
  grep -iE 'gameinput|required component|Legacy.Gaming|GameInputInitialize|GameInputCreate|RoGetActivationFactory.*CoreInput' "$LOG" 2>/dev/null | head -25
  echo "### cohtml / Renoir / shared-resource"
  grep -iE 'cohtml|renoir|OpenSharedResource|KeyedMutex|E_NOTIMPL' "$LOG" 2>/dev/null | head -20
  echo "### dll load failures"
  grep -iE 'err:module|import_dll|cannot find|failed to load' "$LOG" 2>/dev/null | sort | uniq -c | sort -rn | head -20
} > "$OUT/findings.txt"
echo "--- findings ---"; head -25 "$OUT/findings.txt"
kill -9 "$PID" 2>/dev/null; pkill -9 -f 'Minecraft\.Windows\.exe' 2>/dev/null
echo "=== done [$VAR] — review $OUT/shot-*.png ==="
