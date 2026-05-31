# Minecraft Bedrock on Linux — Attempts Matrix & Next Steps

Codified record of everything tried across ~4 multi-day attempts, the results, and what to do
next. Last updated **2026-05-31**.

> **Ground-truth status (2026-05-31):** Bedrock **1.26.21 launches and the 3D world renders**
> under WineGDK (clang-23 build), with audio + LAN working. **The entire UI (cohtml) does NOT
> render** — no menus, buttons, HUD, or hotbar. **The game is therefore NOT playable yet.**
> (The README's "WORKING / plays" wording is optimistic and predates the cohtml finding; treat
> this file + upstream Weather-OS/WineGDK#54 as authoritative.)

---

## 1. The two black screens (don't confuse them)

There have been **two distinct "black screen" problems**, solved/diagnosed at different times:

| | Black screen **A** (resolved) | Black screen **B** (current blocker) |
|---|---|---|
| Symptom | Nothing renders at all (3D + UI black) | 3D world renders, **UI invisible** |
| Root cause | **Wrong game binary** — VM extraction silently left v1.26.3 in place when 1.26.21 expected; bgfx issued **zero draw calls** | **cohtml** (Coherent Gameface UI engine) renders nothing under Wine |
| Fixed by | Re-extracting the correct 1.26.21 binary + building WineGDK with **clang-23 + lld** (matches ChristopherHX) | **UNSOLVED** |
| Evidence | Issues #4, #5, #6; upstream #54 | memory `minecraft-bedrock-linux-status`; this file §6 |

Earlier hypotheses for A (bgfx render-thread sync, FORMAT_SUPPORT2 stub, NVIDIA/Wayland, GPU
vendor) were **all ruled out** — see §5.

---

## 2. Runtime / build matrix (high level)

Legend: ✅ works · ❌ broken · ⚠️ partial · — n/a · ? untested

| # | Runtime | Build | Wine | Launches | 3D | UI (cohtml) | Mouse | Gamepad | Login | LAN | Verdict |
|---|---------|-------|------|:--:|:--:|:--:|:--:|:--:|:--:|:--:|---------|
| 1 | **mcpelauncher** (Android repack) | — | — | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **Dead end for latest** — can't run 1.26.x → cross-play version mismatch |
| 2 | **GDK-Proton** (Lutris) | GE-Proton base | Proton | ✅ | ❌* | ? | ? | ? | ❌ | ⚠️ | Black screen on 1.26.20+ (era of wrong binary). Weather-OS says don't use for 1.26.20+. **BUT carries Proton shared-resource patches → re-test for cohtml (§6)** |
| 3 | **GDK-Proton10-32** (Heroic) | GE-Proton10-32 | Proton | ✅ | ❌* | ? | ? | ? | ❌ | ⚠️ | Same as #2; install present at `~/Games/GDK-Proton10-32` |
| 4 | **WineGDK gcc** | gcc | 11.x | ✅ | ❌* | ❌ | ? | ? | ❌ | ✅ | Black screen (wrong-binary era) |
| 5 | **WineGDK clang-20** | clang-20 | **11.8** | ✅ | ✅ | ❌ | ⚠️ | ? | ❌ | ✅ | 3D renders w/ correct binary; UI invisible. Install: `~/Projects/WineGDK/install` |
| 6 | **WineGDK clang-23 + lld** | clang-23 | **11.1** | ✅ | ✅ | ❌ | ⚠️ | ? | ❌ | ✅ | **Current main path.** Matches ChristopherHX. 3D ✅, UI ❌. Install: `~/Projects/WineGDK/install-clang23` |

\* Black screen in rows 2–4 was **black screen A** (wrong binary), not necessarily a property of
that runtime. They have **not** been re-tested with the correct 1.26.21 binary for the cohtml
question — that's the key gap (§6, experiment 1).

---

## 3. Rendering-config sub-matrix (black-screen-A investigation)

13 graphics configurations were tried before the wrong-binary root cause was found. **All showed
black screen** — because the binary was wrong, not because of these settings. Recorded so we
don't repeat them:

| Config | D3D backend | Display | Result |
|---|---|---|---|
| GDK-Proton10-32 default | DXVK + vkd3d-proton | Wayland | black |
| GDK-Proton10-32 `PROTON_USE_BUILTIN3D=1` | wined3d | Wayland | black |
| GDK-Proton10-32 `WINE_DISABLE_VULKAN_OPWR=1` | DXVK | Wayland | black |
| WineGDK gcc | wined3d OpenGL | XWayland | black |
| WineGDK gcc | wined3d Vulkan | XWayland | black |
| WineGDK clang-20 | wined3d OpenGL | XWayland | black |
| WineGDK | wined3d Vulkan + **lavapipe** (SW) | XWayland | black (rules out GPU/driver) |
| WineGDK | **bgfx native Vulkan** (d3d11/12 blocked) | XWayland | black |
| WineGDK | DXVK | **Xephyr** nested X11 | black |
| WineGDK | DXVK, **CSMT off**, backbuffer offscreen | XWayland | black |
| WineGDK | Wine **virtual desktop** | XWayland | game exits early |
| WineGDK + correct 1.26.21 binary | DXVK | XWayland | **3D renders ✅** |
| ChristopherHX reference | DXVK | Intel UHD 620 | 1,587 draws ✅ |

---

## 4. Fork & branch inventory (WineGDK ecosystem)

Local clone: `~/Projects/WineGDK/src` — remotes `upstream`=Weather-OS, `origin`=jphein, `lukas`=LukasPAH.

| Fork / branch | Purpose | State (2026-05-31) | Relevance |
|---|---|---|---|
| **Weather-OS/WineGDK** master | Upstream baseline | Maintainer semi-active (burst 2026-05-07, then quiet) | Base |
| **LukasPAH/next** | Integration: WinAppRuntime bootstrap stubs, core-input crash fixes, xgameprotocol, sandboxId guard | Active to 2026-04 | Our working base (`lukas-next-local`) |
| **LukasPAH/minimal-xbl** | `next` + Xbox Live **device-code login** (writes URL+code to JSON) + xgamesave stubs | **Updated 2026-05-31 — most current** | **Adopt for login** |
| **olivi-r/rebased-xuser** | Deep XUser OAuth/XSTS token impl (RequestOAuth/XSTS/XToken, key gen, gamertag) | Active to 2026-05-25 | Source of PR #33/#40; deepest login work |
| **olivi-r/xlauncher** | XLauncher + opengl32 GLES passthrough + xgameruntime XNetworking GUID fix | Active | Launcher support |
| **ChristopherHX/xuser-via-xgameruntime** | "Minimal xbl" routed via xgameruntime (= PR #46) | To 2026-05-18 | Overlaps LukasPAH minimal-xbl |
| **jphein/WineGDK** feature branches | gameinputredist-builtin, gameconfighelper-stub, kernelbase-package-apis, ntdll-wnf-stubs, ntdll-license-device, twinapi-datatransfermanager, windows-applicationmodel-coreapp | Correspond to **closed** PRs #47–#53 | Carry locally; **cannot upstream** (clean-room, §7) |
| **jphein local `wip/input-pointer-fixes`** | WM_POINTER mouse plumbing for cohtml/GameInput (NtUserEnableMouseInPointer, synthesize WM_POINTER* from mouse msgs, GetPointerFrame* stubs, D3D11 FORMAT_SUPPORT2) | Committed 2026-05-31 (preserved from attempt #2) | **The mouse/gamepad work that "almost got there"** |

**Key upstream PRs:** #32 (mouse, ink0rr) — open, unmerged; #33/#40 (XUser, olivi-r) — open;
#46 (minimal xbl, ChristopherHX) — open; #31 (xgameprotocol, LukasPAH) — closed; #47–#53 (jphein)
— self-closed (clean-room).

---

## 5. Definitively ruled out

- **Not GPU-vendor specific** — lavapipe (software Vulkan) shows the same zero-draw black screen.
- **Not the D3D11 impl** — DXVK 2.7.1 and wined3d both black (in wrong-binary era).
- **Not `D3D11_FEATURE_FORMAT_SUPPORT2`** — ChristopherHX's working Intel system also returns `E_NOTIMPL`.
- **Not bgfx thread-sync** — render thread is alive (UpdateSubresource/clears happen); it correctly skips draws because the main thread never set vertex streams — which was the wrong binary.
- **Not NVIDIA/Wayland/XWayland** — reproduced under lavapipe and Xephyr.
- **Not the game files being corrupt** — verified exe size/version; issue was *stale* (1.26.3) not corrupt.
- **GameInput error dialog** — root-caused (game's `GameInputInitialize` redist path). Mitigated by builtin GameInput stub + removing that export; a binary NOP patch exists as fallback.

---

## 6. Current blocker: cohtml UI not rendering — root-cause hypothesis & plan

**Hypothesis (high confidence):** cohtml/Renoir renders the UI into its own GPU texture and
composites it onto the 3D scene via a **shared D3D resource (keyed-mutex / NT-handle)**. Bare
WineGDK is *vanilla Wine* and lacks Proton's shared-resource patches:
- DXVK `OpenSharedResourceByName` is `E_NOTIMPL`; DXVK shared resources need Wine patches (Proton-only historically).
- VKD3D-Proton added upstream-Wine shared-resource support only in **v3.0 (Nov 2025)**.
- RenderDragon auto-selects the highest backend (often **D3D12** → VKD3D path) on capable GPUs.

Supporting evidence: **Civilization VII** (also Coherent Gameface) renders its UI fine on
Proton/Steam Deck → Gameface is not Wine-incompatible; the gap is the *environment*.

**Current prefix:** DXVK (`d3d11`/`dxgi`) + vkd3d-proton (`d3d12`/`d3d12core`); game options
`graphics_api:0`, `graphics_mode:0` (Classic, forced to dodge deferred-renderer crash).

### Prioritized experiments
1. **Re-test the SAME 1.26.21 binary on GDK-Proton** (it carries Proton shared-resource patches).
   If the UI appears on GDK-Proton but not bare WineGDK → root cause confirmed, and the fix is to
   cherry-pick Proton's shared-resource (winevulkan/dxgi) patches into the clang-23 WineGDK build.
2. **Trace the share directly:** `WINEDEBUG=+dxgi,+d3d11 DXVK_LOG_LEVEL=info VKD3D_DEBUG=warn`,
   grep for `OpenSharedResource*` → `E_NOTIMPL` / "Not supported on this platform" / keyed-mutex
   acquire failures / "Fixing up wrong MiscFlags". This is the smoking gun if present.
3. **Force the D3D11 backend** (DXVK↔DXVK is better-supported than VKD3D↔DXVK). Confirm whether
   `graphics_api:0` is actually D3D11 and whether UI renders.
4. **Ensure VKD3D-Proton ≥ 3.0 + recent DXVK**, with **DXVK using Wine's dxgi** (correct DLL overrides).
5. **Force cohtml/Renoir CPU rasterizer fallback** (if a reachable flag exists) — if the UI then
   appears, it proves the GPU shared-texture path is the break.
6. **Confirm the `graphics_mode:0` (Classic) confounder** — verify forcing Classic didn't itself
   change UI compositing; check whether UI was ever visible in any mode.

---

## 7. Constraints & lessons

- **Clean-room:** AI-assisted Wine patches violate Wine's contribution rules. Keep our patches in
  jphein forks / local `wip/*` branches; **do not** submit upstream (jphein already self-closed
  PRs #47–#53 for this reason).
- **Upstream comments:** only on jphein repos, never Weather-OS/LukasPAH. Keep comments to 1–2 sentences.
- **`xgameruntime.dll.threading`** is a native Microsoft DLL — must come from VM extraction, not built by WineGDK.
- **`wine msiexec` hangs** on GameInputRedist.msi → use `msiextract` (msitools).
- **VM extraction can silently leave a stale binary** — always verify version after `host-copy-from-vm.sh` (caused black screen A, cost ~days).

---

## 8. Local asset inventory

| Asset | Path | Notes |
|---|---|---|
| WineGDK source | `~/Projects/WineGDK/src` | git; branch `wip/input-pointer-fixes`; backups `backup/lukas-next-local-2026-05-31` |
| Build clang-20 | `~/Projects/WineGDK/build64-clang` → `install/` | wine-11.8 |
| Build clang-23 | `~/Projects/WineGDK/build64-clang23` → `install-clang23/` | wine-11.1 (current path) |
| Build gcc | `~/Projects/WineGDK/build64` | older |
| Game (WineGDK target) | `~/Games/minecraft-bedrock/game` | 1.26.21, prefix at `../prefix` |
| Game (Lutris/GDK-Proton) | `~/Games/minecraft-bedrock-edition-lutris/game` | GDK-Proton target |
| GE-Proton10-32 | `~/Games/GDK-Proton10-32` | Heroic runtime |
| Reference VM | KVM Win11 @ 192.168.122.x | source of game extraction; no 3D accel |
| Forks (mine) | jphein/{minecraft-bedrock-linux, WineGDK, GDK-Proton} | |

---

*Generated while reorganizing after attempt #4. See memory notes `minecraft-bedrock-linux-status`
and `winegdk-upstream-prs` for the live short-form summary.*
