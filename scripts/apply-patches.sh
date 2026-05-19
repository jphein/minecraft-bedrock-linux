#!/usr/bin/env bash
# Apply DLL patches needed for Minecraft Bedrock on GDK-Proton.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Configuration ---
# Override these via environment or edit here.
: "${PROTON_DIR:="$HOME/.steam/root/compatibilitytools.d/GDK-Proton10-32"}"
NTDLL="$PROTON_DIR/files/lib/wine/x86_64-windows/ntdll.dll"

# --- 1. ntdll.dll: add WNF stubs (LIEF binary patch) ---
echo "=== Patching ntdll.dll (WNF stubs) ==="

if [ ! -f "$NTDLL" ]; then
    echo "ERROR: ntdll.dll not found at $NTDLL"
    echo "Set PROTON_DIR to your GDK-Proton install."
    exit 1
fi

# Back up the original once
if [ ! -f "$NTDLL.bak" ]; then
    cp -v "$NTDLL" "$NTDLL.bak"
fi

python3 "$SCRIPT_DIR/patch-ntdll-wnf.py" "$NTDLL.bak" -o "$NTDLL"
echo ""

# --- 2. combase.dll: ObjectStublessClient stubs ---
echo "=== combase.dll (ObjectStublessClient3..32) ==="
echo "The LIEF binary-patch approach does NOT work for combase because Wine"
echo "overrides the on-disk DLL with its builtin stub table at load time."
echo ""
echo "The working fix is to rebuild combase.dll from Wine source with the"
echo "ObjectStublessClient stubs compiled in.  See:"
echo "  https://github.com/ValveSoftware/wine/blob/proton_10/dlls/combase/combase.spec"
echo ""
echo "Short version:"
echo "  1. Clone the Proton Wine fork and check out the proton_10 branch"
echo "  2. Add ObjectStublessClient3..32 to dlls/combase/combase.spec"
echo "  3. Add stub implementations in dlls/combase/stubless.c"
echo "  4. Build with: ./configure --enable-win64 && make -j\$(nproc) dlls/combase"
echo "  5. Copy the resulting combase.dll into the Proton prefix"
echo ""
echo "A reference LIEF patcher is available at:"
echo "  $SCRIPT_DIR/patch-combase-stubless.py"

echo ""
echo "Done."
