#!/usr/bin/env bash
# Debug launch: captures Wine debug output to a timestamped log file
# Usage: ./debug-launch.sh [--verbose]

set -euo pipefail

GAME_DIR="${GAME_DIR:-$HOME/vmshare/minecraft-bedrock}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/MinecraftBedrock/prefix}"
GDK_PROTON_DIR="${GDK_PROTON_DIR:-$HOME/.steam/root/compatibilitytools.d/GDK-Proton10-32}"

WINEDEBUG_CHANNELS="+loaddll,err+all,warn+module"
if [[ "${1:-}" == "--verbose" ]]; then
    WINEDEBUG_CHANNELS="+loaddll,+seh,+module,err+all,warn+all"
    echo "[debug] Verbose mode enabled"
fi

LOGFILE="/tmp/minecraft-debug-$(date +%F-%H%M%S).log"
echo "[debug] Logging to: $LOGFILE"
echo "[debug] WINEDEBUG=$WINEDEBUG_CHANNELS"

export UMU_ID=umu-0
export SteamGameId=0
export PROTON_NO_NTSYNC=1
export STEAM_COMPAT_DATA_PATH="$PREFIX_DIR"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/root"
export PROTONPATH="$GDK_PROTON_DIR"
export WINEDEBUG="$WINEDEBUG_CHANNELS"

"$GDK_PROTON_DIR/proton" run "$GAME_DIR/Minecraft.Windows.exe" 2>&1 | tee "$LOGFILE"
EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "=== Debug Summary ==="
echo "Log file: $LOGFILE"
echo "Exit code: $EXIT_CODE"
UNIMP=$(grep -ci "unimplemented" "$LOGFILE" 2>/dev/null || true)
ERRS=$(grep -ci "^[0-9a-f]*:err+" "$LOGFILE" 2>/dev/null || true)
echo "Unimplemented stubs: $UNIMP"
echo "Error lines: $ERRS"
if [[ "$UNIMP" -gt 0 ]]; then
    echo ""
    echo "--- Unimplemented (deduplicated) ---"
    grep -i "unimplemented" "$LOGFILE" | sort -u | head -20
fi
if [[ "$ERRS" -gt 0 ]]; then
    echo ""
    echo "--- Errors (deduplicated) ---"
    grep "^[0-9a-f]*:err+" "$LOGFILE" | sort -u | head -20
fi
exit "$EXIT_CODE"
