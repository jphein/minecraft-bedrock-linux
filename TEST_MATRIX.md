# Test Matrix — cohtml UI investigation

Runnable, fill-in-as-you-go matrix for finding/fixing the **current blocker**: the cohtml
(Coherent Gameface) UI not rendering on WineGDK while the 3D world does. Background &
hypothesis: [`ATTEMPTS.md`](ATTEMPTS.md) §6 and [issue #7](https://github.com/jphein/minecraft-bedrock-linux/issues/7).

## How to run

```bash
scripts/run-test.sh list            # show configs
scripts/run-test.sh trace-shared 40 # run one config, wait 40s, screenshot + grep log
```

Each run writes to `/tmp/mctest/<config>/`: `launch.log`, `screenshot.png`, `findings.txt`.
**Decide the UI verdict by looking at `screenshot.png`**, then fill the row below.
The harness kills any old game first (no zombie windows).

Per-run env knobs: `WINEGDK_DIR`, `GAME_DIR`, `PREFIX_DIR`, and a wait-seconds arg.

## Result legend
✅ works · ❌ broken · ⚠️ partial · ? not yet run

## Matrix (WineGDK configs — via `run-test.sh`)

| Config | What it isolates | Launches | 3D | **UI (cohtml)** | Mouse | Notes / key log findings |
|---|---|:--:|:--:|:--:|:--:|---|
| `baseline` | current state (DXVK d3d11 + vkd3d d3d12, api:0, mode:0) | ? | ? | ? | ? | expected: 3D ✅, UI ❌ — confirms starting point |
| `trace-shared` | **smoking gun** — `+dxgi,+d3d11` + DXVK/VKD3D logs | ? | ? | ? | ? | grep `OpenSharedResource*`→`E_NOTIMPL` / "Not supported on this platform" / keyed-mutex acquire fail. **Run this first.** |
| `force-d3d11` | DXVK↔DXVK share path (better-supported) | ? | ? | ? | ? | confirm `graphics_api` D3D11 value first (see below) |
| `force-d3d12` | VKD3D↔DXVK share path | ? | ? | ? | ? | the path that auto-selects on capable GPUs |
| `wined3d` | builtin wined3d (no DXVK/vkd3d) | ? | ? | ? | ? | control — does UI behave differently without DXVK? |
| `cohtml-cpu` | force Renoir CPU rasterizer (env, speculative) | ? | ? | ? | ? | **if UI appears ⇒ GPU shared-texture path is the break** |
| `clang20` | clang-20 build vs clang-23 | ? | ? | ? | ? | compiler control |

## Cross-runtime comparison (run separately — not via `run-test.sh`)

The single highest-value experiment. GDK-Proton carries Proton's shared-resource patches that
bare WineGDK lacks; if the UI renders there, the root cause is confirmed.

| Runtime | Launch method | UI (cohtml) | Notes |
|---|---|:--:|---|
| GDK-Proton (Lutris) | Lutris / `proton run` against `~/Games/minecraft-bedrock-edition-lutris/game` | ? | **same 1.26.21 binary** — that's the point |
| GE-Proton10-32 (Heroic) | Heroic, `~/Games/GDK-Proton10-32/proton` | ? | alt Proton runtime |
| bare WineGDK clang-23 | `scripts/run-test.sh baseline` | ? | reference (UI broken) |

**Interpretation:** UI ✅ on GDK-Proton + ❌ on bare WineGDK ⇒ shared-resource patches are the
fix → cherry-pick Proton's `winevulkan`/`dxgi` shared-resource patches into the clang-23 WineGDK
build. UI ❌ everywhere ⇒ look upstream of the share (cohtml init failing, missing helper, etc.).

## Things to confirm before trusting some rows

- **`graphics_api` values:** options.txt currently has `graphics_api:0`. Confirm what 0/1/2 map to
  in this MC build (D3D11 vs D3D12 vs auto) — the `force-d3d11`/`force-d3d12` rows assume 1/2;
  fix the script if wrong. Check the d3d device-creation lines in `baseline`'s log to see which
  backend is actually live.
- **cohtml CPU env names** (`cohtml-cpu`) are speculative; if they do nothing, look for a real
  RenderDragon/cohtml flag (game logs, command line, or a `.coherent`/config file).
- **`graphics_mode:0` (Classic) confounder:** all rows force Classic to dodge the deferred-renderer
  crash. Note whether UI behavior changes if you ever get mode:2 stable.

## Run log

Record dated observations here as runs happen (newest first):

- **2026-05-31 — capture method solved:** on GNOME Wayland only `gnome-screenshot -w` (active window) works (grim/xwd/D-Bus/Xephyr all fail — see memory `gnome-wayland-game-capture`). It captures the FOCUSED window, so the game must be fullscreen+focused. Bare-WineGDK fullscreen (1849x1040) grabs focus → captured fine. **GDK-Proton's borderless 1928x1062 window does NOT grab focus** (GNOME focus-stealing prevention) → `-w` grabs the terminal instead. Need a focus nudge (manual click, or force exclusive fullscreen) for Proton runs.
- **2026-05-31 — KEY FINDING (patched clang-23 build, capture-mechanism test):** the game renders the **3D world AND a cohtml Ore-UI dialog** (GameInput "missing required component… Install"). So cohtml is NOT fundamentally failing to render — reframes blocker toward GameInput (#8). Needs confirming on vanilla.
- **2026-05-31 — build pipeline:** Weather-OS/master compiled but `make install` aborted on a Wine idl collision (`not overwriting just created windows.ui.text.core.idl`) before installing ntdll.so → broken install. Pipeline fixed to `make -i install` + never delete tree unless install complete. LukasPAH building.
