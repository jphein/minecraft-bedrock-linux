#!/usr/bin/env bash
# Test-matrix harness for the cohtml-UI investigation.
#
# Runs ONE named config: kills any old game, applies that config's graphics
# settings + DLL overrides + tracing, launches, waits for the menu, takes a
# screenshot, and greps the log for shared-resource / keyed-mutex markers.
# Review the screenshot to decide UI=✅/❌ and record it in TEST_MATRIX.md.
#
# Usage:   scripts/run-test.sh <config> [seconds_to_wait]
#          scripts/run-test.sh list
# Example: scripts/run-test.sh trace-shared 40
#
# Output goes to /tmp/mctest/<config>/ : launch.log, screenshot.png, findings.txt
set -uo pipefail

CONFIG="${1:-list}"
WAIT="${2:-35}"

WINEGDK_DIR="${WINEGDK_DIR:-$HOME/Projects/WineGDK/install-clang23}"
GAME_DIR="${GAME_DIR:-$HOME/Games/minecraft-bedrock/game}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/minecraft-bedrock/prefix}"
WINE="$WINEGDK_DIR/bin/wine"
EXE="$GAME_DIR/Minecraft.Windows.exe"
OPTIONS_FILE="$PREFIX_DIR/drive_c/users/$(whoami)/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/minecraftpe/options.txt"

# Defaults (overridden per-config below)
GRAPHICS_MODE=0          # 0=Classic, 2=deferred/PBR (crashes under Wine)
GRAPHICS_API=0           # RenderDragon backend selector in options.txt
DLLOVERRIDES="d3d11,dxgi=n;GameInput=n;api-ms-win-rtcore-ntuser-private-l1-1-1=n;ext-ms-win-ntuser-private-l1-1-1=n"
WINEDEBUG_VAL="-all"
EXTRA_ENV=()             # array of VAR=VALUE
DESC=""

list_configs() {
  cat <<'EOF'
Available configs (see TEST_MATRIX.md for what each one tests):
  baseline       clang-23, DXVK(d3d11)+vkd3d(d3d12), api:0, mode:0  — current known state (UI broken)
  trace-shared   baseline + full +dxgi,+d3d11 trace + DXVK/VKD3D logs — hunt OpenSharedResource* (KEY)
  force-d3d11    force RenderDragon D3D11 (graphics_api), DXVK only    — DXVK<->DXVK share path
  force-d3d12    force RenderDragon D3D12 (graphics_api), vkd3d        — VKD3D<->DXVK share path
  wined3d        builtin wined3d instead of DXVK                       — control
  cohtml-cpu     set cohtml/Renoir CPU rasterizer env (if honored)     — if UI appears => GPU-share is the break
  clang20        same as baseline but the clang-20 build               — build-compiler control
EOF
}

case "$CONFIG" in
  list|"")      list_configs; exit 0 ;;
  baseline)     DESC="DXVK+vkd3d, api:0, mode:0 (current state)" ;;
  trace-shared) DESC="baseline + shared-resource tracing"
                WINEDEBUG_VAL="+dxgi,+d3d11"
                EXTRA_ENV=( "DXVK_LOG_LEVEL=info" "VKD3D_DEBUG=warn" "DXVK_LOG_PATH=/tmp/mctest/trace-shared" "VKD3D_LOG_FILE=/tmp/mctest/trace-shared/vkd3d.log" ) ;;
  force-d3d11)  DESC="force RenderDragon D3D11, DXVK only"
                GRAPHICS_API=1   # NOTE: confirm the D3D11 value for this MC build; adjust if wrong
                DLLOVERRIDES="d3d11,dxgi=n;d3d12,d3d12core=b;GameInput=n;api-ms-win-rtcore-ntuser-private-l1-1-1=n;ext-ms-win-ntuser-private-l1-1-1=n" ;;
  force-d3d12)  DESC="force RenderDragon D3D12, vkd3d-proton"
                GRAPHICS_API=2 ;;  # NOTE: confirm the D3D12 value; adjust if wrong
  wined3d)      DESC="builtin wined3d (control)"
                DLLOVERRIDES="d3d11,dxgi,d3d12,d3d12core=b;GameInput=n;api-ms-win-rtcore-ntuser-private-l1-1-1=n;ext-ms-win-ntuser-private-l1-1-1=n" ;;
  cohtml-cpu)   DESC="cohtml/Renoir CPU rasterizer (if honored)"
                # Speculative — Coherent env knobs vary by integration; harmless if ignored.
                EXTRA_ENV=( "COHTML_FORCE_SOFTWARE=1" "COHTML_DISABLE_GPU=1" ) ;;
  clang20)      DESC="clang-20 build (compiler control)"
                WINEGDK_DIR="$HOME/Projects/WineGDK/install"
                WINE="$WINEGDK_DIR/bin/wine" ;;
  *)            echo "Unknown config: $CONFIG"; echo; list_configs; exit 1 ;;
