# vm-setup-ssh.ps1
# Run this inside the Windows 11 VM as Administrator
# Enables OpenSSH Server, configures firewall, sets up SSH key auth

#Requires -RunAsAdministrator

Write-Host "=== Setting up OpenSSH Server ===" -ForegroundColor Cyan

# Install OpenSSH Server
Write-Host "[1/5] Installing OpenSSH Server..."
$capability = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
if ($capability.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Write-Host "  Installed."
} else {
    Write-Host "  Already installed."
}

# Start and auto-start sshd
Write-Host "[2/5] Starting sshd service..."
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'
Write-Host "  sshd running and set to auto-start."

# Set PowerShell as default SSH shell
Write-Host "[3/5] Setting PowerShell as default SSH shell..."
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
    -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -PropertyType String -Force | Out-Null
Write-Host "  Done."

# Firewall rule
Write-Host "[4/5] Configuring firewall..."
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' `
        -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    Write-Host "  Firewall rule created."
} else {
    Write-Host "  Firewall rule already exists."
}

# Fix sshd_config for admin SSH key auth
# By default, Windows OpenSSH uses a separate authorized_keys file for admin users
# (administrators_authorized_keys in ProgramData). This breaks normal ~/.ssh/authorized_keys.
# Comment out the Match Group block so admin users can use their own authorized_keys.
Write-Host "[5/5] Fixing sshd_config for SSH key authentication..."
$sshdConfig = "C:\ProgramData\ssh\sshd_config"
if (Test-Path $sshdConfig) {
    $content = Get-Content $sshdConfig
    $modified = $false
    $newContent = @()
    foreach ($line in $content) {
        if ($line -match '^\s*Match Group administrators\s*$') {
            $newContent += "#$line"
            $modified = $true
        } elseif ($line -match '^\s+AuthorizedKeysFile\s+__PROGRAMDATA__' -and $modified) {
            $newContent += "#$line"
        } else {
            $newContent += $line
        }
    }
    if ($modified) {
        $newContent | Set-Content $sshdConfig
        Restart-Service sshd
        Write-Host "  Commented out 'Match Group administrators' block and restarted sshd."
    } else {
        Write-Host "  sshd_config already patched (or no Match Group administrators block found)."
    }
} else {
    Write-Host "  WARNING: sshd_config not found at $sshdConfig" -ForegroundColor Yellow
}

# Show IP address
Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "VM IP address(es):" -ForegroundColor Yellow
Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.InterfaceAlias -notlike "Loopback*" -and $_.IPAddress -ne "127.0.0.1"
} | ForEach-Object {
    Write-Host "  $($_.IPAddress) ($($_.InterfaceAlias))"
}
Write-Host ""
Write-Host "From your Ubuntu host, set up SSH key auth:"
Write-Host "  1. Generate a key (if needed):  ssh-keygen -t ed25519"
Write-Host "  2. Copy the public key to the VM:"
Write-Host "     scp ~/.ssh/id_ed25519.pub $env:USERNAME@<IP>:C:/Users/$env:USERNAME/.ssh/authorized_keys"
Write-Host "  3. Or paste it manually:"
Write-Host "     mkdir C:\Users\$env:USERNAME\.ssh"
Write-Host "     notepad C:\Users\$env:USERNAME\.ssh\authorized_keys"
Write-Host ""
Write-Host "Then test from Ubuntu:  ssh $env:USERNAME@<IP_ADDRESS>"
