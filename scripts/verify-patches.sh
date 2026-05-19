#!/usr/bin/env bash
# Verify all patches are applied for Minecraft Bedrock on GDK-Proton.
# Override paths: PROTON_DIR, PREFIX_DIR, GAME_DIR
set -uo pipefail

PROTON_DIR="${PROTON_DIR:-$HOME/.steam/root/compatibilitytools.d/GDK-Proton10-32}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/MinecraftBedrock/prefix}"
GAME_DIR="${GAME_DIR:-$HOME/vmshare/minecraft-bedrock}"
LAUNCH_SCRIPT="$(cd "$(dirname "$0")" && pwd)/launch.sh"
WINE_DLL="$PROTON_DIR/files/lib/wine/x86_64-windows"
PASS=0; FAIL=0; WARN=0

check() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then echo "  PASS  $label"; ((PASS++))
    else echo "  FAIL  $label"; ((FAIL++)); fi
}
warn() { echo "  WARN  $1"; ((WARN++)); }

echo "=== Minecraft Bedrock Patch Verification ==="
echo "Proton: $PROTON_DIR"
echo "Prefix: $PREFIX_DIR"
echo ""

# 1. ntdll.dll WNF exports
if [ -f "$WINE_DLL/ntdll.dll" ]; then
    check "ntdll.dll: NtQueryWnfStateData"  grep -qU NtQueryWnfStateData "$WINE_DLL/ntdll.dll"
    check "ntdll.dll: RtlSubscribeWnfStateChangeNotification" \
        grep -qU RtlSubscribeWnfStateChangeNotification "$WINE_DLL/ntdll.dll"
    check "ntdll.dll: ZwQueryWnfStateData"  grep -qU ZwQueryWnfStateData "$WINE_DLL/ntdll.dll"
else
    echo "  FAIL  ntdll.dll not found"; ((FAIL++))
fi

# 2. combase.dll ObjectStublessClient exports
if [ -f "$WINE_DLL/combase.dll" ]; then
    check "combase.dll: ObjectStublessClient3"  grep -qU ObjectStublessClient3 "$WINE_DLL/combase.dll"
    check "combase.dll: ObjectStublessClient32" grep -qU ObjectStublessClient32 "$WINE_DLL/combase.dll"
else
    echo "  FAIL  combase.dll not found"; ((FAIL++))
fi

# 3. rpcrt4.dll ObjectStublessClient exports
if [ -f "$WINE_DLL/rpcrt4.dll" ]; then
    check "rpcrt4.dll: ObjectStublessClient3" grep -qU ObjectStublessClient3 "$WINE_DLL/rpcrt4.dll"
else
    echo "  FAIL  rpcrt4.dll not found"; ((FAIL++))
fi

# 4. Launch script environment
if [ -f "$LAUNCH_SCRIPT" ]; then
    check "launch.sh: UMU_ID is set"          grep -q 'UMU_ID=' "$LAUNCH_SCRIPT"
    check "launch.sh: PROTON_NO_NTSYNC=1"     grep -q 'PROTON_NO_NTSYNC=1' "$LAUNCH_SCRIPT"
else
    warn "launch.sh not found at $LAUNCH_SCRIPT (skipped)"
fi

# 5. GameInputRedist.dll in prefix
check "GameInputRedist.dll in prefix" \
    test -n "$(find "$PREFIX_DIR" -iname 'GameInputRedist.dll' -print -quit 2>/dev/null)"

# 6. Wine prefix structure
check "Wine prefix exists (pfx/)"            test -d "$PREFIX_DIR/pfx"
check "Wine prefix has system32"              test -d "$PREFIX_DIR/pfx/drive_c/windows/system32"
check "Wine prefix has user.reg"              test -f "$PREFIX_DIR/pfx/user.reg"

echo ""
echo "Results: $PASS passed, $FAIL failed, $WARN warnings"
[ "$FAIL" -eq 0 ] && echo "All checks passed." || exit 1
