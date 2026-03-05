# vm-extract-minecraft.ps1
# Run this inside the Windows 11 VM as Administrator
# Decrypts Minecraft.Windows.exe and copies all game files to a destination
#
# Xbox/Microsoft Store games are encrypted at rest. The exe cannot be copied
# directly — it must be decrypted via Invoke-CommandInDesktopPackage. Other
# game files (DLLs, data/) can be copied via robocopy from inside the package
# context, since direct Copy-Item may fail with access denied.
#
# Usage (in elevated PowerShell):
#   .\vm-extract-minecraft.ps1                          # Copies to C:\Users\<user>\minecraft
#   .\vm-extract-minecraft.ps1 -Destination "D:\minecraft"

#Requires -RunAsAdministrator

param(
    [string]$Destination = "$env:USERPROFILE\minecraft"
)

Write-Host "=== Minecraft Bedrock Extraction ===" -ForegroundColor Cyan

# Find the game package
Write-Host "[1/4] Finding Minecraft installation..."
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
Write-Host "[2/4] Copying game files via robocopy (this may take a few minutes)..."
New-Item -ItemType Directory -Path $Destination -Force | Out-Null

# Use Invoke-CommandInDesktopPackage to run robocopy inside the package context.
# This bypasses the at-rest encryption so all files are copied in decrypted form.
# robocopy handles subdirectories and is more reliable than Copy-Item for protected dirs.
Invoke-CommandInDesktopPackage `
    -PackageFamilyName "Microsoft.MinecraftUWP_8wekyb3d8bbwe" `
    -AppId "Game" `
    -Command "cmd.exe" `
    -Args "/C robocopy `"$installDir`" `"$Destination`" /E /R:1 /W:1 /NP"

# Wait for robocopy to finish — it runs asynchronously in the package context
Write-Host "  Waiting for robocopy to complete..."
$prevSize = 0
$stableCount = 0
do {
    Start-Sleep -Seconds 5
    $currentSize = (Get-ChildItem $Destination -Recurse -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
    $sizeMB = [math]::Round($currentSize / 1MB, 1)
    Write-Host "  Progress: $sizeMB MB copied..."
    if ($currentSize -eq $prevSize -and $currentSize -gt 0) {
        $stableCount++
    } else {
        $stableCount = 0
    }
    $prevSize = $currentSize
} while ($stableCount -lt 3)

Write-Host "  Robocopy complete."

# The exe may still be encrypted even after robocopy (it's encrypted at the filesystem level).
# Decrypt it specifically via Invoke-CommandInDesktopPackage copy.
Write-Host "[3/4] Decrypting Minecraft.Windows.exe..."
$decryptedExe = "$env:USERPROFILE\Minecraft.Windows.decrypted.exe"

Invoke-CommandInDesktopPackage `
    -PackageFamilyName "Microsoft.MinecraftUWP_8wekyb3d8bbwe" `
    -AppId "Game" `
    -Command "cmd.exe" `
    -Args "/C copy `"$installDir\Minecraft.Windows.exe`" `"$decryptedExe`""

Start-Sleep -Seconds 5

if (Test-Path $decryptedExe) {
    $bytes = [System.IO.File]::ReadAllBytes($decryptedExe)
    if ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) {
        Write-Host "  Decrypted successfully (MZ header verified)."
        Copy-Item -Path $decryptedExe -Destination "$Destination\Minecraft.Windows.exe" -Force
        Remove-Item $decryptedExe
    } else {
        Write-Host "  WARNING: Decrypted file does not have MZ header." -ForegroundColor Yellow
        Write-Host "  Try launching Minecraft once from the Xbox App, then run this script again."
    }
} else {
    Write-Host "  WARNING: Decrypted exe not found." -ForegroundColor Yellow
    Write-Host "  Invoke-CommandInDesktopPackage may have failed silently."
}

# Summary
Write-Host "[4/4] Verifying..."
$exePath = "$Destination\Minecraft.Windows.exe"
if (Test-Path $exePath) {
    $exeBytes = [System.IO.File]::ReadAllBytes($exePath)[0..1]
    if ($exeBytes[0] -eq 0x4D -and $exeBytes[1] -eq 0x5A) {
        $size = (Get-Item $exePath).Length / 1MB
        Write-Host "  Minecraft.Windows.exe: $([math]::Round($size, 1)) MB (decrypted, valid PE)" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Minecraft.Windows.exe appears to still be encrypted" -ForegroundColor Yellow
    }
} else {
    Write-Host "  WARNING: Minecraft.Windows.exe not found in destination" -ForegroundColor Yellow
}

$totalSize = (Get-ChildItem $Destination -Recurse -ErrorAction SilentlyContinue |
              Measure-Object -Property Length -Sum).Sum / 1MB
$fileCount = (Get-ChildItem $Destination -Recurse | Measure-Object).Count
Write-Host "  Total: $fileCount files, $([math]::Round($totalSize, 1)) MB"

Write-Host ""
Write-Host "=== Extraction Complete ===" -ForegroundColor Green
Write-Host "Game files are at: $Destination"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Transfer files to your Ubuntu host via SCP:"
Write-Host "     scp -r $env:USERNAME@<VM_IP>:C:/Users/$env:USERNAME/minecraft/* ~/vmshare/minecraft-bedrock/"
Write-Host "  2. Run ./scripts/setup.sh on the Ubuntu host"
