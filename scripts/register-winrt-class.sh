#!/bin/bash
# Register a WinRT ActivatableClassId in the Wine prefix registry.
# Usage: ./register-winrt-class.sh <ClassName> <DllName>
# Example: ./register-winrt-class.sh Windows.ApplicationModel.Core.CoreApplication windows.applicationmodel.dll
#
# This adds the registry entries that combase!RoGetActivationFactory uses to find
# which DLL implements a WinRT class (via HKLM\Software\Microsoft\WindowsRuntime\ActivatableClassId).

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <WinRTClassName> <DllName>"
    echo "Example: $0 Windows.ApplicationModel.Core.CoreApplication windows.applicationmodel.dll"
    exit 1
fi

CLASS_NAME="$1"
DLL_NAME="$2"
SYSREG="${PREFIX_PFX:-$HOME/Games/MinecraftBedrock/prefix/pfx}/system.reg"

if [ ! -f "$SYSREG" ]; then
    echo "ERROR: system.reg not found at $SYSREG"
    exit 1
fi

# Check if already registered
if grep -q "ActivatableClassId\\\\\\\\${CLASS_NAME}]" "$SYSREG"; then
    echo "Class $CLASS_NAME is already registered."
    exit 0
fi

# Generate the registry entries (both normal and Wow6432Node)
TIMESTAMP=1772678246
TIME_HEX="1dcac49014f7ff2"
DLL_PATH="C:\\\\windows\\\\system32\\\\${DLL_NAME}"

# Append to end of file (Wine will sort on next load)
cat >> "$SYSREG" << EOF

[Software\\\\Microsoft\\\\WindowsRuntime\\\\ActivatableClassId\\\\${CLASS_NAME}] ${TIMESTAMP}
#time=${TIME_HEX}
"DllPath"="${DLL_PATH}"

[Software\\\\Wow6432Node\\\\Microsoft\\\\WindowsRuntime\\\\ActivatableClassId\\\\${CLASS_NAME}] ${TIMESTAMP}
#time=${TIME_HEX}
"DllPath"="${DLL_PATH}"
EOF

echo "Registered WinRT class: $CLASS_NAME -> $DLL_NAME"
