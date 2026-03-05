# Minecraft Bedrock on Ubuntu Linux (via Lutris + GDK-Proton)

Complete end-to-end guide: from creating a Windows 11 KVM VM to running Minecraft Bedrock on Ubuntu.

## Overview

| Component | Details |
|-----------|---------|
| Host OS | Ubuntu 24.04 LTS |
| VM | Windows 11 on KVM/QEMU with virt-manager |
| Runner | [GDK-Proton10-32](https://github.com/Weather-OS/GDK-Proton) |
| Launcher | [Lutris](https://lutris.net/) (Flatpak, v0.5.22+) |
| Game Version | Bedrock 1.26.301.0+ (GDK build, 1.21.120 minimum) |
| GPU Tested | NVIDIA GeForce GTX 1650, Driver 580.126.09 |

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/host-install-kvm.sh` | Install KVM/QEMU/virt-manager on Ubuntu |
| `scripts/host-create-vm.sh` | Create the Windows 11 VM via CLI |
| `scripts/vm-setup-ssh.ps1` | Enable OpenSSH on Windows 11 (run inside VM) |
| `scripts/vm-extract-minecraft.ps1` | Decrypt and copy Minecraft files (run inside VM) |
| `scripts/host-copy-from-vm.sh` | SSH into VM and copy game files to host |
| `scripts/setup.sh` | Set up XCurl, SSL certs, GDK DLLs, and Lutris config |
| `scripts/launch.sh` | Launch Minecraft directly via GDK-Proton |
| `scripts/update-xcurl.sh` | Re-download XCurl.dll after game updates |

---

## Part 1: Set Up the Windows 11 KVM VM

### 1.1 Install KVM and Dependencies

```bash
./scripts/host-install-kvm.sh
```

Or manually:

```bash
# Verify CPU supports hardware virtualization
egrep -c '(vmx|svm)' /proc/cpuinfo  # Must be > 0

sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients \
  bridge-utils virt-manager virtinst ovmf swtpm swtpm-tools

sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER
newgrp libvirt
```

### 1.2 Download Windows 11 ISO and VirtIO Drivers

1. **Windows 11 ISO**: Download from [microsoft.com/software-download/windows11](https://www.microsoft.com/en-us/software-download/windows11) — select "Download Windows 11 Disk Image (ISO) for x64 devices"

2. **VirtIO drivers ISO**:
```bash
wget -P ~/Downloads/ https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
```

### 1.3 Create the VM

Use `virt-manager` (GUI) or the CLI script:

```bash
./scripts/host-create-vm.sh ~/Downloads/Win11.iso ~/Downloads/virtio-win.iso
```

**virt-manager GUI settings** (if doing it manually):

| Setting | Value |
|---------|-------|
| Chipset | Q35 |
| Firmware | UEFI: `/usr/share/OVMF/OVMF_CODE_4M.ms.fd` (Secure Boot) |
| CPU | Copy host configuration (host-passthrough), 4+ cores |
| RAM | 8192 MiB minimum (16384 recommended) |
| Disk | 80 GiB, VirtIO bus |
| NIC | virtio |
| TPM | Emulated, TIS model, version 2.0 |
| Extra CDROM | Add VirtIO drivers ISO |

During Windows install, when no disk is found:
1. Click "Load driver"
2. Browse VirtIO CDROM → `vioscsi\w11\amd64`
3. Select the driver → disk appears

After install, open VirtIO CDROM in Explorer and run `virtio-win-gt-x64.msi` to install all drivers.

### 1.4 Set Up Shared Folder (virtiofs)

**Shut down the VM**, then in virt-manager:

1. Memory → check **"Enable shared memory"**
2. Add Hardware → Filesystem:
   - Driver: **virtiofs**
   - Source path: `/home/<user>/vmshare`
   - Target path: `vmshare`

**Inside Windows 11:**

1. Install [WinFSP](https://github.com/winfsp/winfsp/releases) (the `.msi`, select "Core" component)
2. Reboot
3. Open Services (`services.msc`) → find "VirtIO-FS Service" → set to Automatic → Start
4. The shared folder appears as a new drive letter

---

## Part 2: Set Up SSH on Windows 11 VM

### 2.1 Enable OpenSSH Server

Run inside the Windows 11 VM (elevated PowerShell), or copy the script to the VM:

```powershell
# Install OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start and auto-start
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# Set PowerShell as default SSH shell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
    -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -PropertyType String -Force

# Ensure firewall rule exists
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}
```

See `scripts/vm-setup-ssh.ps1` for the full script.

### 2.2 Find the VM's IP Address

From the Ubuntu host:

```bash
sudo virsh domifaddr win11 --source agent
# Or:
sudo virsh net-dhcp-leases default
```

The IP is typically `192.168.122.x` with the default NAT network.

### 2.3 Test SSH Connection

```bash
ssh YourWindowsUser@192.168.122.xxx
```

---

## Part 3: Extract Minecraft Files from the VM

### 3.1 Prerequisites

- Minecraft Bedrock installed via Xbox App in the Windows 11 VM
- Game launched at least once
- SSH working (Part 2)

### 3.2 Run Extraction Remotely

```bash
./scripts/host-copy-from-vm.sh WindowsUser 192.168.122.xxx
```

Or manually via SSH:

```bash
# Find the game install path
ssh User@VM_IP "(Get-AppxPackage Microsoft.MinecraftUWP).InstallLocation"

# Decrypt the exe
ssh User@VM_IP 'Invoke-CommandInDesktopPackage -PackageFamilyName "Microsoft.MinecraftUWP_8wekyb3d8bbwe" -AppId "Game" -Command "cmd.exe" -Args "/C copy `"$((Get-AppxPackage Microsoft.MinecraftUWP).InstallLocation)\Minecraft.Windows.exe`" `"$ENV:USERPROFILE\Desktop\Minecraft.Windows.exe`""'

# Copy files via the shared folder (if virtiofs is set up)
ssh User@VM_IP '$src = (Get-AppxPackage Microsoft.MinecraftUWP).InstallLocation; Copy-Item -Path "$src\*" -Destination "Z:\minecraft-bedrock\" -Recurse -Force; Copy-Item -Path "$ENV:USERPROFILE\Desktop\Minecraft.Windows.exe" -Destination "Z:\minecraft-bedrock\Minecraft.Windows.exe" -Force'
```

Or copy via SCP if no shared folder:

```bash
scp -r User@VM_IP:"C:/XboxGames/Minecraft\ for\ Windows/Content/*" ~/vmshare/minecraft-bedrock/
scp User@VM_IP:C:/Users/User/Desktop/Minecraft.Windows.exe ~/vmshare/minecraft-bedrock/
```

### 3.3 Verify the EXE is Decrypted

```bash
file ~/vmshare/minecraft-bedrock/Minecraft.Windows.exe
# Should say: PE32+ executable (GUI) x86-64, for MS Windows

# Or check the MZ header:
xxd -l 2 ~/vmshare/minecraft-bedrock/Minecraft.Windows.exe
# Should output: 00000000: 4d5a  MZ
```

If it says `data` instead of `PE32+`, the exe is still encrypted — re-run the decryption step.

---

## Part 4: Set Up and Launch on Ubuntu

### 4.1 Run the Setup Script

```bash
./scripts/setup.sh
```

This will:
1. Replace `XCurl.dll` with the mingw curl build
2. Download SSL certificates
3. Copy `xgameruntime.dll` to the game directory
4. Install `GameInputRedist.msi` into the Wine prefix
5. Symlink GDK-Proton into Lutris
6. Create the Lutris game config and database entry

### 4.2 Launch

**Via Lutris:**
Open Lutris (Flatpak) and click Play on "Minecraft Bedrock"

**Via script (no Lutris needed):**
```bash
./scripts/launch.sh
```

**Key environment variables** (these are critical — without them you get "missing a required component"):
- `STEAM_COMPAT_DATA_PATH` — path to Wine prefix
- `STEAM_COMPAT_CLIENT_INSTALL_PATH` — path to `.steam/root`
- `PROTONPATH` — path to GDK-Proton

---

## Known Limitations

- **No Microsoft account login** — XUser is not implemented in WineGDK
- **No Realms or featured servers** — requires Microsoft auth
- **Multiplayer workaround** — use [ProxyPass](https://minecraft.wiki/w/Tutorial:Playing_Minecraft_on_Linux) to proxy external servers as LAN
- **File picker crashes** — import worlds manually by extracting `.mcworld` files into `com.mojang/minecraftWorlds/`
- **Wine prefix corruption** — crashes can corrupt the prefix; back up saves regularly

## Troubleshooting

### "Missing a required component" error
1. Verify `xgameruntime.dll` and `xgameruntime.dll.threading` are in the game directory
2. Ensure Lutris config has `runner_type: proton` (not plain wine)
3. Check `STEAM_COMPAT_DATA_PATH` and `STEAM_COMPAT_CLIENT_INSTALL_PATH` env vars are set

### Game crashes immediately
Check `~/.var/app/net.lutris.Lutris/cache/lutris/lutris.log`

### Encrypted EXE
Re-run `Invoke-CommandInDesktopPackage` on the Windows VM — see Part 3

## References

- [Minecraft Wiki - Playing on Linux](https://minecraft.wiki/w/Tutorial:Playing_Minecraft_on_Linux)
- [GDK-Proton (GitHub)](https://github.com/Weather-OS/GDK-Proton)
- [WineGDK (GitHub)](https://github.com/Weather-OS/WineGDK)
- [MCGDKLauncher (GitHub)](https://github.com/oliik2013/MCGDKLauncher)
- [Microsoft - Download Windows 11](https://www.microsoft.com/en-us/software-download/windows11)
- [VirtIO Windows Drivers](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso)
