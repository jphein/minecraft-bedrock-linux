# Playing Minecraft Bedrock 26.32 on Linux

**Status (2026-06-28): playable.** Runs on bare WineGDK + DXVK. Menu renders, **gamepad works**,
**keyboard works**, and it connects to the **Luna** server (and other Tailscale BDS servers) via the
LAN proxy. **Menu mouse-clicks** may need a short wait on 26.3x (see Limitations) — keyboard/gamepad
always work.

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

With the LAN proxy running, your remote BDS servers appear in **Play → Servers/Friends → LAN Games**:
just select one and **Join** — no address typing.

Put your real server addresses in **`scripts/servers.conf`** (copy
`scripts/servers.conf.example`). That file is **gitignored** so your private (e.g. Tailscale) IPs are
never committed. One per line:

```
# remoteIP:remotePort:localPort:Name
100.x.y.z:19132:19132:My Server
100.x.y.z:8890:8890:Another Server
```

To add a server directly in-game instead: **Add Server** → address + port → Save → Join.

## Input

- **Gamepad** (Xbox / Stadia / PS3): D-pad/stick to move, A to select. Connect the controller
  **before** launching (GameInput enumerates at startup). Xbox & Stadia go through XInput; PS3 and
  other generic HID pads through DirectInput — both handled by our WineGDK build.
- **Keyboard:** arrows/Tab/Enter to navigate; WASD in-world.
- **Mouse:** in-world mouse-look works; **menu clicks** may need the ~5s gate wait on 26.3x
  (use keyboard or gamepad if a click doesn't land). See Limitations.

## Gotchas

- **Silent "no window" on launch** = leftover `lan-proxy.py` (holding UDP 19132/8890) or zombie
  wine/wineserver from a previous run. The game process starts but hangs with 0% CPU and an empty
  log. Fix: `pkill -9 -f Minecraft.Windows.exe; pkill -9 -f lan-proxy; <wineserver> -k` then relaunch.
  `play-bedrock.sh` does this automatically.
- **"Missing required component" error screen** instead of the menu: an intermittent GDK
  component-check race — just relaunch.
- **A menu mouse-click doesn't land** = give the menu the ~5s gate wait, or fall back to
  keyboard/gamepad. On 26.3x the launcher runs Wine's **builtin** dwmapi (our custom click-hook
  proxy page-faults under the new pointer-input API), so the menu lacks the click-through hook. The
  game still renders and plays normally. See Limitations.

## How it works (the fixes)

- **WineGDK** (`~/Projects/WineGDK`, branch `wip/input-xbl`):
  - Gamepad: `game_input2_GetCurrentReading` returned `E_NOTIMPL` for gamepads — implemented
    `read_gamepad()` (XInput, then DInput8 fallback) → real controller state. (commit `48250f5b`)
  - Mouse device: kept dropped on purpose — retaining it triggers the error screen.
- **gameinput.dll** built drop-mouse + gamepad, installed into `install-clang23`.
- Launch config: builtin GameInput (`gameinput=b`), **no** `GameInputRedist.dll`. On 26.3x, **builtin**
  dwmapi (`dwmapi=b`) — the custom click-hook proxy from 1.26.21 page-faults under 26.3x's new
  pointer-input API, so we drop it and the menu loses the mouse-click hook (game still renders/plays).

## Limitations

- **Menu mouse-clicks may not register on 26.3x.** The custom dwmapi click-hook proxy that drove menu
  clicks on 1.26.21 **page-faults** under 26.3x's reworked pointer-input API, so the launcher falls
  back to Wine's **builtin** dwmapi (`dwmapi=b`). The game renders and plays fine; in the menu, give it
  the ~5s gate wait before clicking, or use keyboard/gamepad. (Underlying cause is the same as before:
  Bedrock's pointer path wants a GameInput mouse device — which trips the GDK "missing required
  component" check — or `Microsoft.UI.Input.dll`, which never loads under Wine here.) Tracked in issues
  #8/#9.
