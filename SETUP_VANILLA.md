# Vanilla matrix — minimal game-side setup (documented)

Procedure for testing 6 vanilla upstream variants with the **minimum** game-side setup needed to
launch — and an explicit list of what is deliberately **NOT** applied. Every command run is logged
here per the "document everything" instruction. Approach rationale: [`memory: vanilla-matrix-approach`].

## Canonical game (held constant)

All runtimes point at **one** game dir so only the runtime varies:

- **Game dir:** `~/Games/minecraft-bedrock/game`
- **Binary:** `Minecraft.Windows.exe`, 242,760,528 bytes, version **1.26.20** (strings cap at 1.26.20; the same 242 MB exe is in the Lutris dir — verified identical version).
- Per-runtime **prefixes are separate** (a clean prefix per variant), the game dir is shared read-mostly.

## What's ALREADY present in the game dir (the minimal setup)

Verified 2026-05-31:

| File | Status | Why needed |
|---|---|---|
| `XCurl.dll` | present, **mingw libcurl** (not MS) | MS XCurl depends on Xbox Live; replaced with mingw curl so networking works |
| CA bundle | referenced by XCurl (`/mingw64/etc/ssl/certs/ca-bundle.crt`) | HTTPS for the mingw curl |
| `xgameruntime.dll` | present (896 KB) | GDK runtime; XTaskQueue etc. |
| `xgameruntime.dll.threading` | present (4.6 MB) | **native MS DLL from the VM** — game won't launch without it; not built by WineGDK |
| `Installers/GameInputRedist.msi` | present | GameInput reddistributable (see GameInput handling below) |
| `cohtml.WindowsDesktop.dll` | present (7.3 MB) | the Coherent Gameface UI engine (the render blocker, #7) |

## What we ADD per prefix (launch-enabling only — NOT input mods)

| Item | Why | Vanilla? |
|---|---|---|
| `GameConfigHelper.dll` stub | `gamelaunchhelper.exe` imports `OpenGameConfigForPackage`; absent in Wine → fails to launch | game-side stub, returns S_OK; launch-enabling, not input |
| `midlproxystub` DLL | Wine PE-mode bug resolving `combase` → `rpcrt4` forwarders (`ObjectStublessClient3..32`) | launch-enabling; may be unneeded on Proton (different build) — test |
| `GameInputRedist=b` override **or** install the MSI | MS redist's `GameInputInitialize` activates `Legacy.Gaming.Input` WinRT (absent in Wine) → crash; force the runtime's **builtin** redist instead (see #8) | DLL override, not a patch; needed to launch |
| `graphics_mode:0` (Classic) | deferred/PBR renderer races and crashes under Wine | options.txt setting |

## What is deliberately NOT applied (so it's vanilla)

- ❌ our custom **GameInput stub** (`stubs/gameinput/`) — the WM_POINTER IAT-patch / window-subclass UI fix
- ❌ the **WM_POINTER Wine patch** (`wip/input-*` — NtUserEnableMouseInPointer, synthesized WM_POINTER*)
- ❌ the **exe NOP patch** for the GameInput error dialog
- ❌ any `PROTON_USE_WINED3D` / forced-builtin-graphics tweaks from our modified `launch-proton.sh`

Each variant uses its **own runtime's** built-in `gameinput.dll` / `gameinputredist.dll` — that's the point of the vanilla baseline.

## Scoring (per variant)

`launches · 3D renders · cohtml UI renders · UI responds to mouse · keyboard · gamepad · MS login`
— recorded in [`TEST_MATRIX.md`](TEST_MATRIX.md). Mouse is scored twice (UI via WM_POINTER vs
gameplay via GameInput readings) because of the dual input path (#8). On Wayland, mouse-lock is
expected to fail (`SetCursorPos` warp) regardless — note but don't count against the variant.

## Runtimes

| # | Variant | Runtime path | Prefix |
|---|---|---|---|
| 1 | GDK-Proton (real, Weather-OS 10-32) | `~/Games/GDK-Proton10-32/proton` | fresh `~/Games/vanilla-prefixes/gdkproton` |
| 2 | WineGDK Weather-OS/master | `~/Projects/winegdk-vanilla/install-vanilla-weatheros` | fresh `.../winegdk-weatheros` |
| 3 | WineGDK LukasPAH/minimal-xbl | `…/install-vanilla-lukas` | fresh `.../winegdk-lukas` |
| 4 | WineGDK olivi-r/rebased-xuser | `…/install-vanilla-olivir` | fresh `.../winegdk-olivir` |
| 5 | WineGDK ChristopherHX/xuser-via-xgameruntime | `…/install-vanilla-christopherhx` | fresh `.../winegdk-christopherhx` |
| 6 | GE-Proton10-32 (plain-Proton control) | (download/locate GE-Proton) | fresh `.../ge-proton` |

## Run log (every command, newest first)

- 2026-05-31: reclaimed disk (apt clean + rm old gcc `build64`) 9.6G→15G free; launched
  `scripts/build-vanilla-matrix.sh` (bg) building variants 2–5; standardized game dir; wrote this doc.
