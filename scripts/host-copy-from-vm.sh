#!/usr/bin/env bash
# Copy Minecraft Bedrock files from a Windows 11 VM via SSH
# Usage: ./host-copy-from-vm.sh <windows-user> <vm-ip>
#
# This script SSHs into the VM, runs extraction inside the Xbox package context
# (to bypass at-rest encryption), then copies the files to the host via SCP.
#
# Prerequisites:
#   - SSH access to the VM with key auth (run vm-setup-ssh.ps1 first)
#   - Minecraft Bedrock installed via Xbox App and launched at least once

set -euo pipefail

WIN_USER="${1:?Usage: $0 <windows-user> <vm-ip>}"
VM_IP="${2:?Usage: $0 <windows-user> <vm-ip>}"
DEST_DIR="${DEST_DIR:-$HOME/vmshare/minecraft-bedrock}"
SSH_TARGET="$WIN_USER@$VM_IP"
VM_STAGING="C:/Users/$WIN_USER/minecraft"

echo "=== Copying Minecraft from Windows VM ==="
echo "VM:   $SSH_TARGET"
echo "Dest: $DEST_DIR"
echo ""

# Test SSH connection
echo "[1/6] Testing SSH connection..."
if ! ssh -o ConnectTimeout=5 "$SSH_TARGET" "echo 'SSH OK'" 2>/dev/null; then
    echo "ERROR: Cannot SSH into $SSH_TARGET"
    echo "Make sure:"
    echo "  1. The VM is running"
    echo "  2. OpenSSH is enabled (run vm-setup-ssh.ps1 in the VM)"
    echo "  3. SSH key auth is set up (~/.ssh/authorized_keys on VM)"
    echo "  4. The IP is correct (check: virsh domifaddr <vm-name>)"
    exit 1
fi
echo "  Connected."

# Check if Minecraft is installed
echo "[2/6] Checking Minecraft installation..."
INSTALL_DIR=$(ssh "$SSH_TARGET" "powershell -command \"(Get-AppxPackage Microsoft.MinecraftUWP).InstallLocation\"" 2>/dev/null)
if [ -z "$INSTALL_DIR" ]; then
    echo "ERROR: Minecraft Bedrock not found on the VM"
    echo "Install it from the Xbox App and launch it at least once."
    exit 1
fi
echo "  Found at: $INSTALL_DIR"

# Copy game files using robocopy inside the package context
# Xbox/MS Store games are encrypted at rest — direct copy fails with access denied.
# Invoke-CommandInDesktopPackage runs a command inside the package sandbox where
# files are transparently decrypted.
echo "[3/6] Copying game files on VM via robocopy (inside package context)..."
ssh "$SSH_TARGET" "powershell -command \"
    Invoke-CommandInDesktopPackage \`
        -PackageFamilyName 'Microsoft.MinecraftUWP_8wekyb3d8bbwe' \`
        -AppId 'Game' \`
        -Command 'cmd.exe' \`
        -Args '/C robocopy \\\"$INSTALL_DIR\\\" \\\"$VM_STAGING\\\" /E /R:1 /W:1 /NP'
\""

# Wait for robocopy to finish (runs asynchronously)
echo "  Waiting for robocopy..."
PREV_SIZE=0
STABLE=0
while [ "$STABLE" -lt 3 ]; do
    sleep 5
    CURR_SIZE=$(ssh "$SSH_TARGET" "powershell -command \"(Get-ChildItem '$VM_STAGING' -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum\"" 2>/dev/null || echo "0")
    CURR_MB=$(echo "scale=1; ${CURR_SIZE:-0} / 1048576" | bc 2>/dev/null || echo "0")
    echo "  Progress: ${CURR_MB} MB..."
    if [ "$CURR_SIZE" = "$PREV_SIZE" ] && [ "$CURR_SIZE" != "0" ]; then
        STABLE=$((STABLE + 1))
    else
        STABLE=0
    fi
    PREV_SIZE="$CURR_SIZE"
done
echo "  Robocopy complete."

# Decrypt the exe specifically
# The exe is encrypted at the filesystem level and won't be usable even after robocopy.
echo "[4/6] Decrypting Minecraft.Windows.exe on VM..."
ssh "$SSH_TARGET" "powershell -command \"
    Invoke-CommandInDesktopPackage \`
        -PackageFamilyName 'Microsoft.MinecraftUWP_8wekyb3d8bbwe' \`
        -AppId 'Game' \`
        -Command 'cmd.exe' \`
        -Args '/C copy \\\"$INSTALL_DIR\\Minecraft.Windows.exe\\\" \\\"C:\\Users\\$WIN_USER\\Minecraft.Windows.decrypted.exe\\\"'
\""
sleep 5

# Replace the encrypted exe with the decrypted one
ssh "$SSH_TARGET" "powershell -command \"
    if (Test-Path 'C:\\Users\\$WIN_USER\\Minecraft.Windows.decrypted.exe') {
        Copy-Item 'C:\\Users\\$WIN_USER\\Minecraft.Windows.decrypted.exe' '$VM_STAGING\\Minecraft.Windows.exe' -Force
        Remove-Item 'C:\\Users\\$WIN_USER\\Minecraft.Windows.decrypted.exe'
        Write-Host 'Decrypted exe copied.'
    } else {
        Write-Host 'WARNING: Decrypted exe not found'
    }
\""

# Copy files from VM to host via SCP
echo "[5/6] Downloading game files to host via SCP..."
mkdir -p "$DEST_DIR"
scp -r "$SSH_TARGET:\"$VM_STAGING\"/*" "$DEST_DIR/"
echo "  Done."

# Verify
echo "[6/6] Verifying..."
if file "$DEST_DIR/Minecraft.Windows.exe" | grep -q "PE32+"; then
    echo "  Minecraft.Windows.exe: VALID (PE32+ executable, decrypted)"
else
    echo "  WARNING: Minecraft.Windows.exe may still be encrypted"
    echo "  Check with: file $DEST_DIR/Minecraft.Windows.exe"
fi

TOTAL_SIZE=$(du -sh "$DEST_DIR" | cut -f1)
FILE_COUNT=$(find "$DEST_DIR" -type f | wc -l)
echo "  Total: $FILE_COUNT files, $TOTAL_SIZE"

# Clean up staging on VM
echo "  Cleaning up VM staging directory..."
ssh "$SSH_TARGET" "powershell -command \"Remove-Item '$VM_STAGING' -Recurse -Force -ErrorAction SilentlyContinue\"" 2>/dev/null || true

echo ""
echo "=== Done ==="
echo "Next: run ./scripts/setup.sh"
