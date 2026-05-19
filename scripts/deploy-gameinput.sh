#!/usr/bin/env bash
# Deploy GameInput DLLs from a WineGDK build into GDK-Proton and the Wine prefix.
#
# Background:
#   Microsoft's GameInputRedist.msi installs gameinput.dll and gameinputredist.dll
#   into the Wine prefix. Those native Windows DLLs crash under Wine/Proton because
#   they depend on kernel-level HID support that Wine doesn't provide. GDK-Proton's
#   WineGDK fork includes builtin replacements that stub the GameInput API safely.
#
#   This script copies the builtin DLLs from a WineGDK build directory into both
#   GDK-Proton's wine lib (so Proton can find them) and the Wine prefix's system32
#   (overwriting the crash-prone native versions installed by the MSI).
#
#   At launch time, WINEDLLOVERRIDES="GameInputRedist=b" tells Wine to prefer the
#   builtin DLL over the native one in the prefix. The launch scripts and Lutris
#   config set this automatically.
#
# Usage:
#   ./scripts/deploy-gameinput.sh <winegdk-build-dir>
#
#   Example:
#   ./scripts/deploy-gameinput.sh ~/Projects/WineGDK/build64
#
# Environment variables (all optional):
#   GDK_PROTON_DIR — GDK-Proton install path (default: ~/.steam/root/compatibilitytools.d/GDK-Proton10-32)
#   PREFIX_DIR     — Wine prefix path        (default: ~/Games/MinecraftBedrock/prefix)

set -euo pipefail

BUILD_DIR="${1:?Usage: $0 <winegdk-build-dir>}"

GDK_PROTON_DIR="${GDK_PROTON_DIR:-$HOME/.steam/root/compatibilitytools.d/GDK-Proton10-32}"
PREFIX_DIR="${PREFIX_DIR:-$HOME/Games/MinecraftBedrock/prefix}"

PROTON_DLL_DIR="$GDK_PROTON_DIR/files/lib/wine/x86_64-windows"
PREFIX_SYS32="$PREFIX_DIR/pfx/drive_c/windows/system32"

echo "=== Deploy GameInput DLLs ==="
echo "  Build dir:    $BUILD_DIR"
echo "  GDK-Proton:   $GDK_PROTON_DIR"
echo "  Prefix:       $PREFIX_DIR"
echo ""

# Validate build dir has the DLLs we need
DLLS="gameinput.dll gameinputredist.dll"
for dll in $DLLS; do
    # WineGDK build output is typically at dlls/<name>/<name>.dll
    DLL_NAME="${dll%.dll}"
    CANDIDATES=(
        "$BUILD_DIR/dlls/$DLL_NAME/$dll"
        "$BUILD_DIR/$dll"
        "$BUILD_DIR/dlls/$DLL_NAME/$DLL_NAME.dll.so"
    )
    FOUND=""
    for candidate in "${CANDIDATES[@]}"; do
        if [ -f "$candidate" ]; then
            FOUND="$candidate"
            break
        fi
    done
    if [ -z "$FOUND" ]; then
        echo "ERROR: $dll not found in build dir"
        echo "  Searched:"
        for candidate in "${CANDIDATES[@]}"; do
            echo "    $candidate"
        done
        exit 1
    fi
done

# 1. Copy to GDK-Proton's wine lib directory
echo "[1/2] Copying to GDK-Proton ($PROTON_DLL_DIR)..."
if [ ! -d "$PROTON_DLL_DIR" ]; then
    echo "  ERROR: GDK-Proton DLL dir not found: $PROTON_DLL_DIR"
    exit 1
fi

for dll in $DLLS; do
    DLL_NAME="${dll%.dll}"
    SRC=""
    for candidate in "$BUILD_DIR/dlls/$DLL_NAME/$dll" "$BUILD_DIR/$dll"; do
        if [ -f "$candidate" ]; then
            SRC="$candidate"
            break
        fi
    done
    # Back up original if it exists and hasn't been backed up
    if [ -f "$PROTON_DLL_DIR/$dll" ] && [ ! -f "$PROTON_DLL_DIR/$dll.orig" ]; then
        cp "$PROTON_DLL_DIR/$dll" "$PROTON_DLL_DIR/$dll.orig"
        echo "  Backed up: $dll -> $dll.orig"
    fi
    cp "$SRC" "$PROTON_DLL_DIR/$dll"
    echo "  Installed: $dll"
done

# 2. Copy to Wine prefix system32 (overwrites native versions from MSI)
echo "[2/2] Copying to Wine prefix ($PREFIX_SYS32)..."
mkdir -p "$PREFIX_SYS32"
for dll in $DLLS; do
    DLL_NAME="${dll%.dll}"
    SRC=""
    for candidate in "$BUILD_DIR/dlls/$DLL_NAME/$dll" "$BUILD_DIR/$dll"; do
        if [ -f "$candidate" ]; then
            SRC="$candidate"
            break
        fi
    done
    cp "$SRC" "$PREFIX_SYS32/$dll"
    echo "  Installed: $dll"
done

echo ""
echo "=== Done ==="
echo ""
echo "The builtin GameInput DLLs are now in place. The launch scripts already set"
echo "WINEDLLOVERRIDES=\"GameInputRedist=b\" so Wine will prefer the builtin version."
echo ""
echo "If you reinstall GameInputRedist.msi (e.g., via update.sh), re-run this script"
echo "to overwrite the native DLLs again."
