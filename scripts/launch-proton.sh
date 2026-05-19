#!/usr/bin/env bash
# Launch Minecraft Bedrock via GDK-Proton (Proton fork with GDK/Xbox Live support)
#
# Black screen fix: force ALL graphics DLLs to Wine builtins so bgfx uses
# D3D11 -> wined3d -> OpenGL instead of D3D12 -> vkd3d-proton -> Vulkan.
# PROTON_USE_WINED3D=1 is the reliable way to achieve this, since Proton's
# own setup script can override plain WINEDLLOVERRIDES.

set -euo pipefail

GAME_DIR="${GAME_DIR:-$HOME/Games/minecraft-bedrock-edition-lutris/game}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/minecraft-bedrock-edition-lutris/prefix}"
GDK_PROTON_DIR="${GDK_PROTON_DIR:-$HOME/Games/minecraft-bedrock-edition-lutris/GDK-Proton10-32}"

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

exec "$PROTON" run "$GAME_DIR/Minecraft.Windows.exe"
