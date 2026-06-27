#!/usr/bin/env bash
# ============================================================================
# update.sh — DEPRECATED (old GDK-Proton updater)
# ============================================================================
# This GDK-Proton updater is RETIRED. It targeted dead paths
# (~/.steam/.../compatibilitytools.d, ~/Games/MinecraftBedrock) and must not be
# confused with the current WineGDK flow.
# ============================================================================

set -euo pipefail

echo "update.sh is DEPRECATED (old GDK-Proton flow, dead paths)." >&2
echo "" >&2
echo "Use the one-command WineGDK update instead:" >&2
echo "    scripts/update-bedrock.sh" >&2
echo "" >&2
echo "Building blocks (run from the orchestrator): host-copy-from-vm.sh, then setup.sh." >&2
exit 1
