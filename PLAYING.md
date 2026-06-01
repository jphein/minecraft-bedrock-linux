# Playing Minecraft Bedrock 1.26.21 on Linux

**Status (2026-05-31): playable.** Runs on bare WineGDK + DXVK. Menu renders, **gamepad works**,
**keyboard works**, and it connects to the **Luna** server (and other Tailscale BDS servers) via the
LAN proxy. The only thing not working is **mouse clicks in the cohtml menu** (see Limitations).

## Quick start

Launch from the GNOME dash: **"Minecraft Bedrock"**
(right-click for **Play (Windowed)** / **Play (no LAN proxy)**).

Or from a terminal:

```bash
~/Projects/minecraft-bedrock-linux/scripts/play-bedrock.sh            # fullscreen
~/Projects/minecraft-bedrock-linux/scripts/play-bedrock.sh --windowed # windowed
~/Projects/minecraft-bedrock-linux/scripts/play-bedrock.sh --no-proxy # skip the LAN proxy
```

The launcher: kills stale processes (important — see Gotchas), starts the LAN proxy so the remote
servers show up under **LAN Games**, then launches the game.

## Connecting to Luna (and the other servers)

With the LAN proxy running, the Tailscale BDS servers appear in **Play → Servers/Friends → LAN Games**:
just select **Luna** and **Join** — no address typing.

| Name              | Address                | Note            |
|-------------------|------------------------|-----------------|
| Luna              | `REDACTED-IP:8890`    | Luna World, Creative |
| Redacted Server | `REDACTED-IP:19132`   |                 |
| donkey            | `REDACTED-IP:8888`    |                 |
| Galaxy Tab        | `REDACTED-IP:19132` | redacted-host (offline until powered on) |

Server list lives in `scripts/play-bedrock.sh` (`SERVERS=(...)`). To add a server directly in-game
instead: **Add Server** → address + port → Save → Join.

## Input

- **Gamepad** (Xbox / Stadia / PS3): D-pad/stick to move, A to select. Connect the controller
  **before** launching (GameInput enumerates at startup). Xbox & Stadia go through XInput; PS3 and
  other generic HID pads through DirectInput — both handled by our WineGDK build.
- **Keyboard:** arrows/Tab/Enter to navigate; WASD in-world.
- **Mouse:** does not click in the menu (use keyboard or gamepad). See Limitations.

## Gotchas

- **Silent "no window" on launch** = leftover `lan-proxy.py` (holding UDP 19132/8890) or zombie
  wine/wineserver from a previous run. The game process starts but hangs with 0% CPU and an empty
  log. Fix: `pkill -9 -f Minecraft.Windows.exe; pkill -9 -f lan-proxy; <wineserver> -k` then relaunch.
  `play-bedrock.sh` does this automatically.
- **"Missing required component" error screen** instead of the menu: an intermittent GDK
  component-check race — just relaunch.

## How it works (the fixes)

- **WineGDK** (`~/Projects/WineGDK`, branch `wip/input-xbl`):
  - Gamepad: `game_input2_GetCurrentReading` returned `E_NOTIMPL` for gamepads — implemented
    `read_gamepad()` (XInput, then DInput8 fallback) → real controller state. (commit `48250f5b`)
  - Mouse device: kept dropped on purpose — retaining it triggers the error screen.
- **gameinput.dll** built drop-mouse + gamepad, installed into `install-clang23`.
- Launch config: builtin GameInput (`gameinput=b`), **no** `GameInputRedist.dll`, native dwmapi proxy.

## Limitations

- **Mouse clicks in the cohtml menu don't register.** Root cause: Bedrock's pointer input wants
  either a GameInput mouse device (which trips the GDK "missing required component" check) or
  `Microsoft.UI.Input.dll` (which never loads under Wine here). Use keyboard or gamepad. Tracked in
  issues #8/#9.
