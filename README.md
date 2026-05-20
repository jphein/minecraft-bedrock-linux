# Minecraft Bedrock on Ubuntu Linux (via WineGDK)

Complete end-to-end guide: from creating a Windows 11 KVM VM to running Minecraft Bedrock on Ubuntu using [WineGDK](https://github.com/Weather-OS/WineGDK), a Wine fork with native GDK (Game Development Kit) support.

> **Status: WORKING** -- the game launches, renders, and plays on Linux.

> **Known Limitations**
>
> - **No Microsoft account login** — XUser is not implemented in WineGDK, so you **cannot sign in**
> - **No Realms, no featured servers** — these require Microsoft authentication
> - **No online multiplayer** (without workaround) — LAN play works natively (same version as Windows); for external servers, use [ProxyPass](https://minecraft.wiki/w/Tutorial:Playing_Minecraft_on_Linux) to proxy them as LAN
> - **File picker crashes the game** — import worlds manually by extracting `.mcworld` files into `com.mojang/minecraftWorlds/`
> - **Wine prefix can corrupt on crashes** — back up your saves regularly
>
> If you only need Java Edition, it runs **natively** on Linux — just use [Prism Launcher](https://prismlauncher.org/).
> [mcpelauncher](https://mcpelauncher.readthedocs.io/) (Android-based) is **not a viable alternative** — it cannot run the latest Bedrock versions, so cross-play with Android/console/Windows players fails due to version mismatch.

## Overview

| Component | Details |
|-----------|---------|
| Host OS | Ubuntu 24.04 LTS |
| VM | Windows 11 on KVM/QEMU with virt-manager |
| Runner | [WineGDK](https://github.com/Weather-OS/WineGDK) (built from source), Wine 11.8 |
| Game Version | Bedrock 1.26.21 |
| GPU Tested | NVIDIA GeForce GTX 1650 (TU117), Driver 595.58.03 |
| Forks | [jphein/WineGDK](https://github.com/jphein/WineGDK), [jphein/GDK-Proton](https://github.com/jphein/GDK-Proton) |

## Current Status (2026-05-19)

**WORKING** -- Minecraft Bedrock 1.26.21 launches and renders on Ubuntu Linux via WineGDK. Both WineGDK build configurations produce a working game:

| Build | Install Path | Notes |
|-------|-------------|-------|
| clang-20 | `~/Projects/WineGDK/install/` | Default build |
| clang-23 | `~/Projects/WineGDK/install-clang23/` | Matches ChristopherHX's build configuration |

### What works
- Game launches, renders, and plays (world generation, movement, audio, input)
- D3D11 rendering pipeline fully functional
- LAN multiplayer

### Previous black screen issue (resolved)

The game previously showed a black screen across 13 different configurations (DXVK, lavapipe, wined3d OpenGL/Vulkan, etc.). The root cause was **the wrong game binary**: file extraction from the Windows VM had silently failed, leaving version 1.26.3 in place when 1.26.21 was expected. With the correct 1.26.21 binary, the game renders correctly. The rendering issue was never in bgfx, Wine, or the GPU driver -- it was a version mismatch.

### Critical file: xgameruntime.dll.threading

The file `xgameruntime.dll.threading` is a native Microsoft DLL that must be present in the game directory. It is not built by WineGDK -- it comes from the Windows VM game extraction. If this file is missing, the game will fail to launch. Verify it exists after running `host-copy-from-vm.sh`.

### Tracking
- [Issue #4](https://github.com/jphein/minecraft-bedrock-linux/issues/4) — Black screen (resolved: wrong binary version)
- [Issue #5](https://github.com/jphein/minecraft-bedrock-linux/issues/5) — bgfx analysis (resolved: not a bgfx issue)
- [Weather-OS/WineGDK#54](https://github.com/Weather-OS/WineGDK/issues/54) — Upstream discussion

## Scripts

| Script | Where | Purpose |
|--------|-------|---------|
| `scripts/host-install-kvm.sh` | Host | Install KVM/QEMU/virt-manager on Ubuntu |
| `scripts/host-create-vm.sh` | Host | Create the Windows 11 VM via CLI |
| `scripts/vm-setup-ssh.ps1` | VM | Enable OpenSSH, fix admin key auth, configure firewall |
| `scripts/vm-extract-minecraft.ps1` | VM | Decrypt and copy Minecraft files (robocopy + package context) |
| `scripts/host-copy-from-vm.sh` | Host | SSH into VM, extract game files, SCP to host |
| `scripts/setup.sh` | Host | Set up XCurl, SSL certs, stub DLLs, and Wine prefix |
| `scripts/launch.sh` | Host | Launch Minecraft via WineGDK (wine) |
| `scripts/debug-launch.sh` | Host | Launch with Wine debug output captured to log file |
| `scripts/update-xcurl.sh` | Host | Re-download XCurl.dll after game updates |
| `scripts/update.sh` | Host | Full update: re-extract from VM and re-setup |
| `scripts/collect-logs.sh` | Host | Collect full diagnostic info (system, DLLs, prefix health) |
| `scripts/lan-proxy.py` | Host | UDP broadcast proxy for LAN multiplayer across subnets |
| `scripts/install-addon.sh` | Host | Install .mcaddon/.mcpack into the game's com.mojang directory |
| `scripts/deploy-gameinput.sh` | Host | Copy builtin GameInput DLLs from WineGDK build to prefix |
| `scripts/uninstall.sh` | Host | Remove all Minecraft Bedrock files |
| `stubs/gameconfighelper/` | Host | MinGW stub DLL: GameConfigHelper.dll (OpenGameConfigForPackage) |
| `stubs/midlproxystub/` | Host | MinGW stub DLL: ObjectStublessClient3-32 forwarding to rpcrt4 |

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
> (browse VirtIO CDROM -> `vioscsi\w11\amd64` when no disk is found).
> SATA + e1000e work out of the box with no extra drivers.

After install, install the [virtio-win guest tools](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) inside the VM for best performance (open the ISO in Explorer, run `virtio-win-gt-x64.msi`).

### 1.4 File Transfer Method

We use **SSH + SCP** to copy game files from the VM (see Parts 2 and 3). This is the most reliable method because Xbox App games are encrypted at rest and need special handling.

**Alternative: virtiofs shared folder** (optional, more setup):

1. Install `virtiofsd` on the host: `sudo apt install virtiofsd`
2. Shut down the VM, then in virt-manager:
   - Memory -> check **"Enable shared memory"**
   - Add Hardware -> Filesystem: Driver=virtiofs, Source=`/home/<user>/vmshare`, Target=`vmshare`
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

## Part 4: Build WineGDK and Launch on Ubuntu

### 4.1 Build Dependencies

```bash
sudo apt install -y build-essential gcc-mingw-w64-x86-64 flex bison \
  libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
  libxcomposite-dev libglu1-mesa-dev libfreetype-dev libosmesa6-dev \
  libgnutls28-dev libpulse-dev libudev-dev libdbus-1-dev libfontconfig-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libvulkan-dev \
  libusb-1.0-0-dev libsdl2-dev libcups2-dev libkrb5-dev libsane-dev \
  libpcap-dev libunwind-dev gettext
```

### 4.2 Clone and Build WineGDK

```bash
git clone https://github.com/Weather-OS/WineGDK.git ~/Projects/WineGDK
cd ~/Projects/WineGDK

# Configure with an install prefix (64-bit only is sufficient for Bedrock)
./configure --prefix=$HOME/Projects/WineGDK/install --enable-win64

# Build (uses all cores)
make -j$(nproc)

# Install to the prefix directory
make install
```

The build takes 10-30 minutes depending on hardware. The resulting `wine` binary will be at `~/Projects/WineGDK/install/bin/wine`.

**Alternative: clang-23 build** (matches ChristopherHX's configuration):

```bash
cd ~/Projects/WineGDK
CC=clang-23 ./configure --prefix=$HOME/Projects/WineGDK/install-clang23 --enable-win64
make -j$(nproc)
make install
```

Both clang-20 and clang-23 builds produce a working game. To use the clang-23 build, set `WINEGDK_DIR=~/Projects/WineGDK/install-clang23` when running the launch scripts.

### 4.3 Run the Setup Script

```bash
./scripts/setup.sh
```

This will:
1. Replace `XCurl.dll` with the mingw curl build (for network functionality)
2. Copy XCurl dependency DLLs to the game directory
3. Download SSL certificates (for HTTPS)
4. Copy xgameruntime DLLs to the game directory
5. Create the Wine prefix and install GameInputRedist
6. Build and install the midlproxystub DLL (ObjectStublessClient fix)
7. Patch graphics options to avoid deferred renderer crash

> **Known issue: msiexec hangs on GameInputRedist.msi**
>
> Step 5 uses `wine msiexec` to install GameInputRedist, but msiexec hangs indefinitely under WineGDK. The workaround is to use `msiextract` (from the `msitools` package) instead:
> ```bash
> sudo apt install msitools
> msiextract -C "$PREFIX_DIR/drive_c" "$GAME_DIR/Installers/GameInputRedist.msi"
> ```
> The `setup.sh` script does not yet handle this automatically -- if it hangs at the GameInputRedist step, kill it (Ctrl+C), run the `msiextract` command above, and re-run `setup.sh` (it will skip already-completed steps or re-do them harmlessly).

### 4.4 Launch

```bash
./scripts/launch.sh
```

This runs `wine` from your WineGDK build directly — no Proton, no Steam Runtime, no Lutris.

**Environment variables** (all have sensible defaults in the script):

| Variable | Default | Purpose |
|----------|---------|---------|
| `WINEGDK_DIR` | `~/Projects/WineGDK/install` | Path to WineGDK install prefix |
| `GAME_DIR` | `~/Games/minecraft-bedrock/game` | Path to extracted game files |
| `WINEPREFIX` | `~/Games/minecraft-bedrock/prefix` | Wine prefix for the game |

Example with custom paths:
```bash
WINEGDK_DIR=~/Projects/WineGDK/install GAME_DIR=~/vmshare/minecraft-bedrock ./scripts/launch.sh
```

### 4.5 Debug Launch

To capture Wine debug output for troubleshooting:
```bash
./scripts/debug-launch.sh           # Standard debug channels
./scripts/debug-launch.sh --verbose # All warnings + SEH + module loading
```

Logs are saved to `~/minecraft-debug-<timestamp>.log`.

---

## Uninstalling

```bash
./scripts/uninstall.sh
```

This removes the game directory, Wine prefix, and related configs. Source game files in `~/vmshare/` are kept as a backup — delete them manually if no longer needed. Your WineGDK build at `~/Projects/WineGDK/` is not touched.

---

## Updating

When a new Minecraft Bedrock version comes out, update it in the Xbox App on the Windows VM, then run:

```bash
./scripts/update.sh <windows-user> <vm-ip>
```

This will:
1. **Re-extract game files** — decrypts and copies the updated build from the VM
2. **Update XCurl.dll** — auto-detects and downloads the latest mingw curl from MSYS2
3. **Refresh SSL certificates** — downloads the latest Mozilla CA bundle
4. **Re-install GameInputRedist** — into the Wine prefix

World saves are automatically backed up before extraction and restored afterward.

**Partial updates** (skip steps you don't need):

```bash
# Skip VM extraction (just re-setup with existing game files)
SKIP_VM=1 ./scripts/update.sh <windows-user> <vm-ip>
```

To update WineGDK itself, rebuild from source:
```bash
cd ~/Projects/WineGDK && git pull && make -j$(nproc) && make install
```

---

## WineGDK Fixes and Stubs

WineGDK is a Wine fork that includes native support for several Windows APIs that Minecraft Bedrock depends on. The following are handled **natively by WineGDK** (no patches needed):

- **GameInput** — builtin `gameinput.dll` and `gameinputredist.dll` stub the GameInput API safely (Microsoft's native redistributable crashes under Wine due to missing HID/winebus.sys support)
- **xgameruntime** — `xgameruntime.dll` and related GDK runtime DLLs are built into WineGDK
- **DataTransferManager** — `DataTransferManager.GetForWindow()` returns a stub instead of `E_NOTIMPL`
- **CoreApplication WinRT activation** — `RoGetActivationFactory("Windows.ApplicationModel.Core.CoreApplication")` is supported
- **WNF stubs in ntdll.dll** — `NtQueryWnfStateData`, `RtlSubscribeWnfStateChangeNotification`, and related Windows Notification Facility functions are stubbed
- **NtQueryLicenseValue** — returns `STATUS_OBJECT_NAME_NOT_FOUND` correctly
- **RtlGetDeviceFamilyInfoEnum** — form factor value is correct
- **kernelbase.dll package APIs** — `GetCurrentPackagePath2`, `PackageFamilyNameFromFullName`, `PackageNameAndPublisherIdFromFamilyName` are stubbed

### Still Required (applied by setup scripts)

1. **XCurl.dll** — Minecraft ships a proprietary XCurl that depends on Xbox Live services. We replace it with a mingw-built `libcurl` so networking (skin downloads, marketplace, etc.) works. The replacement depends on ~13 DLLs (libbrotlidec, libssl, libcrypto, etc.) that must be in the game directory — `setup.sh` handles this.

2. **SSL certificates** — The mingw curl needs a CA bundle. Downloaded from [curl.se/ca](https://curl.se/ca/cacert.pem) by `setup.sh`.

3. **GameConfigHelper.dll** — Minecraft's `GameLaunchHelper.exe` imports `OpenGameConfigForPackage` from this DLL, which does not exist in Wine. The MinGW stub in `stubs/gameconfighelper/` returns `S_OK`. Deployed by `setup.sh`.

4. **midlproxystub DLL** — Wine's PE-only mode has a bug resolving `combase.dll` forwarders to `rpcrt4.dll` for `ObjectStublessClient3` through `ObjectStublessClient32`. The stub DLL in `stubs/midlproxystub/` provides direct implementations. Built and deployed by `setup.sh`.

### Environment Variables (set automatically by launch scripts)

| Variable | Value | Purpose |
|----------|-------|---------|
| `WINEPREFIX` | `~/Games/minecraft-bedrock/prefix` | Wine prefix for the game |
| `WINEDLLOVERRIDES` | `GameInputRedist=b` | Force Wine's builtin GameInput instead of the native MSI redistributable, which crashes |

## Known Limitations

- **No Microsoft account login** — XUser is not implemented in WineGDK
- **No Realms or featured servers** — requires Microsoft auth
- **Multiplayer** — LAN play works natively; for external servers, use [ProxyPass](https://minecraft.wiki/w/Tutorial:Playing_Minecraft_on_Linux) to proxy them as LAN
- **File picker crashes** — import worlds manually by extracting `.mcworld` files into `com.mojang/minecraftWorlds/`
- **Wine prefix corruption** — crashes can corrupt the prefix; back up saves regularly
- **Deferred rendering crash** — the game's PBR/RTX renderer (graphics_mode:2) has a race condition under Wine; launch scripts force Classic mode (graphics_mode:0) automatically
- **msiexec hangs** — `wine msiexec` hangs when installing GameInputRedist.msi; use `msiextract` instead (see setup instructions above)
- **xgameruntime.dll.threading** — this native Microsoft DLL must come from the Windows VM extraction; it is not built by WineGDK
- **Work in progress** — WineGDK is under active development; some APIs may still be incomplete

## Troubleshooting

### wine not found

Ensure WineGDK is built and installed:
```bash
ls ~/Projects/WineGDK/install/bin/wine
```
If missing, rebuild: `cd ~/Projects/WineGDK && make -j$(nproc) && make install`

### WineGDK build fails

Common issues:
- **Missing headers**: install the build dependencies from [4.1](#41-build-dependencies)
- **Vulkan not found**: `sudo apt install libvulkan-dev`
- **MinGW not found**: `sudo apt install gcc-mingw-w64-x86-64` (needed for PE DLL builds and stub DLLs)

### Game crashes immediately

1. Run `scripts/debug-launch.sh` and check the log for `err:module:import_dll` lines — these indicate missing DLLs
2. Ensure `XCurl.dll` and its dependencies are in the game directory
3. Check that `GameConfigHelper.dll` and the midlproxystub DLL are installed

### "Missing a required component" error

1. Verify `xgameruntime.dll` is in the game directory (copied from the WineGDK build by `setup.sh`)
2. Verify `xgameruntime.dll.threading` is in the game directory -- this is a native Microsoft DLL that must come from the Windows VM game extraction, not from WineGDK. If missing, re-run `host-copy-from-vm.sh`
3. Check that `WINEPREFIX` points to a valid prefix

### Black screen (no rendering)

If the game launches but shows only a black screen, the most likely cause is the **wrong game binary version**. Verify you have the correct version:
```bash
strings ~/Games/minecraft-bedrock/game/Minecraft.Windows.exe | grep -i "1\.26\."
```
Re-extract from the VM with `host-copy-from-vm.sh` if the version does not match what is installed in the Xbox App. The VM file copy can fail silently, leaving an older binary in place.

### setup.sh hangs at GameInputRedist

`wine msiexec` hangs under WineGDK. Kill the script (Ctrl+C) and install manually:
```bash
sudo apt install msitools
msiextract -C ~/Games/minecraft-bedrock/prefix/drive_c ~/Games/minecraft-bedrock/game/Installers/GameInputRedist.msi
```
Then re-run `setup.sh` to complete the remaining steps.

### Encrypted EXE

Re-run `Invoke-CommandInDesktopPackage` on the Windows VM — see Part 3

### VM IP address not found
```bash
virsh domifaddr <vm-name>
# Or check DHCP leases:
virsh net-dhcp-leases default
```

### Debug tools
- Run `scripts/debug-launch.sh` to capture Wine debug output
- Run `scripts/collect-logs.sh` for a full diagnostic report

## References

- [WineGDK (GitHub)](https://github.com/Weather-OS/WineGDK) — Wine fork with GDK support
- [Minecraft Wiki - Playing on Linux](https://minecraft.wiki/w/Tutorial:Playing_Minecraft_on_Linux)
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
- **WineGDK** ([LGPL, same as Wine](https://github.com/Weather-OS/WineGDK)) — Wine fork with GDK support, built from source
