# Minecraft Bedrock on Ubuntu Linux (via Lutris + GDK-Proton)

Complete end-to-end guide: from creating a Windows 11 KVM VM to running Minecraft Bedrock on Ubuntu.

> **WARNING: Known Limitations**
>
> This is an **experimental** setup with significant trade-offs:
>
> - **No Microsoft account login** — XUser is not implemented in WineGDK, so you **cannot sign in**
> - **No Realms, no featured servers** — these require Microsoft authentication
> - **No online multiplayer** (without workaround) — use [ProxyPass](https://minecraft.wiki/w/Tutorial:Playing_Minecraft_on_Linux) to proxy external servers as LAN
> - **File picker crashes the game** — import worlds manually by extracting `.mcworld` files into `com.mojang/minecraftWorlds/`
> - **Wine prefix can corrupt on crashes** — back up your saves regularly
> - **Game may crash unexpectedly** — this is not a stable, supported configuration
>
> If you only need Java Edition, it runs **natively** on Linux — just use [Prism Launcher](https://prismlauncher.org/).
> For a more stable Bedrock experience (without ray tracing), consider [mcpelauncher](https://mcpelauncher.readthedocs.io/) (Android-based).

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

| Script | Where | Purpose |
|--------|-------|---------|
| `scripts/host-install-kvm.sh` | Host | Install KVM/QEMU/virt-manager on Ubuntu |
| `scripts/host-create-vm.sh` | Host | Create the Windows 11 VM via CLI |
| `scripts/vm-setup-ssh.ps1` | VM | Enable OpenSSH, fix admin key auth, configure firewall |
| `scripts/vm-extract-minecraft.ps1` | VM | Decrypt and copy Minecraft files (robocopy + package context) |
| `scripts/host-copy-from-vm.sh` | Host | SSH into VM, extract game files, SCP to host |
| `scripts/setup.sh` | Host | Set up XCurl, SSL certs, GDK DLLs, and Lutris config |
| `scripts/launch.sh` | Host | Launch Minecraft directly via GDK-Proton |
| `scripts/update-xcurl.sh` | Host | Re-download XCurl.dll after game updates |
| `lutris-installer.yaml` | Host | Lutris installer — automates all of Part 4 |
| `scripts/uninstall.sh` | Host | Remove all Minecraft Bedrock files and Lutris entries |

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
| RAM | 4096 MiB minimum (8192 recommended) |
| Disk | 40+ GiB, SATA or VirtIO bus |
| NIC | e1000e or virtio |
| TPM | Emulated, TIS model, version 2.0 |

> **Note:** VirtIO disk/NIC are faster but require loading drivers during Windows install
> (browse VirtIO CDROM → `vioscsi\w11\amd64` when no disk is found).
> SATA + e1000e work out of the box with no extra drivers.

After install, install the [virtio-win guest tools](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) inside the VM for best performance (open the ISO in Explorer, run `virtio-win-gt-x64.msi`).

### 1.4 File Transfer Method

We use **SSH + SCP** to copy game files from the VM (see Parts 2 and 3). This is the most reliable method because Xbox App games are encrypted at rest and need special handling.

**Alternative: virtiofs shared folder** (optional, more setup):

1. Install `virtiofsd` on the host: `sudo apt install virtiofsd`
2. Shut down the VM, then in virt-manager:
   - Memory → check **"Enable shared memory"**
   - Add Hardware → Filesystem: Driver=virtiofs, Source=`/home/<user>/vmshare`, Target=`vmshare`
3. Inside Windows: install [WinFSP](https://github.com/winfsp/winfsp/releases), reboot, start "VirtIO-FS Service" in `services.msc`
4. The shared folder appears as a new drive letter

> **Note:** Even with virtiofs, you still need `Invoke-CommandInDesktopPackage` to decrypt the game files — direct copies from the game directory will be encrypted/access-denied.

---

## Part 2: Set Up SSH on Windows 11 VM

SSH is how we extract and copy game files from the VM. Run `scripts/vm-setup-ssh.ps1` in an **elevated PowerShell** inside the VM, or follow these manual steps:

### 2.1 Enable OpenSSH Server

```powershell
# Install OpenSSH Server (takes a few minutes to download)
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start and auto-start
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# Firewall rule
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server' `
    -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

### 2.2 Fix SSH Key Auth for Admin Users

By default, Windows OpenSSH uses a separate `administrators_authorized_keys` file for admin accounts, which breaks normal `~/.ssh/authorized_keys`. **This must be fixed:**

Open `C:\ProgramData\ssh\sshd_config` in Notepad and **comment out** these two lines at the bottom:

```
#Match Group administrators
#       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
```

Then restart sshd:

```powershell
Restart-Service sshd
```

### 2.3 Set Up SSH Keys

On the **Ubuntu host**:

```bash
# Generate a key (if you don't have one)
ssh-keygen -t ed25519

# Find the VM's IP
virsh domifaddr <vm-name>
# Or: virsh net-dhcp-leases default
```

The IP is typically `192.168.122.x` with the default NAT network.

In the **Windows VM** (PowerShell):

```powershell
mkdir C:\Users\<user>\.ssh -Force
# Paste your public key (~/.ssh/id_ed25519.pub contents) into:
notepad C:\Users\<user>\.ssh\authorized_keys
```

### 2.4 Test SSH Connection

```bash
ssh <windows-user>@192.168.122.xxx "echo connected"
```

---

## Part 3: Extract Minecraft Files from the VM

### 3.1 Prerequisites

- Minecraft Bedrock installed via Xbox App in the Windows 11 VM
- Game launched at least once
- SSH working (Part 2)

### 3.2 Why Extraction is Needed

Xbox App games are **encrypted at rest**. You cannot simply copy files from `C:\XboxGames\` or `C:\Program Files\WindowsApps\` — the exe will be unreadable and other files may be access-denied.

The workaround is `Invoke-CommandInDesktopPackage`, which runs a command inside the app's sandbox where files are transparently decrypted:

1. **robocopy** all game files to a user-accessible staging directory
2. **copy** the exe separately (robocopy gets the encrypted version; the exe must be copied inside the package context to get the decrypted version)

### 3.3 Automated Extraction

From the **Ubuntu host** (does everything via SSH):

```bash
./scripts/host-copy-from-vm.sh <windows-user> <vm-ip>
```

Or run `vm-extract-minecraft.ps1` **inside the VM** (elevated PowerShell), then SCP the files:

```powershell
# In the VM:
.\vm-extract-minecraft.ps1
```

```bash
# Then from Ubuntu:
scp -r <user>@<vm-ip>:C:/Users/<user>/minecraft/* ~/vmshare/minecraft-bedrock/
```

### 3.4 Verify the EXE is Decrypted

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

### Option A: Lutris Installer (recommended)

The Lutris installer automates all of Part 4 — it downloads GDK-Proton, replaces XCurl, sets up SSL certs, copies runtime DLLs, creates the Wine prefix, and configures the game in Lutris.

```bash
flatpak install -y flathub net.lutris.Lutris
flatpak run net.lutris.Lutris -i https://raw.githubusercontent.com/jphein/minecraft-bedrock-linux/master/lutris-installer.yaml
```

Or if you cloned this repo:
```bash
flatpak run net.lutris.Lutris -i lutris-installer.yaml
```

Lutris will prompt you to select any file inside your extracted game directory (from Part 3). After installation, launch the game from Lutris.

### Option B: Manual Setup

#### 4.1 Install Lutris (Flatpak)

```bash
flatpak install -y flathub net.lutris.Lutris
```

#### 4.2 Install GDK-Proton

Download the latest release from [GDK-Proton releases](https://github.com/Weather-OS/GDK-Proton/releases) and extract:

```bash
mkdir -p ~/.steam/root/compatibilitytools.d/
tar xf GDK-Proton10-32.tar.gz -C ~/.steam/root/compatibilitytools.d/
```

#### 4.3 Run the Setup Script

```bash
./scripts/setup.sh
```

This will:
1. Replace `XCurl.dll` with the mingw curl build (for network functionality)
2. Download SSL certificates (for HTTPS)
3. Copy `xgameruntime.dll` and `xgameruntime.dll.threading` to the game directory
4. Install `GameInputRedist.msi` into the Wine prefix
5. Symlink GDK-Proton into Lutris's runner directory
6. Create the Lutris game config and database entry

#### 4.4 Launch

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

## Uninstalling

```bash
./scripts/uninstall.sh
```

This removes the game directory, Wine prefix, GDK-Proton, Lutris configs, and database entries. It handles both Lutris installer and manual `setup.sh` installations. Source game files in `~/vmshare/` are kept as a backup — delete them manually if no longer needed.

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

### VM IP address not found
```bash
virsh domifaddr <vm-name>
# Or check DHCP leases:
virsh net-dhcp-leases default
```

## References

- [Minecraft Wiki - Playing on Linux](https://minecraft.wiki/w/Tutorial:Playing_Minecraft_on_Linux)
- [GDK-Proton (GitHub)](https://github.com/Weather-OS/GDK-Proton)
- [WineGDK (GitHub)](https://github.com/Weather-OS/WineGDK)
- [MCGDKLauncher (GitHub)](https://github.com/oliik2013/MCGDKLauncher)
- [Bedrock Native Modding Wiki - GDK](https://bedrock-native-modding.github.io/wiki/platforms/gdk.html)
- [Microsoft - Download Windows 11](https://www.microsoft.com/en-us/software-download/windows11)
- [VirtIO Windows Drivers](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso)

## Legal

This project is licensed under the [GNU General Public License v3.0](LICENSE).

**Minecraft** is a registered trademark of Mojang Studios / Microsoft Corporation. This project is not affiliated with, endorsed by, or associated with Mojang or Microsoft. You must own a legitimate copy of Minecraft Bedrock Edition to use this guide.

**Third-party components** downloaded at runtime by the setup scripts:
- **mingw-w64 curl** ([curl license](https://curl.se/docs/copyright.html)) — replaces XCurl.dll for network functionality
- **CA certificate bundle** ([Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/)) — from [curl.se/ca](https://curl.se/ca/cacert.pem)
- **GDK-Proton** ([BSD-3-Clause / Valve Proton license](https://github.com/Weather-OS/GDK-Proton)) — Wine/Proton fork with GDK support
