#!/usr/bin/env bash
# Debug launch: Minecraft Bedrock via GDK-Proton with Wine debug logging
# Usage: ./debug-launch-proton.sh [--verbose]
#
# Black screen fix: force ALL graphics DLLs to Wine builtins so bgfx uses
# D3D11 -> wined3d -> OpenGL instead of D3D12 -> vkd3d-proton -> Vulkan.
# PROTON_USE_WINED3D=1 is the reliable way to achieve this, since Proton's
# own setup script can override plain WINEDLLOVERRIDES.

set -euo pipefail

GAME_DIR="${GAME_DIR:-$HOME/Games/minecraft-bedrock-edition-lutris/game}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/minecraft-bedrock-edition-lutris/prefix}"
GDK_PROTON_DIR="${GDK_PROTON_DIR:-$HOME/Games/minecraft-bedrock-edition-lutris/GDK-Proton10-32}"

WINEDEBUG_CHANNELS="+loaddll,err+all,warn+module"
if [[ "${1:-}" == "--verbose" ]]; then
    WINEDEBUG_CHANNELS="+loaddll,+seh,+module,err+all,warn+all"
    echo "[debug] Verbose mode enabled"
fi

LOGFILE="$HOME/minecraft-proton-debug-$(date +%F-%H%M%S).log"
echo "[debug] Logging to: $LOGFILE"
echo "[debug] WINEDEBUG=$WINEDEBUG_CHANNELS"

# Proton / Steam runtime env vars
export STEAM_COMPAT_DATA_PATH="$PREFIX_DIR"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$PREFIX_DIR"
export UMU_ID="umu-0"
export SteamAppId=0
export SteamGameId=0

# Black screen fix: tell Proton to use wined3d (OpenGL) instead of DXVK/vkd3d-proton.
# This makes bgfx's D3D11 path go through wined3d->OpenGL, which actually renders.
export PROTON_USE_WINED3D=1

# Belt-and-suspenders: also set WINEDLLOVERRIDES for any codepath that checks them.
# Forces builtins for all graphics DLLs and GameInputRedist.
export WINEDLLOVERRIDES="dxgi=b;d3d11=b;d3d12=b;d3d12core=b;GameInputRedist=b"

export WINEDEBUG="$WINEDEBUG_CHANNELS"

PROTON="$GDK_PROTON_DIR/proton"
if [[ ! -x "$PROTON" ]]; then
    echo "ERROR: proton not found at $PROTON"
    echo "Set GDK_PROTON_DIR to your GDK-Proton install directory."
    exit 1
fi

if [[ ! -f "$GAME_DIR/Minecraft.Windows.exe" ]]; then
    echo "ERROR: Minecraft.Windows.exe not found in $GAME_DIR"
    echo "Set GAME_DIR to the directory containing the game."
    exit 1
fi

# Work around a race condition in Minecraft's Deferred Rendering / PBR pipeline:
# When graphics_mode is set to 2 (Deferred/RTX), rendering threads may access
# MaterialDefinition objects before they are fully initialized, causing a crash.
# Setting graphics_mode:0 (Classic) avoids the deferred material paths entirely.
# The game auto-resets graphics_mode to 2 each launch, so we must patch every time.
#
# Proton maps the Windows user to "steamuser", not the host username.
OPTIONS_FILE="$PREFIX_DIR/pfx/drive_c/users/steamuser/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/minecraftpe/options.txt"
if [[ -f "$OPTIONS_FILE" ]]; then
    sed -i 's/^graphics_mode:[0-9]\+/graphics_mode:0/' "$OPTIONS_FILE"
fi

echo "[debug] PROTON_USE_WINED3D=$PROTON_USE_WINED3D"
echo "[debug] WINEDLLOVERRIDES=$WINEDLLOVERRIDES"
echo "[debug] Launching: $PROTON run $GAME_DIR/Minecraft.Windows.exe"

"$PROTON" run "$GAME_DIR/Minecraft.Windows.exe" 2>&1 | tee "$LOGFILE"
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