esac

OUT="/tmp/mctest/$CONFIG"; mkdir -p "$OUT"
LOG="$OUT/launch.log"

echo "=== config: $CONFIG — $DESC ==="
echo "wine: $WINE"
[[ -x "$WINE" ]] || { echo "ERROR: wine not found at $WINE (build it first)"; exit 1; }

# --- kill any old game (per project rule: never leave zombies) ---
# Kill ONLY the game exe by exact name — NEVER a broad 'wine|Minecraft' grep, which
# would also kill concurrent WineGDK builds and this script's own process.
pkill -9 -f 'Minecraft\.Windows\.exe' 2>/dev/null
sleep 2
echo "old game processes remaining: $(pgrep -cf 'Minecraft\.Windows\.exe' || true)"

# --- apply graphics options ---
if [[ -f "$OPTIONS_FILE" ]]; then
  sed -i "s/^graphics_mode:[0-9]\+/graphics_mode:$GRAPHICS_MODE/" "$OPTIONS_FILE"
  sed -i "s/^graphics_api:[0-9]\+/graphics_api:$GRAPHICS_API/"   "$OPTIONS_FILE"
  echo "options: graphics_mode:$GRAPHICS_MODE graphics_api:$GRAPHICS_API"
fi

# --- launch ---
export WINEPREFIX="$PREFIX_DIR"
export WINEDLLOVERRIDES="$DLLOVERRIDES"
export WINEESYNC=1 WINEFSYNC=1
export WINEDEBUG="$WINEDEBUG_VAL"
for kv in "${EXTRA_ENV[@]}"; do export "$kv"; done

echo "launching (log: $LOG) ..."
"$WINE" "$EXE" >"$LOG" 2>&1 &
GAME_PID=$!
echo "pid $GAME_PID; waiting ${WAIT}s for menu ..."
sleep "$WAIT"

# --- screenshot (GNOME Wayland) ---
SHOT="$OUT/screenshot.png"
if command -v gnome-screenshot &>/dev/null; then
  gnome-screenshot -f "$SHOT" 2>/dev/null && echo "screenshot: $SHOT"
else
  echo "gnome-screenshot not found — capture manually"
fi

# --- grep the log for the shared-resource smoking gun ---
FIND="$OUT/findings.txt"
{
  echo "### shared-resource / keyed-mutex markers in $LOG"
  grep -iE 'OpenSharedResource|KeyedMutex|SHARED_NTHANDLE|SHARED_KEYEDMUTEX|D3D11_RESOURCE_MISC_SHARED|not supported on this platform|E_NOTIMPL|Fixing up.*MiscFlags|shared resource' "$LOG" | sort | uniq -c | sort -rn | head -40
  echo
  echo "### cohtml / Renoir / Gameface mentions"
  grep -iE 'cohtml|renoir|gameface|coherent' "$LOG" | head -20
  echo
  echo "### err/fixme summary (top 30)"
  grep -iE '^[0-9a-f]+:(err|fixme):' "$LOG" | sed -E 's/[0-9a-fx]+//; s/  +/ /g' | sort | uniq -c | sort -rn | head -30
} > "$FIND"
echo "findings: $FIND"
echo "--- top findings ---"; head -20 "$FIND"

# --- stop the game ---
kill -9 "$GAME_PID" 2>/dev/null
pkill -9 -f 'Minecraft.Windows.exe' 2>/dev/null
echo "=== done: $CONFIG — review $SHOT then record UI verdict in TEST_MATRIX.md ==="
