#!/usr/bin/env bash
# Launch Minecraft Bedrock directly via GDK-Proton (no Lutris needed)

set -euo pipefail

GAME_DIR="${GAME_DIR:-$HOME/vmshare/minecraft-bedrock}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/MinecraftBedrock/prefix}"
GDK_PROTON_DIR="${GDK_PROTON_DIR:-$HOME/.steam/root/compatibilitytools.d/GDK-Proton10-32}"

# Required for non-Steam games — without UMU_ID/SteamGameId, Proton uses wrong launch path and silently exits
export UMU_ID=umu-0
export SteamGameId=0
export PROTON_NO_NTSYNC=1
export STEAM_COMPAT_DATA_PATH="$PREFIX_DIR"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/root"
export PROTONPATH="$GDK_PROTON_DIR"

exec "$GDK_PROTON_DIR/proton" run "$GAME_DIR/Minecraft.Windows.exe"
