# vm-setup-ssh.ps1
# Run this inside the Windows 11 VM as Administrator
# Enables OpenSSH Server, sets PowerShell as default shell, configures firewall

#Requires -RunAsAdministrator

Write-Host "=== Setting up OpenSSH Server ===" -ForegroundColor Cyan

# Install OpenSSH Server
Write-Host "[1/4] Installing OpenSSH Server..."
$capability = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
if ($capability.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Write-Host "  Installed."
} else {
    Write-Host "  Already installed."
}

# Start and auto-start sshd
Write-Host "[2/4] Starting sshd service..."
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'
Write-Host "  sshd running and set to auto-start."

# Set PowerShell as default SSH shell
Write-Host "[3/4] Setting PowerShell as default SSH shell..."
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
    -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -PropertyType String -Force | Out-Null
Write-Host "  Done."

# Firewall rule
Write-Host "[4/4] Configuring firewall..."
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' `
        -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    Write-Host "  Firewall rule created."
} else {
    Write-Host "  Firewall rule already exists."
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
Write-Host "From your Ubuntu host, connect with:"
Write-Host "  ssh $env:USERNAME@<IP_ADDRESS>"
