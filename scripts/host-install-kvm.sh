#!/usr/bin/env bash
# Install KVM/QEMU/virt-manager on Ubuntu 24.04
set -euo pipefail

echo "=== Installing KVM/QEMU/virt-manager ==="

# Check CPU virtualization support
VMX_COUNT=$(egrep -c '(vmx|svm)' /proc/cpuinfo || true)
if [ "$VMX_COUNT" -eq 0 ]; then
    echo "ERROR: CPU does not support hardware virtualization (vmx/svm)"
    echo "Enable VT-x/AMD-V in your BIOS settings"
    exit 1
fi
echo "CPU virtualization supported ($VMX_COUNT cores)"

# Install packages
sudo apt update
sudo apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virt-manager \
    virtinst \
    ovmf \
    swtpm \
    swtpm-tools

# Add user to required groups
sudo usermod -aG libvirt "$USER"
sudo usermod -aG kvm "$USER"

# Start and enable libvirtd
sudo systemctl enable --now libvirtd

# Verify
echo ""
echo "=== Verifying installation ==="
virsh list --all 2>/dev/null && echo "libvirt: OK" || echo "libvirt: FAILED (try logging out and back in)"
echo ""
echo "=== Done ==="
echo "Log out and back in for group changes to take effect."
echo ""
echo "Next steps:"
echo "  1. Download Windows 11 ISO from https://www.microsoft.com/en-us/software-download/windows11"
echo "  2. Download VirtIO drivers: wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
echo "  3. Run: ./scripts/host-create-vm.sh <win11.iso> <virtio-win.iso>"
