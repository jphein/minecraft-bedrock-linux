#!/usr/bin/env bash
# Create a Windows 11 VM using virt-install (CLI)
# Usage: ./host-create-vm.sh <windows11.iso> <virtio-win.iso>
set -euo pipefail

WIN_ISO="${1:?Usage: $0 <windows11.iso> <virtio-win.iso>}"
VIRTIO_ISO="${2:?Usage: $0 <windows11.iso> <virtio-win.iso>}"
VM_NAME="${3:-win11}"
RAM_MB="${RAM_MB:-8192}"
CPUS="${CPUS:-4}"
DISK_GB="${DISK_GB:-80}"
SHARE_DIR="${SHARE_DIR:-$HOME/vmshare}"

# Validate inputs
for f in "$WIN_ISO" "$VIRTIO_ISO"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: File not found: $f"
        exit 1
    fi
done

# Create shared directory
mkdir -p "$SHARE_DIR"

echo "=== Creating Windows 11 VM ==="
echo "Name:    $VM_NAME"
echo "RAM:     $RAM_MB MiB"
echo "CPUs:    $CPUS"
echo "Disk:    $DISK_GB GiB"
echo "Share:   $SHARE_DIR"
echo ""

virt-install \
    --name "$VM_NAME" \
    --memory "$RAM_MB" \
    --vcpus "$CPUS" \
    --cpu host-passthrough \
    --os-variant win11 \
    --machine q35 \
    --boot uefi \
    --disk size="$DISK_GB",bus=virtio,cache=none,discard=unmap \
    --cdrom "$WIN_ISO" \
    --disk "$VIRTIO_ISO",device=cdrom \
    --network network=default,model=virtio \
    --graphics spice \
    --video qxl \
    --channel spicevmc \
    --tpm backend.type=emulator,backend.version=2.0,model=tpm-tis \
    --memorybacking source.type=memfd,access.mode=shared \
    --filesystem source.dir="$SHARE_DIR",target.dir=vmshare,driver.type=virtiofs \
    --noautoconsole

echo ""
echo "=== VM '$VM_NAME' created ==="
echo ""
echo "The VM is starting. Open virt-manager to complete Windows installation."
echo ""
echo "During Windows install, when no disk is found:"
echo "  1. Click 'Load driver'"
echo "  2. Browse VirtIO CDROM -> vioscsi\\w11\\amd64"
echo "  3. Select the driver -> disk appears"
echo ""
echo "After install, inside Windows:"
echo "  1. Open VirtIO CDROM in Explorer"
echo "  2. Run virtio-win-gt-x64.msi to install all drivers"
echo "  3. Install WinFSP from https://github.com/winfsp/winfsp/releases"
echo "  4. Reboot, then start VirtIO-FS Service in services.msc"
echo "  5. Run scripts/vm-setup-ssh.ps1 to enable SSH"
