#!/usr/bin/env bash
# Copy Minecraft Bedrock files from a Windows 11 VM via SSH
# Usage: ./host-copy-from-vm.sh <windows-user> <vm-ip>
#
# This script SSHs into the VM, runs the extraction, and copies files back.
# Requires: SSH access to the VM (run vm-setup-ssh.ps1 first)

set -euo pipefail

WIN_USER="${1:?Usage: $0 <windows-user> <vm-ip>}"
VM_IP="${2:?Usage: $0 <windows-user> <vm-ip>}"
DEST_DIR="${DEST_DIR:-$HOME/vmshare/minecraft-bedrock}"
SSH_TARGET="$WIN_USER@$VM_IP"

echo "=== Copying Minecraft from Windows VM ==="
echo "VM:   $SSH_TARGET"
echo "Dest: $DEST_DIR"
echo ""

# Test SSH connection
echo "[1/5] Testing SSH connection..."
if ! ssh -o ConnectTimeout=5 "$SSH_TARGET" "Write-Host 'SSH OK'" 2>/dev/null; then
    echo "ERROR: Cannot SSH into $SSH_TARGET"
    echo "Make sure:"
    echo "  1. The VM is running"
    echo "  2. OpenSSH is enabled (run vm-setup-ssh.ps1 in the VM)"
    echo "  3. The IP address is correct (check: sudo virsh domifaddr win11 --source agent)"
    exit 1
fi
echo "  Connected."

# Check if Minecraft is installed
echo "[2/5] Checking Minecraft installation..."
INSTALL_DIR=$(ssh "$SSH_TARGET" "(Get-AppxPackage Microsoft.MinecraftUWP).InstallLocation" 2>/dev/null)
if [ -z "$INSTALL_DIR" ]; then
    echo "ERROR: Minecraft Bedrock not found on the VM"
    echo "Install it from the Xbox App and launch it at least once."
    exit 1
fi
echo "  Found at: $INSTALL_DIR"

# Create destination
mkdir -p "$DEST_DIR"

# Copy game files via SCP
echo "[3/5] Copying game files (this may take several minutes)..."
# Convert Windows path to something SCP can use
WIN_PATH=$(echo "$INSTALL_DIR" | sed 's/\\/\//g')
scp -r "$SSH_TARGET:\"$WIN_PATH\"/*" "$DEST_DIR/"
echo "  Done."

# Decrypt the exe
echo "[4/5] Decrypting Minecraft.Windows.exe on VM..."
ssh "$SSH_TARGET" "
    \$decrypted = \"\$env:USERPROFILE\\Desktop\\Minecraft.Windows.decrypted.exe\"
    Invoke-CommandInDesktopPackage \`
        -PackageFamilyName 'Microsoft.MinecraftUWP_8wekyb3d8bbwe' \`
        -AppId 'Game' \`
        -Command 'cmd.exe' \`
        -Args \"/C copy \`\"\$((Get-AppxPackage Microsoft.MinecraftUWP).InstallLocation)\\Minecraft.Windows.exe\`\" \`\"\$decrypted\`\"\"
    Start-Sleep -Seconds 5
    if (Test-Path \$decrypted) {
        Write-Host 'Decryption successful'
    } else {
        Write-Host 'ERROR: Decryption may have failed'
    }
"

# Copy the decrypted exe
echo "[5/5] Copying decrypted exe..."
scp "$SSH_TARGET:C:/Users/$WIN_USER/Desktop/Minecraft.Windows.decrypted.exe" "$DEST_DIR/Minecraft.Windows.exe"

# Clean up on VM
ssh "$SSH_TARGET" "Remove-Item \"\$env:USERPROFILE\\Desktop\\Minecraft.Windows.decrypted.exe\" -Force -ErrorAction SilentlyContinue"

# Verify
echo ""
echo "=== Verifying ==="
if file "$DEST_DIR/Minecraft.Windows.exe" | grep -q "PE32+"; then
    echo "Minecraft.Windows.exe: VALID (PE32+ executable, decrypted)"
else
    echo "WARNING: Minecraft.Windows.exe may still be encrypted"
    echo "Check with: file $DEST_DIR/Minecraft.Windows.exe"
fi

FILE_COUNT=$(find "$DEST_DIR" -type f | wc -l)
echo "Total files: $FILE_COUNT"
echo ""
echo "=== Done ==="
echo "Next: run ./scripts/setup.sh"
