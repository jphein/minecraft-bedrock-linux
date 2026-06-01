#!/usr/bin/env bash
#
# Minecraft Bedrock 1.26.21 launcher for Linux (WineGDK + DXVK).
#
#   ./play-bedrock.sh              # fullscreen (default)
#   ./play-bedrock.sh --windowed   # windowed
#   ./play-bedrock.sh --no-proxy   # don't start the LAN proxy for remote servers
#
# What it does, in order:
#   1. CLEAN UP stale processes (CRITICAL): leftover lan-proxy / wineserver / game
#      instances from a previous run cause a silent "no window" startup hang.
#   2. Start the LAN proxy so the Tailscale BDS servers (Luna etc.) show up under
#      Minecraft's "LAN Games" — no manual server-address typing needed.
#   3. Launch the game (builtin GameInput, mouse-device dropped to avoid the
#      "missing required component" screen; gamepad works via the GetCurrentReading
#      XInput/DInput fix in our WineGDK build).
#
set -uo pipefail

# ---- config -----------------------------------------------------------------
WINEGDK="${WINEGDK_DIR:-$HOME/Projects/WineGDK/install-clang23}"
GAME_DIR="${GAME_DIR:-$HOME/Games/minecraft-bedrock/game}"
PREFIX="${PREFIX_DIR:-$HOME/Games/minecraft-bedrock/prefix}"
REPO="$HOME/Projects/minecraft-bedrock-linux"
OPT="$PREFIX/drive_c/users/$(whoami)/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/minecraftpe/options.txt"

# Remote BDS servers to advertise as LAN games:  remoteIP:remotePort:localPort:Name
SERVERS=(
  "REDACTED-IP:19132:19132:Redacted Server"
  "REDACTED-IP:8888:8888:donkey"
  "REDACTED-IP:8890:8890:Luna"
  "REDACTED-IP:19132:19134:Galaxy Tab"   # redacted-host (offline until powered on; fix IP/port if needed)
)

WINDOWED=0
USE_PROXY=1
for arg in "$@"; do
  case "$arg" in
    --windowed|-w) WINDOWED=1 ;;
    --no-proxy)    USE_PROXY=0 ;;
    --fullscreen|-f) WINDOWED=0 ;;
  esac
done

# ---- 1. clean up stale processes (the no-window gotcha) ----------------------
echo "[play] cleaning up stale processes..."
pkill -9 -f 'Minecraft\.Windows\.exe' 2>/dev/null || true
pkill -9 -f 'lan-proxy\.py'           2>/dev/null || true
"$WINEGDK/bin/wineserver" -k 2>/dev/null || true
sleep 3

# ---- 2. LAN proxy for remote (Tailscale) servers ----------------------------
if [ "$USE_PROXY" = 1 ]; then
  echo "[play] starting LAN proxy for ${#SERVERS[@]} servers..."
  setsid nohup python3 "$REPO/scripts/lan-proxy.py" "${SERVERS[@]}" \
      >/tmp/lan-proxy.log 2>&1 </dev/null &
  disown 2>/dev/null || true
  sleep 1
fi

# ---- 3. graphics mode --------------------------------------------------------
if [ -f "$OPT" ]; then
  sed -i 's/^graphics_mode:[0-9]\+/graphics_mode:0/' "$OPT"
  if [ "$WINDOWED" = 1 ]; then
    sed -i 's/^gfx_fullscreen:[0-9]\+/gfx_fullscreen:0/' "$OPT"
    echo "[play] windowed mode"
  else
    sed -i 's/^gfx_fullscreen:[0-9]\+/gfx_fullscreen:1/' "$OPT"
    echo "[play] fullscreen mode"
  fi
fi

# ---- 4. launch ---------------------------------------------------------------
export WINEPREFIX="$PREFIX" WINEESYNC=1 WINEFSYNC=1 WINEDEBUG=-all
# builtin gameinput (clears error screen w/ no redist); native dwmapi proxy; stub the
# unimplemented ntuser private apisets.
export WINEDLLOVERRIDES="d3d11,dxgi=n;gameinput=b;dwmapi=n;api-ms-win-rtcore-ntuser-private-l1-1-1=n;ext-ms-win-ntuser-private-l1-1-1=n"
echo "[play] launching Minecraft Bedrock... (Servers tab / LAN Games for Luna)"
exec "$WINEGDK/bin/wine" "$GAME_DIR/Minecraft.Windows.exe"
