# Performance tuning (this machine)

Polished perf extras for **GTX 1650 (4 GB, driver 595.71.05) + Intel i7-3770 (4c/8t, 2012) + 15.6 GiB RAM**, Ubuntu 24.04, WineGDK clang-23 + **DXVK 2.7.1** (D3D11-only path; no vkd3d-proton).

> The big picture: this box is **CPU-limited** (an old Ivy-Bridge i7 + Wine/DXVK translation overhead), and the GPU has only **4 GB VRAM**. So the largest wins are **lowering chunk/view distance** (CPU) and **MSAA/fancy effects** (GPU+VRAM) — not env-var micro-tuning. The system itself is already well-tuned.

## Use it

```bash
scripts/play-bedrock.sh --perf            # gamemode + ioprio + tuned dxvk.conf
scripts/play-bedrock.sh --perf --hud      # + MangoHud overlay (fps, temps, vram)
scripts/play-bedrock.sh --perf --windowed
scripts/apply-perf-options.sh             # apply tuned in-game video settings (game CLOSED)
```

`config/dxvk.conf` is applied on **every** launch (safe + beneficial); `--perf`/`--hud`/`apply-perf-options.sh` are opt-in.

## What each piece does

### `config/dxvk.conf` (DXVK 2.7.1, verified keys)
- `dxvk.enableGraphicsPipelineLibrary = Auto` — background pipeline compilation (modern replacement for the old async fork / state cache); cuts shader-comp stutter, self-disables if unsupported.
- `dxvk.numCompilerThreads = 6` — leave 2 of 8 threads free so compiles don't starve the render/sim threads on this CPU.
- `dxgi.maxFrameLatency = 2` — fewer queued frames = less input lag + memory churn on a slow CPU.
- `dxvk.enableMemoryDefrag = Auto` — reclaims VRAM on the 4 GB card.

### `scripts/apply-perf-options.sh` (in-game video settings)
Tuned for this hardware (run with the game closed; makes a backup; idempotent):

| Setting | Was | Now | Why |
|---|---|---|---|
| `gfx_viewdistance` | 544 (**34 chunks**) | **192 (12 chunks)** | Chunk meshing is single-thread CPU work — the #1 FPS lever on the old i7. 34 chunks is wildly over-provisioned. (128=max fps, 256 if frametimes hold.) |
| `gfx_msaa` | 2 | **0** | MSAA is GPU + VRAM heavy for little benefit; frees 4 GB-card VRAM and reduces surface complexity in the fragile render path. |
| `gfx_smoothlighting` | 1 | **0** | Adds per-vertex lighting work to chunk meshing (the bottleneck stage). |
| `gfx_transparentleaves` | 1 | **0** | Fancy leaves = big overdraw/geometry in forests. |
| `gfx_fancyskies` | 1 | **0** | Cosmetic; free it back. |
| `gfx_vsync` | 1 | **0** | In-engine vsync fights the compositor under Wine; cap fps instead. |
| `gfx_max_framerate` | 0 (∞) | **60** | Uncapped fps wastes CPU + worsens pacing/heat on an old quad-core. |
| `graphics_mode` | 0 (Fast) | **0 (Fast)** | **Do NOT raise.** Fabulous uses deferred render targets / shared textures and is the most likely to break our cohtml/shared-texture path (and too heavy for 4 GB). |

### `--perf` (system)
- **`gamemoderun`** — governor is already `performance` (so that part's a no-op), but it still nudges the GPU performance level + sets I/O priority + inhibits the screensaver.
- **`ionice -c2 -n0`** — best-effort top I/O priority for chunk/texture streaming.

### `--hud`
- **MangoHud** overlay (fps, frametimes, CPU/GPU temps, RAM/VRAM). Use it once to see whether dips are GPU-bound (lower view distance) or CPU-bound (cap fps / accept).

## Things that DON'T help here (verified — intentionally omitted)
- **`__GL_SHADER_DISK_CACHE` / `__GL_THREADED_OPTIMIZATIONS` / `__GL_MaxFramesAllowed`** — OpenGL-only; **no effect on DXVK/Vulkan**. The NVIDIA Vulkan pipeline cache (`~/.cache/nvidia`) is automatic.
- **`DXVK_STATE_CACHE` / `DXVK_STATE_CACHE_PATH`** — **removed in DXVK 2.7** (GPL replaced it). No effect.
- **`DXVK_ASYNC`** — async *fork* only; this is mainline 2.7.1 (uses GPL). No effect.
- **`VKD3D_*`** — no vkd3d-proton installed and Bedrock is D3D11-only.
- **`nvidia-settings` PowerMizer** — it's an X-screen attribute and **fails on this Wayland session** ("No targets match"). GPU power is fixed at 75 W, so `nvidia-smi -pl` does nothing either. Leave GPU clocking to gamemode + the driver.
- **`vm.max_map_count`** (already 1,048,576), **THP** (already `madvise`), **CPU governor** (already `performance`) — all already optimal; no sysctl changes needed.

## Optional one-time system tweak
To let gamemode renice without per-launch sudo, either add yourself to the `gamemode` group (`sudo usermod -aG gamemode $USER`, re-login) or drop an `/etc/gamemode.ini` with `[general] renice=5 / ioprio=0`. Reversible; not required.
