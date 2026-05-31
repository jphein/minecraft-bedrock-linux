#!/usr/bin/env bash
# VANILLA GDK-Proton launch — stock runtime, minimal game-side setup, NO mods.
# Differs from launch-proton.sh: no PROTON_USE_WINED3D, no forced graphics builtins,
# no custom GameInput stub. Goal: observe out-of-the-box behavior (incl. GameInput).
#
# Usage: scripts/launch-vanilla-gdkproton.sh [wait_seconds]
# Output: /tmp/mctest/vanilla-gdkproton/{launch.log,screenshot.png,findings.txt}
set -uo pipefail
WAIT="${1:-40}"

GDK="${GDK:-$HOME/Games/GDK-Proton10-32}"            # real Weather-OS GDK-Proton (10-32)
GAME_DIR="${GAME_DIR:-$HOME/Games/minecraft-bedrock/game}"   # canonical 1.26.21.1
PFX="${PFX:-$HOME/Games/vanilla-prefixes/gdkproton}"        # fresh prefix
OUT=/tmp/mctest/vanilla-gdkproton; mkdir -p "$OUT" "$PFX"
LOG="$OUT/launch.log"
EXE="$GAME_DIR/Minecraft.Windows.exe"

echo "=== VANILLA GDK-Proton ==="
echo "proton: $GDK/proton"; echo "game: $EXE"; echo "prefix: $PFX"

# Kill ONLY the game exe — NEVER a broad 'wine|proton' grep (that kills concurrent
# builds and even this script, whose path contains "proton"/"Minecraft").
pkill -9 -f 'Minecraft\.Windows\.exe' 2>/dev/null
sleep 2

# minimal game-side setup (documented in SETUP_VANILLA.md): GameConfigHelper next to exe
CFG=/home/jp/Projects/minecraft-bedrock-linux/stubs/gameconfighelper/GameConfigHelper.dll
[ -f "$CFG" ] && cp -f "$CFG" "$GAME_DIR/GameConfigHelper.dll" && echo "deployed GameConfigHelper.dll to game dir"

# Proton env (stock)
export STEAM_COMPAT_DATA_PATH="$PFX"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/root"
export GAMEID=minecraft-bedrock-vanilla
export STORE=none SteamAppId=0 SteamGameId=0 UMU_ID=umu-0
# Force the runtime's builtin GameInput redist if present (the only "override"; see SETUP_VANILLA.md).
export WINEDLLOVERRIDES="GameInputRedist=b"
# capture wine/proton diagnostics
export PROTON_LOG=1 PROTON_LOG_DIR="$OUT"
export WINEDEBUG="+loaddll,+module"

# patch graphics_mode:0 if options.txt already exists (first run it won't)
OPT="$PFX/pfx/drive_c/users/steamuser/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/minecraftpe/options.txt"
[ -f "$OPT" ] && { sed -i 's/^graphics_mode:[0-9]\+/graphics_mode:0/' "$OPT"; sed -i 's/^gfx_fullscreen:[0-9]\+/gfx_fullscreen:1/' "$OPT"; echo "patched graphics_mode:0 + gfx_fullscreen:1 (for capture focus)"; }

echo "launching (log: $LOG)..."
"$GDK/proton" run "$EXE" >"$LOG" 2>&1 &
PID=$!
echo "pid $PID; capturing for ${WAIT}s (find+raise+multishot)..."
bash /home/jp/Projects/minecraft-bedrock-linux/scripts/capture-game.sh "$OUT" "$WAIT" Minecraft

# quick findings
{
  echo "### GameInput / required-component / WinRT markers"
  grep -iE 'gameinput|required component|Legacy.Gaming|RoGetActivationFactory|GameInputInitialize|GameInputCreate' "$LOG" "$OUT"/*.log 2>/dev/null | head -20
  echo "### shared-resource / cohtml"
  grep -iE 'OpenSharedResource|KeyedMutex|cohtml|renoir|E_NOTIMPL' "$LOG" "$OUT"/*.log 2>/dev/null | head -15
  echo "### errors loading dlls"
  grep -iE 'err:module|import_dll|failed to load|not found' "$LOG" 2>/dev/null | sort | uniq -c | sort -rn | head -15
} > "$OUT/findings.txt"
echo "--- findings ---"; head -25 "$OUT/findings.txt"

# leave it running a moment for a second screenshot opportunity? no — stop cleanly
kill -9 "$PID" 2>/dev/null; pkill -9 -f 'Minecraft.Windows.exe' 2>/dev/null
echo "=== done — review $OUT/screenshot.png ==="
