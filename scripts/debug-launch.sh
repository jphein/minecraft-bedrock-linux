#!/usr/bin/env bash
# Debug launch: captures Wine debug output to a timestamped log file
# Usage: ./debug-launch.sh [--verbose]

set -euo pipefail

WINEGDK_DIR="${WINEGDK_DIR:-$HOME/Projects/WineGDK/install}"
GAME_DIR="${GAME_DIR:-$HOME/Games/minecraft-bedrock/game}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/minecraft-bedrock/prefix}"

WINEDEBUG_CHANNELS="+loaddll,err+all,warn+module"
if [[ "${1:-}" == "--verbose" ]]; then
    WINEDEBUG_CHANNELS="+loaddll,+seh,+module,err+all,warn+all"
    echo "[debug] Verbose mode enabled"
fi

LOGFILE="$HOME/minecraft-debug-$(date +%F-%H%M%S).log"
echo "[debug] Logging to: $LOGFILE"
echo "[debug] WINEDEBUG=$WINEDEBUG_CHANNELS"

export WINEPREFIX="$PREFIX_DIR"
export WINEDEBUG="$WINEDEBUG_CHANNELS"
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

"$WINE" "$GAME_DIR/Minecraft.Windows.exe" 2>&1 | tee "$LOGFILE"
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
