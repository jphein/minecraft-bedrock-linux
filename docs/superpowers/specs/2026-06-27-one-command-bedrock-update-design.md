# One-Command Bedrock Update — Design & Script Contract

**Date:** 2026-06-27
**Goal:** Collapse the entire Bedrock-update procedure (VM Store-update → extract → host-setup → push to katana → update terra BDS servers → smoke-verify) into a single command run from katana: `scripts/update-bedrock.sh`. Encodes the recipe reverse-engineered by hand on 2026-06-20 (the 26.21→26.31 update) so it never has to be rediscovered.

This document is the **authoritative contract**. Every script below must match these interfaces exactly so the pieces compose.

---

## Topology & hard constraints

- **katana** — JP's workstation; where the orchestrator runs. Has the repo + the WineGDK build + a playable client.
- **game** — Ubuntu host (`ssh` via Tailscale IP), GTX 1650 + i7-3770, runs the Win11 KVM VM. Passwordless sudo. The repo lives at `~/Projects/minecraft-bedrock-linux`.
- **VM `windows11`** — on game's libvirt NAT (`192.168.122.x`). **Reachable ONLY from game**, never from katana. So all VM ops are issued from a script running *on game* (one hop game→VM), never katana→game→VM triple-nested.
- **terra** — Azure VM (Tailscale only; public :22 blocked). Runs 3 Bedrock Dedicated Servers + 1 Java Fabric (`mcfabric` — NEVER touch). Passwordless sudo.
- **Bedrock requires client↔server protocol match** — the client and all 3 BDS must be the same release, or LAN-proxy play fails silently.

## Artifacts — ALL under the repo (`~/Projects/minecraft-bedrock-linux/`), per JP

- Scripts: `scripts/`
- **Logs: `logs/` (gitignored), one timestamped file per run** — replaces the `/tmp/mc-*.log` sprawl. Every script writes here (or to a path the orchestrator passes); nothing goes to `/tmp`.
- Config: `scripts/update-targets.conf` (gitignored; `.example` committed) — topology + private IPs.
- This design doc lives in `docs/superpowers/specs/`.

## Config schema — `scripts/update-targets.conf`

Sourced as bash. `BDS_SERVER` may repeat (collected into an array). Real file gitignored (private Tailscale IPs); `.example` committed with placeholders.

```bash
# Placeholders only — real values live in the gitignored scripts/update-targets.conf
GAME_SSH="<user>@<game-host>"         # how katana reaches the game host (Tailscale/LAN)
VM_NAME="windows11"                    # libvirt domain
VM_USER="<win-user>"                   # Windows user (ssh + C:\Users\<user>)
MC_PACKAGE_FAMILY="Microsoft.MinecraftUWP_8wekyb3d8bbwe"
MC_AUMID="Microsoft.MinecraftUWP_8wekyb3d8bbwe!Game"
TERRA_SSH="<user>@<bds-host>"          # how katana reaches the BDS host (Tailscale)
# Bedrock servers — "systemd_service:linux_user:udp_port:display_name" (repeat per server)
BDS_SERVER="mcbedrock:<svc-user>:19132:<world1>"
BDS_SERVER="mcbedrock2:<svc-user2>:8888:<world2>"
GAME_GAME_DIR="$HOME/Games/minecraft-bedrock/game"     # on game (resolved remotely)
KATANA_GAME_DIR="$HOME/Games/minecraft-bedrock/game"   # on katana
MIN_FREE_GB_GAME=5                     # abort extraction if game has less free
```

## Inter-script result protocol

A remote script signals machine-readable results to its caller on stdout as lines prefixed `RESULT ` (`RESULT key=value`), and uses **exit code** for success/failure (0 ok, non-zero abort). Callers parse `RESULT` lines and check exit codes. Human log lines go to stderr or the log file so they don't pollute `RESULT` parsing.

---

## Script contracts

### 1. `scripts/update-bedrock.sh` — orchestrator (runs on **katana**)

