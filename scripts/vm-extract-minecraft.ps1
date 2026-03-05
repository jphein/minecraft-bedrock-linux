# vm-extract-minecraft.ps1
# Run this inside the Windows 11 VM as Administrator
# Decrypts Minecraft.Windows.exe and copies all game files to a destination
#
# Usage (in elevated PowerShell):
#   .\vm-extract-minecraft.ps1                          # Copies to Desktop\minecraft-bedrock
#   .\vm-extract-minecraft.ps1 -Destination "Z:\minecraft-bedrock"  # Copies to shared folder

#Requires -RunAsAdministrator

param(
    [string]$Destination = "$env:USERPROFILE\Desktop\minecraft-bedrock"
)

Write-Host "=== Minecraft Bedrock Extraction ===" -ForegroundColor Cyan

# Find the game package
Write-Host "[1/5] Finding Minecraft installation..."
$pkg = Get-AppxPackage Microsoft.MinecraftUWP
if (-not $pkg) {
    Write-Host "ERROR: Minecraft Bedrock is not installed." -ForegroundColor Red
    Write-Host "Install it from the Xbox App and launch it at least once."
    exit 1
}

$installDir = $pkg.InstallLocation
Write-Host "  Found at: $installDir"

# Check that it's a GDK build
if (-not (Test-Path "$installDir\MicrosoftGame.Config")) {
    Write-Host "ERROR: This doesn't appear to be a GDK build (no MicrosoftGame.Config)." -ForegroundColor Red
    Write-Host "You need Minecraft Bedrock version 1.21.120 or newer."
    exit 1
}

# Create destination
Write-Host "[2/5] Creating destination directory..."
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
Write-Host "  $Destination"

# Copy all game files
Write-Host "[3/5] Copying game files (this may take a few minutes)..."
Copy-Item -Path "$installDir\*" -Destination $Destination -Recurse -Force
Write-Host "  Done."

# Decrypt the exe
Write-Host "[4/5] Decrypting Minecraft.Windows.exe..."
$decryptedExe = "$env:USERPROFILE\Desktop\Minecraft.Windows.decrypted.exe"

Invoke-CommandInDesktopPackage `
    -PackageFamilyName "Microsoft.MinecraftUWP_8wekyb3d8bbwe" `
    -AppId "Game" `
    -Command "cmd.exe" `
    -Args "/C copy `"$installDir\Minecraft.Windows.exe`" `"$decryptedExe`""

# Wait a moment for the copy to complete (runs in a separate process)
Start-Sleep -Seconds 5

if (Test-Path $decryptedExe) {
    # Verify it's actually decrypted (check MZ header)
    $bytes = [System.IO.File]::ReadAllBytes($decryptedExe)
    if ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) {
        Write-Host "  Decrypted successfully (MZ header verified)."
        # Replace the encrypted copy with the decrypted one
        Copy-Item -Path $decryptedExe -Destination "$Destination\Minecraft.Windows.exe" -Force
        Remove-Item $decryptedExe
    } else {
        Write-Host "  WARNING: Decrypted file does not have MZ header. It may still be encrypted." -ForegroundColor Yellow
        Write-Host "  Try launching Minecraft once from the Xbox App, then run this script again."
    }
} else {
    Write-Host "  WARNING: Decrypted exe not found at $decryptedExe" -ForegroundColor Yellow
    Write-Host "  The Invoke-CommandInDesktopPackage may have failed."
    Write-Host "  Try running the command manually in an elevated PowerShell."
}

# Summary
Write-Host "[5/5] Verifying..."
$exePath = "$Destination\Minecraft.Windows.exe"
if (Test-Path $exePath) {
    $size = (Get-Item $exePath).Length / 1MB
    Write-Host "  Minecraft.Windows.exe: $([math]::Round($size, 1)) MB"
} else {
    Write-Host "  WARNING: Minecraft.Windows.exe not found in destination" -ForegroundColor Yellow
}

$fileCount = (Get-ChildItem $Destination -Recurse | Measure-Object).Count
Write-Host "  Total files: $fileCount"

Write-Host ""
Write-Host "=== Extraction Complete ===" -ForegroundColor Green
Write-Host "Game files are at: $Destination"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Transfer files to your Ubuntu host (shared folder or scp)"
Write-Host "  2. Run ./scripts/setup.sh on the Ubuntu host"
