#!/usr/bin/env bash
# Collect diagnostic info for debugging Minecraft Bedrock on Linux.
# Override paths: PROTON_DIR, PREFIX_DIR, GAME_DIR
set -uo pipefail

PROTON_DIR="${PROTON_DIR:-$HOME/.steam/root/compatibilitytools.d/GDK-Proton10-32}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/MinecraftBedrock/prefix}"
GAME_DIR="${GAME_DIR:-$HOME/vmshare/minecraft-bedrock}"
WINE_DLL="$PROTON_DIR/files/lib/wine/x86_64-windows"
SYS32="$PREFIX_DIR/pfx/drive_c/windows/system32"
OUT="/tmp/minecraft-diagnostic-$(date +%Y-%m-%d).txt"
exec > >(tee "$OUT") 2>&1

echo "=== Minecraft Bedrock Linux Diagnostic — $(date) ==="
echo ""
echo "--- System ---"
echo "Distro:  $(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
echo "Kernel:  $(uname -r)"
echo "GPU:     $(lspci 2>/dev/null | grep -i 'vga\|3d' | sed 's/^[^ ]* //')"
if command -v nvidia-smi &>/dev/null; then
    echo "Driver:  nvidia $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null)"
elif [ -f /sys/module/amdgpu/version ]; then
    echo "Driver:  amdgpu $(cat /sys/module/amdgpu/version)"
else
    echo "Driver:  $(glxinfo 2>/dev/null | grep 'OpenGL version' || echo 'unknown')"
fi

echo ""
echo "--- GDK-Proton ---"
echo "Path: $PROTON_DIR"
if [ -f "$PROTON_DIR/version" ]; then echo "Version: $(cat "$PROTON_DIR/version")"
elif [ -f "$PROTON_DIR/RELEASE" ]; then echo "Release: $(cat "$PROTON_DIR/RELEASE")"
else echo "Version: $(basename "$PROTON_DIR")"; fi
echo "Wine:    $("$PROTON_DIR/files/bin/wine64" --version 2>/dev/null || echo 'not found')"

echo ""
echo "--- DLL Patches ---"
for sym in NtQueryWnfStateData RtlSubscribeWnfStateChangeNotification ZwQueryWnfStateData; do
    printf "  ntdll.dll  %-44s %s\n" "$sym" \
        "$(strings "$WINE_DLL/ntdll.dll" 2>/dev/null | grep -qF "$sym" && echo OK || echo MISSING)"
done
for dll in combase.dll rpcrt4.dll; do
    printf "  %-11s %-44s %s\n" "$dll" "ObjectStublessClient3" \
        "$(strings "$WINE_DLL/$dll" 2>/dev/null | grep -qF ObjectStublessClient3 && echo OK || echo MISSING)"
done

echo ""
echo "--- Prefix Health ($PREFIX_DIR) ---"
for dll in ntdll.dll kernel32.dll kernelbase.dll combase.dll rpcrt4.dll; do
    printf "  system32/%-18s %s\n" "$dll" "$([ -f "$SYS32/$dll" ] && echo present || echo MISSING)"
done
GIRD=$(find "$PREFIX_DIR" -iname 'GameInputRedist.dll' -print -quit 2>/dev/null)
echo "  GameInputRedist.dll      ${GIRD:-MISSING}"

echo ""
echo "--- Launch Environment ---"
LAUNCH="$(cd "$(dirname "$0")" && pwd)/launch.sh"
if [ -f "$LAUNCH" ]; then grep -E '^\s*export ' "$LAUNCH" | sed 's/^/  /'
else echo "  launch.sh not found at $LAUNCH"; fi

echo ""
echo "--- Game ($GAME_DIR) ---"
MANIFEST="$GAME_DIR/appxmanifest.xml"
if [ -f "$MANIFEST" ]; then echo "Version: $(grep -oP 'Version="\K[^"]+' "$MANIFEST" | head -1)"
else echo "Version: appxmanifest.xml not found"; fi
[ -f "$GAME_DIR/Minecraft.Windows.exe" ] \
    && echo "Exe:     $(file "$GAME_DIR/Minecraft.Windows.exe" | cut -d: -f2-)" \
    || echo "Exe:     NOT FOUND"

echo ""
echo "--- Recent Wine Logs (last 24h in /tmp/) ---"
LOGS=$(find /tmp -maxdepth 1 -name '*.log' -mmin -1440 2>/dev/null | head -5)
if [ -n "$LOGS" ]; then
    for f in $LOGS; do echo "  $f ($(wc -l < "$f") lines)"; done
else echo "  None found."; fi

echo ""
echo "=== Saved to $OUT ==="
