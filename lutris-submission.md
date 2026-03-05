# Lutris.net Installer Submission

Submit at: https://lutris.net/games/minecraft-bedrock-edition/installer/new

## Fields

**Version:**
```
GDK-Proton10 (game files from Windows)
```

**Runner:**
```
Linux
```

**Description:**
```
Runs Minecraft Bedrock (GDK build) via GDK-Proton. Requires game files extracted from a Windows install.
```

**Notes:**
```
You must extract decrypted game files from Windows first (Xbox App games are encrypted at rest). Full instructions: https://github.com/jphein/minecraft-bedrock-linux
```

**Script:**
```yaml
require-binaries: curl, zstd, tar

files:
- game_exe: "N/A:Select any file inside your extracted Minecraft Bedrock game directory"

installer:
  - execute:
      command: >-
        mkdir -p "$GAMEDIR/game" &&
        GAME_SRC="$(dirname "$game_exe")" &&
        cp -a "$GAME_SRC"/. "$GAMEDIR/game/"

  - execute:
      command: >-
        if [ ! -d "$GAMEDIR/GDK-Proton10-32" ]; then
        curl -sL "https://github.com/Weather-OS/GDK-Proton/releases/download/release10-32/GDK-Proton10-32.tar.gz"
        | tar xz -C "$GAMEDIR";
        fi

  - execute:
      command: >-
        WORK=$(mktemp -d) &&
        cd "$WORK" &&
        curl -sLO "https://repo.msys2.org/mingw/mingw64/mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar.zst" &&
        zstd -d mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar.zst &&
        tar xf mingw-w64-x86_64-curl-8.12.1-1-any.pkg.tar &&
        cp mingw64/bin/libcurl-4.dll "$GAMEDIR/game/XCurl.dll" &&
        rm -rf "$WORK"

  - execute:
      command: >-
        mkdir -p "$GAMEDIR/etc/ssl/certs" &&
        curl -sL -o "$GAMEDIR/etc/ssl/certs/ca-bundle.crt" "https://curl.se/ca/cacert.pem"

  - execute:
      command: >-
        cp "$GAMEDIR/GDK-Proton10-32/files/lib/wine/x86_64-windows/xgameruntime.dll" "$GAMEDIR/game/" &&
        cp "$GAMEDIR/GDK-Proton10-32/files/lib/wine/x86_64-windows/xgameruntime.dll.threading" "$GAMEDIR/game/"

  - execute:
      command: >-
        mkdir -p "$GAMEDIR/prefix/pfx" &&
        mkdir -p "$HOME/.steam/root" &&
        if [ -f "$GAMEDIR/game/Installers/GameInputRedist.msi" ]; then
        WINEPREFIX="$GAMEDIR/prefix/pfx"
        "$GAMEDIR/GDK-Proton10-32/files/bin/wine64"
        msiexec /i "$GAMEDIR/game/Installers/GameInputRedist.msi" /qn 2>/dev/null || true;
        fi

  - write_file:
      file: $GAMEDIR/launch.sh
      content: |
        #!/usr/bin/env bash
        set -euo pipefail
        GAMEDIR="$(cd "$(dirname "$0")" && pwd)"
        export STEAM_COMPAT_DATA_PATH="$GAMEDIR/prefix"
        export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/root"
        export PROTONPATH="$GAMEDIR/GDK-Proton10-32"
        exec "$GAMEDIR/GDK-Proton10-32/proton" run "$GAMEDIR/game/Minecraft.Windows.exe"

  - chmodx: $GAMEDIR/launch.sh

game:
  exe: launch.sh
  working_dir: $GAMEDIR

system:
  env:
    STEAM_COMPAT_DATA_PATH: $GAMEDIR/prefix
    STEAM_COMPAT_CLIENT_INSTALL_PATH: $HOME/.steam/root
    PROTONPATH: $GAMEDIR/GDK-Proton10-32
    GAMEID: minecraft-bedrock
    STORE: none

install_complete_text: >-
  Minecraft Bedrock has been installed! Launch it from Lutris.
  Note: This is an experimental setup with known limitations -
  no Microsoft account login, no Realms, and no featured servers.
  See the project README for workarounds.
```
