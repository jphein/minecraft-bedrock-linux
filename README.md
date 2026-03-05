# Minecraft Bedrock on Ubuntu Linux (via Lutris + GDK-Proton)

Run Minecraft Bedrock Edition on Ubuntu using Lutris (Flatpak), GDK-Proton, and game files copied from a Windows installation.

## Prerequisites

- Ubuntu 24.04 (or similar)
- NVIDIA or AMD GPU with up-to-date drivers and Vulkan support
- A Windows machine/VM with Minecraft Bedrock installed (GDK version 1.21.120+)
- Flatpak installed

## Overview

| Component | Details |
|-----------|---------|
| Runner | [GDK-Proton10-32](https://github.com/Weather-OS/GDK-Proton) |
| Launcher | [Lutris](https://lutris.net/) (Flatpak, v0.5.22+) |
| Game Version | Bedrock 1.26.301.0+ (GDK build) |
| GPU Tested | NVIDIA GeForce GTX 1650, Driver 580.126.09 |

## Setup Steps

### 1. Install Lutris (Flatpak)

```bash
flatpak install -y flathub net.lutris.Lutris
```

### 2. Install GDK-Proton

Download the latest release from [GDK-Proton releases](https://github.com/Weather-OS/GDK-Proton/releases) and extract:

```bash
mkdir -p ~/.steam/root/compatibilitytools.d/
tar xf GDK-Proton10-32.tar.gz -C ~/.steam/root/compatibilitytools.d/
```

Symlink into Lutris Flatpak runner directory:

```bash
mkdir -p ~/.var/app/net.lutris.Lutris/data/lutris/runners/wine/
ln -sf ~/.steam/root/compatibilitytools.d/GDK-Proton10-32 \
  ~/.var/app/net.lutris.Lutris/data/lutris/runners/wine/GDK-Proton10-32
```

### 3. Copy Game Files from Windows

On the Windows machine/VM, locate the game at:
```
C:\XboxGames\Minecraft for Windows\Content\
```

**Important:** The `Minecraft.Windows.exe` must be **unencrypted**. If installed via Xbox App, you may need to extract the unencrypted version using PowerShell on Windows.

Copy the entire contents to your Linux box:
```bash
# Example: copy into a shared folder or use scp
cp -r /path/to/windows/Content/* ~/vmshare/minecraft-bedrock/
```

### 4. Replace XCurl.dll

Download the mingw curl package and replace XCurl.dll for network functionality:

```bash
./scripts/setup.sh
# Or manually:
cd /tmp
curl -sLO https://repo.msys2.org/mingw/mingw64/mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar.zst
zstd -d mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar.zst
tar xf mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar
cp ~/vmshare/minecraft-bedrock/XCurl.dll ~/vmshare/minecraft-bedrock/XCurl.dll.bak
cp /tmp/mingw64/bin/libcurl-4.dll ~/vmshare/minecraft-bedrock/XCurl.dll
```

### 5. Set Up SSL Certificates

```bash
mkdir -p ~/vmshare/etc/ssl/certs/
curl -sL -o ~/vmshare/etc/ssl/certs/ca-bundle.crt https://curl.se/ca/cacert.pem
```

### 6. Install GameInputRedist

```bash
WINEPREFIX=~/Games/MinecraftBedrock/prefix/pfx \
  ~/.steam/root/compatibilitytools.d/GDK-Proton10-32/files/bin/wine64 \
  msiexec /i ~/vmshare/minecraft-bedrock/Installers/GameInputRedist.msi /qn
```

### 7. Copy xgameruntime DLLs to Game Directory

```bash
cp ~/.steam/root/compatibilitytools.d/GDK-Proton10-32/files/lib/wine/x86_64-windows/xgameruntime.dll \
  ~/vmshare/minecraft-bedrock/
cp ~/.steam/root/compatibilitytools.d/GDK-Proton10-32/files/lib/wine/x86_64-windows/xgameruntime.dll.threading \
  ~/vmshare/minecraft-bedrock/
```

### 8. Configure Lutris

Add the game to Lutris's database:

```bash
sqlite3 ~/.var/app/net.lutris.Lutris/data/lutris/pga.db \
  "INSERT INTO games (name, slug, runner, executable, directory, installed, configpath, platform) \
   VALUES ('Minecraft Bedrock', 'minecraft-bedrock', 'wine', \
   '$HOME/vmshare/minecraft-bedrock/Minecraft.Windows.exe', \
   '$HOME/vmshare/minecraft-bedrock', 1, 'minecraft-bedrock', 'windows');"
```

Create the game config at `~/.var/app/net.lutris.Lutris/config/lutris/games/minecraft-bedrock.yml`:

```yaml
game:
  exe: /home/<user>/vmshare/minecraft-bedrock/Minecraft.Windows.exe
  prefix: /home/<user>/Games/MinecraftBedrock/prefix
  working_dir: /home/<user>/vmshare/minecraft-bedrock
name: Minecraft Bedrock
runner: wine
slug: minecraft-bedrock
wine:
  version: GDK-Proton10-32
  runner_type: proton
system:
  env:
    STEAM_COMPAT_DATA_PATH: /home/<user>/Games/MinecraftBedrock/prefix
    STEAM_COMPAT_CLIENT_INSTALL_PATH: /home/<user>/.steam/root
    PROTONPATH: /home/<user>/.steam/root/compatibilitytools.d/GDK-Proton10-32
    GAMEID: minecraft-bedrock
    STORE: none
```

Replace `<user>` with your username.

### 9. Launch

Open Lutris and click Play on "Minecraft Bedrock", or run directly:

```bash
./scripts/launch.sh
```

## Known Limitations

- **No Microsoft account login** — XUser is not implemented in WineGDK
- **No Realms or featured servers** — requires Microsoft auth
- **Multiplayer workaround** — use [ProxyPass](https://minecraft.wiki/w/Tutorial:Playing_Minecraft_on_Linux) to proxy external servers as LAN
- **File picker crashes** — import worlds manually by extracting `.mcworld` files into `com.mojang/minecraftWorlds/`
- **Wine prefix corruption** — crashes can corrupt the prefix; back up saves regularly

## References

- [Minecraft Wiki - Playing on Linux](https://minecraft.wiki/w/Tutorial:Playing_Minecraft_on_Linux)
- [GDK-Proton (GitHub)](https://github.com/Weather-OS/GDK-Proton)
- [WineGDK (GitHub)](https://github.com/Weather-OS/WineGDK)
- [MCGDKLauncher (GitHub)](https://github.com/oliik2013/MCGDKLauncher)