The one command. Flags: `--client-only` (skip terra servers), `--skip-vm` (re-extract current VM build; skip the Store update), `--skip-servers`, `--dry-run` (print what it would do, touch nothing destructive), `--yes` (no interactive confirms), `--help`.

Phases (each verifies before the next; **halt with a clear message on any failure** rather than proceeding):
1. **Preflight** — source `update-targets.conf` (error if missing → point at `.example`); start a timestamped log in `logs/`; `ssh $GAME_SSH true` reachable; report plan.
2. **Deliver scripts to game** — `rsync` the repo's `scripts/` (+ `config/`, `stubs/`) to `$GAME_SSH:~/Projects/minecraft-bedrock-linux/` so game runs the *current* (possibly unpushed) `game-update.sh`, `host-copy-from-vm.sh`, `setup.sh`, `vm-update-minecraft.ps1`. (rsync, not git — must work before anything is pushed.)
3. **Game-side update** — `ssh $GAME_SSH 'bash ~/Projects/minecraft-bedrock-linux/scripts/game-update.sh <flags>'`, tee output to the log. Parse `RESULT new_version=… exe_size=… smoke=…`. If game-update exits non-zero or `smoke=fail` → **halt**, report (the build is bad; nothing was pushed to katana; game.bak rollback intact).
4. **Push to katana** — back up `KATANA_GAME_DIR` → `…/game.bak-<oldver>` (CoW `cp --reflink=auto` or `mv`); delta-rsync `$GAME_SSH:GAME_GAME_DIR/` → `KATANA_GAME_DIR/` with `-a --partial --delete` in a resume-retry loop (game wifi drops); **do NOT use `--append-verify`** (files change in place). Verify katana exe is PE32+, size == game's, version == new_version.
5. **Servers** (unless `--client-only`/`--skip-servers`) — derive the matching BDS release from new_version; `scp scripts/update-bds-servers.sh $TERRA_SSH:/tmp/`; `ssh $TERRA_SSH 'bash /tmp/update-bds-servers.sh <args>'`; parse per-server `RESULT`. Halt on a server that fails to come up.
6. **Report** — summary table (client old→new on game+katana, each server old→new, smoke result) to stdout + log; print the final "Now launch it on katana/game and join a server" instruction. (No headless launch on katana — it would pop a window on JP's desktop.)

Safety: every overwrite has a backup first; version is re-verified after each copy (the 26.x "silent stale-binary" failure mode); `--dry-run` performs only read-only probes.

### 2. `scripts/game-update.sh` — game-side sequencer (runs on **game**)

Driven by the orchestrator over one SSH hop (also runnable standalone on game). Reads `update-targets.conf` from the repo. Flags pass through (`--skip-vm`, `--dry-run`). Steps:
1. Preflight: `df` on game ≥ `MIN_FREE_GB_GAME` (else abort with prune hint); ensure VM running — `sudo virsh domstate $VM_NAME`; if not, `sudo virsh start $VM_NAME` + wait; find VM IP via `sudo virsh domifaddr $VM_NAME` then fallback `sudo virsh net-dhcp-leases default` (a `192.168.122.x`); `ssh -o BatchMode=yes $VM_USER@$VM_IP true` (if it fails → abort: VM sshd not up / needs `vm-setup-ssh.ps1`).
2. **VM update** (skip if `--skip-vm`): `scp scripts/vm-update-minecraft.ps1 $VM_USER@$VM_IP:` then `ssh $VM_USER@$VM_IP 'powershell -ExecutionPolicy Bypass -File vm-update-minecraft.ps1'`. Parse its `RESULT new_version=…`. If `RESULT no_update=true` → still proceed to extract the current build (idempotent) unless caller wants strict.
3. **Backup** current `GAME_GAME_DIR` → sibling `game.bak-<oldver>` via `mv` (instant, disk-neutral; saves live in the prefix, not game/). Capture old exe size for comparison. Capture `xgameruntime.dll.threading` path from the backup for carry-forward.
4. **Extract**: `DEST_DIR="$GAME_GAME_DIR" bash scripts/host-copy-from-vm.sh "$VM_USER" "$VM_IP"`. Then VERIFY (catch silent-fail): exe is PE32+; size differs from old & ≥ 200 MB; version string in `AppxManifest.xml` (or InstallLocation) matches new_version; file count sane (~36k). Abort if any check fails (restore from game.bak).
5. **Carry-forward shims** the fresh extraction lacks: copy `xgameruntime.dll.threading` from `game.bak-<oldver>` → new `game/` (native MS DLL, not in the raw install, version-agnostic). (`GameConfigHelper.dll` is now installed by `setup.sh` from stubs.)
6. **Host setup**: `bash scripts/setup.sh` (must be run by absolute path or the fixed SCRIPT_DIR — see §6). It installs XCurl + deps + certs + xgameruntime.dll + prefix + GameInputRedist + midlproxystub + DXVK + gameinput stub + bootstrap stub + **GameConfigHelper** + graphics_mode:0.
7. **Local smoke** (game's session is locked but compositor up → `DISPLAY=:0` via Xwayland with mutter auth): launch the game with the **play-bedrock.sh env** (`gameinput=b;dwmapi=b`, NOT debug-launch.sh which lacks gameinput=b), capture to `logs/`, wait ~60s, check process-alive + render markers (`DXVK`, `swapchain`, `cohtml`, a real window via `xwininfo`), then kill. `smoke=pass` if rendered with 0 access-violation/page-fault; else `smoke=fail` + the failing log path.
8. Emit `RESULT new_version=… old_version=… exe_size=… file_count=… smoke=pass|fail`. Exit non-zero on any abort.

### 3. `scripts/vm-update-minecraft.ps1` — VM-side updater (runs **in the Win11 VM**)

Driven by `game-update.sh`. Steps:
1. `$old = (Get-AppxPackage Microsoft.MinecraftUWP).Version`.
2. Trigger the Store update scan (headless — this worked on 2026-06-20, no GUI):
   `Get-CimInstance -Namespace root\cimv2\mdm\dmmap -ClassName MDM_EnterpriseModernAppManagement_AppManagement01 | Invoke-CimMethod -MethodName UpdateScanMethod`
3. Poll `(Get-AppxPackage Microsoft.MinecraftUWP).Version` every 30s up to ~15 min until it changes. (On 06-20 the bump landed ~8 min after the scan.)
4. If changed: **launch-once** (extraction requires the updated package has run) — `Start-Process explorer "shell:AppsFolder\$AUMID"` (or the package-launch), wait ~40s, then `Stop-Process -Name Minecraft.Windows -Force` to release file locks before extraction.
5. Emit `RESULT new_version=<v> install_location=<path>` (and `RESULT no_update=true` if unchanged after timeout). Print human progress to the host console.
6. Param the package family / AUMID so it's not hardcoded.

### 4. `scripts/update-bds-servers.sh` — terra BDS updater (runs **on terra**, pushed by orchestrator)

Args: `--target <marketing e.g. 1.26.40>` (orchestrator derives from client version) and the `BDS_SERVER` triples (passed as args or via an env-embedded list). For each `service:user:port:name`:
1. Read current version (run a throwaway copy of the binary with `--version`-equivalent, or parse the startup log).
2. **Resolve the exact BDS zip**: probe `https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server-<v>.zip` with a HEAD for the candidate(s) matching the target marketing version (e.g. client 1.26.40xx → try `1.26.40.NN`); pick the first that returns 200. If none exists yet → **abort that server with a clear message** (don't half-update). Download once to a repo-local/temp path, reuse across servers.
3. **Backup** `worlds/` + `server.properties` + `permissions.json` + `allowlist.json`/`whitelist.json` to `/home/<user>/worlds_backup_<date>/` (run as the server's user; **a per-server user's home may be mode 0700 → run file ops via `sudo -u <user> bash -c '…'`**, not `cd` as the login user).
4. `systemctl stop <service>` (clean; the unit's ExecStop sends `stop`).
5. `unzip -o` the BDS over the install **EXCLUDING** `server.properties permissions.json allowlist.json whitelist.json worlds/*` (and don't clobber `start_server.sh`, not in the zip).
6. `systemctl start <service>`; verify the startup log shows the new `Version:` + `Server started`.
7. **Never touch `mcfabric`/Java.** Emit `RESULT server=<name> old=<v> new=<v> status=up|fail` per server.

### 5. `scripts/host-copy-from-vm.sh` — FIX the 3 silent-fail bugs (runs on game)

The 2026-06-20 failure shipped the OLD exe and "succeeded." Root causes + required fixes:
1. **Stale staging** — `C:\Users\<user>\minecraft` was never cleaned (step-6 cleanup silently failed), so robocopy's size-poll saw an already-stable OLD build. **FIX: delete the staging dir FIRST**, before robocopy, so the poll reflects the real copy.
2. **Async false-complete** — `Invoke-CommandInDesktopPackage` runs robocopy asynchronously; the size-stability poll declared done in ~15s against stale data. **FIX:** after clean-first, poll for *growth then stability*, require a minimum elapsed time, and **verify the staged file count + that the exe is present and non-trivial in staging before proceeding** (not just "size stable").
3. **exe-decrypt to wrong path** — the decrypt wrote to `C:\Users\<user>\Minecraft.Windows.decrypted.exe` then copied; the intermediate didn't land where expected. **FIX: decrypt directly into staging** — `Invoke-CommandInDesktopPackage … cmd /C copy /Y "<InstallLocation>\Minecraft.Windows.exe" "<VM_STAGING>\Minecraft.Windows.exe"`.
4. Before SCP, **verify the staged exe size** matches the VM's InstallLocation exe (catch the silent stale-binary). Keep `set -euo pipefail`. Preserve the existing arg interface (`<windows-user> <vm-ip>`, `DEST_DIR` env). Parameterize the package family via env (default the current value).

### 6. `scripts/setup.sh` — FIX (runs on game/katana)

1. **Move `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` to the TOP**, before any `cd` (currently computed at step 7 after step 1's `cd "$WORK_DIR"` → relative invocation aborts under `set -e`). Use `$SCRIPT_DIR` for all `stubs/` references.
2. **Add a GameConfigHelper install step**: build `stubs/gameconfighelper/` (or use its prebuilt `GameConfigHelper.dll`) and copy to `$GAME_DIR/GameConfigHelper.dll` (the game imports it; it was a manual carry-forward before).
3. Keep the existing `xgameruntime.dll.threading` presence check/warning (carry-forward is handled by `game-update.sh`). Don't otherwise rewrite working steps. Stay idempotent.

### `scripts/update.sh` (the old GDK-Proton one)

**Deprecate**: replace its body with a short notice pointing at `update-bedrock.sh` (the WineGDK one-command flow) — or `git rm` it. It targets dead paths (`~/.steam/.../compatibilitytools.d`, `~/Games/MinecraftBedrock`) and must not be confused with the new flow.

---

## Known follow-up (document, do not implement here)

The 396 KB `stubs/gameinput/dwmapi.dll` mouse-click-hook proxy (commit dc196a3) **page-faults under 26.31's new pointer-input API** (`Microsoft.UI.Input.dll` absent, `GetPointerType` stubbed). The launcher therefore uses **Wine builtin dwmapi** (`dwmapi=b`) — renders + plays fine, but the menu mouse-click hook is inactive (keyboard/controller always work; mouse may need the ~5s gate wait). Rebuilding the hook for the new input API is a separate task. README "Known Limitations" notes this.

## Failure philosophy

Fail loud, fail safe: backups before every overwrite; version re-verified after every copy; halt-and-report on a failed smoke-check rather than pushing a broken build to katana or declaring success; `mcfabric` and world saves are never touched destructively.
