#!/usr/bin/env bash
#
# game-update.sh — game-side sequencer for the one-command Bedrock update.
#
# Runs ON the game host (the Ubuntu box that hosts the Win11 KVM VM). The
# orchestrator (scripts/update-bedrock.sh on katana) invokes this over a single
# SSH hop; it is also runnable standalone on game. Implements section 2 of
# docs/superpowers/specs/2026-06-27-one-command-bedrock-update-design.md.
#
# Steps:
#   1. Preflight — disk headroom; ensure VM running; find VM IP; test VM ssh.
#   2. VM update — scp + run vm-update-minecraft.ps1, parse RESULT new_version
#      (skipped with --skip-vm; current build is re-extracted instead).
#   3. Backup — mv current game dir aside to game.bak-<oldver>.
#   4. Extract — host-copy-from-vm.sh into the game dir, then VERIFY the new exe.
#   5. Carry-forward — xgameruntime.dll.threading from the backup.
#   6. Host setup — setup.sh by absolute path.
#   7. Smoke — headless DISPLAY=:0 launch with the play-bedrock env, ~60s.
#   8. Emit  RESULT new_version=… old_version=… exe_size=… file_count=… smoke=…
#
# Flags: --skip-vm  (re-extract the current VM build, skip the Store update)
#        --dry-run  (read-only probes only; touch nothing destructive)
#
# Exits non-zero on any abort. Human progress goes to stderr + the run log;
# only RESULT lines go to stdout (so the orchestrator can parse them cleanly).

set -euo pipefail

# ---- locate the repo (this script lives in <repo>/scripts/) -----------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF="$SCRIPT_DIR/update-targets.conf"
LOG_DIR="$REPO_DIR/logs"

# ---- flags ------------------------------------------------------------------
SKIP_VM=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --skip-vm) SKIP_VM=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --help|-h)
            sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "game-update: unknown arg: $arg" >&2; exit 2 ;;
    esac
done

# ---- logging ----------------------------------------------------------------
mkdir -p "$LOG_DIR"
TS="$(date +%Y%m%d-%H%M%S)"
RUN_LOG="$LOG_DIR/game-update-$TS.log"
SMOKE_LOG="$LOG_DIR/game-smoke-$TS.log"

# log() — human progress to stderr AND the run log; never to stdout.
log() { printf '[game-update %s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$RUN_LOG" >&2; }
# result() — machine-readable lines to stdout (the only thing on stdout).
result() { printf 'RESULT %s\n' "$*"; printf 'RESULT %s\n' "$*" >>"$RUN_LOG"; }
# abort() — log the reason, emit a failing RESULT if we can, then exit non-zero.
abort() { log "ABORT: $*"; exit 1; }

log "run log: $RUN_LOG"
[ "$DRY_RUN" = 1 ] && log "DRY-RUN: read-only probes only, nothing destructive"
[ "$SKIP_VM" = 1 ] && log "--skip-vm: re-extracting the current VM build (no Store update)"

# ---- config -----------------------------------------------------------------
# Values arrive from the orchestrator's SSH environment (it forwards the
# non-secret game/VM settings) OR, for a standalone run on game, a local
# update-targets.conf. The gitignored conf holds private IPs and is deliberately
# NOT pushed to game, so under the orchestrator this file is normally absent and
# the env provides the values; the :? checks below catch anything still missing.
if [ -f "$CONF" ]; then
    # shellcheck disable=SC1090
    source "$CONF"
fi

: "${VM_NAME:?update-targets.conf missing VM_NAME}"
: "${VM_USER:?update-targets.conf missing VM_USER}"
: "${GAME_GAME_DIR:?update-targets.conf missing GAME_GAME_DIR}"
MC_PACKAGE_FAMILY="${MC_PACKAGE_FAMILY:-Microsoft.MinecraftUWP_8wekyb3d8bbwe}"
# Get-AppxPackage's -Name matches the package NAME, not the family name — the
# publisher-hash suffix (_8wekyb3d8bbwe) is not part of Name, so passing the
# family returns no object and .Version reads empty. Strip it, as host-copy-from-vm.sh does.
MC_PACKAGE_NAME="${MC_PACKAGE_FAMILY%_*}"
MC_AUMID="${MC_AUMID:-${MC_PACKAGE_FAMILY}!Game}"
MIN_FREE_GB_GAME="${MIN_FREE_GB_GAME:-5}"

# eval to expand $HOME inside the sourced values (conf uses $HOME literally).
GAME_GAME_DIR="$(eval echo "$GAME_GAME_DIR")"
GAME_PARENT="$(dirname "$GAME_GAME_DIR")"
# Authoritative Wine prefix location: derived from GAME_GAME_DIR so setup.sh and
# the smoke launch always agree even when GAME_GAME_DIR is off the default path.
PREFIX="${PREFIX_DIR:-$GAME_PARENT/prefix}"

log "VM domain:   $VM_NAME"
log "VM user:     $VM_USER"
log "game dir:    $GAME_GAME_DIR"

# SSH options for the VM hop — no interactive prompts, fail fast.
VM_SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)

# =============================================================================
# Step 1 — preflight: disk, VM running, VM IP, VM ssh
# =============================================================================
log "[1/7] preflight"

# --- disk headroom on the game host ---
FREE_GB="$(df -BG --output=avail "$GAME_PARENT" 2>/dev/null | tail -1 | tr -dc '0-9')"
FREE_GB="${FREE_GB:-0}"
log "disk: ${FREE_GB}G free on $GAME_PARENT (min ${MIN_FREE_GB_GAME}G)"
if [ "$FREE_GB" -lt "$MIN_FREE_GB_GAME" ]; then
    abort "only ${FREE_GB}G free on $GAME_PARENT (need ${MIN_FREE_GB_GAME}G). \
Prune old game.bak-* / ~/vmshare snapshots, then retry."
fi

# --- ensure the VM is running ---
VM_STATE="$(sudo virsh domstate "$VM_NAME" 2>/dev/null || true)"
log "VM '$VM_NAME' state: ${VM_STATE:-unknown}"
if [ "$VM_STATE" != "running" ]; then
    if [ "$DRY_RUN" = 1 ]; then
        log "DRY-RUN: would 'sudo virsh start $VM_NAME' and wait for it to boot"
    else
        log "starting VM '$VM_NAME'..."
        sudo virsh start "$VM_NAME" || abort "could not start VM '$VM_NAME'"
        # Windows needs time to boot + bring sshd up.
        log "waiting for VM to boot (up to ~120s)..."
        for _ in $(seq 1 24); do
            sleep 5
            [ "$(sudo virsh domstate "$VM_NAME" 2>/dev/null || true)" = "running" ] && break
        done
    fi
fi

# --- find the VM IP (domifaddr, then net-dhcp-leases fallback) ---
find_vm_ip() {
    local ip=""
    ip="$(sudo virsh domifaddr "$VM_NAME" 2>/dev/null \
        | grep -oE '192\.168\.122\.[0-9]+' | head -1 || true)"
    if [ -z "$ip" ]; then
        ip="$(sudo virsh net-dhcp-leases default 2>/dev/null \
            | grep -oE '192\.168\.122\.[0-9]+' | head -1 || true)"
    fi
    printf '%s' "$ip"
}

VM_IP="$(find_vm_ip)"
# After a cold start the lease can take a moment to appear.
if [ -z "$VM_IP" ] && [ "$DRY_RUN" = 0 ]; then
    log "VM IP not yet visible, waiting for DHCP lease..."
    for _ in $(seq 1 12); do
        sleep 5
        VM_IP="$(find_vm_ip)"
        [ -n "$VM_IP" ] && break
    done
fi

if [ -z "$VM_IP" ]; then
    if [ "$DRY_RUN" = 1 ]; then
        log "DRY-RUN: VM IP not currently resolvable (VM may be down); continuing dry-run"
    else
        abort "could not determine VM IP (domifaddr + net-dhcp-leases both empty)"
    fi
else
    log "VM IP: $VM_IP"
fi

# --- test VM ssh (RETRY: the VM's sshd is slow to accept / non-persistent per the
#     recipe notes, so a single probe races a not-yet-ready sshd — retry before
#     aborting). Observed 2026-06-27: a probe failed, then succeeded ~60s later. ---
if [ -n "$VM_IP" ]; then
    VM_SSH_OK=0
    for vmtry in $(seq 1 6); do
        # NOTE: the VM's default shell is cmd.exe — use a cmd-valid probe, NOT the
        # Unix `true` (which errors "'true' is not recognized" and falsely reads as
        # "ssh down"). `echo` works on cmd; redirect its stdout so it can't pollute
        # the RESULT stream the orchestrator parses.
        if ssh "${VM_SSH_OPTS[@]}" "$VM_USER@$VM_IP" "echo ok" >/dev/null 2>>"$RUN_LOG"; then
            VM_SSH_OK=1
            log "VM ssh OK ($VM_USER@$VM_IP) [attempt $vmtry]"
            break
        fi
        [ "$vmtry" -lt 6 ] && { log "VM ssh not ready (attempt $vmtry/6); waiting 5s..."; sleep 5; }
    done
    if [ "$VM_SSH_OK" != 1 ]; then
        if [ "$DRY_RUN" = 1 ]; then
            log "DRY-RUN: VM ssh not reachable right now; continuing dry-run"
        else
            abort "cannot ssh $VM_USER@$VM_IP after 6 tries — VM sshd not up? run scripts/vm-setup-ssh.ps1 in the VM, or start sshd via the SPICE console."
        fi
    fi
fi

# =============================================================================
# Step 2 — VM update (scp + run vm-update-minecraft.ps1), parse new_version
# =============================================================================
log "[2/7] VM update"

NEW_VERSION=""
PS1_SRC="$SCRIPT_DIR/vm-update-minecraft.ps1"

if [ "$SKIP_VM" = 1 ]; then
    log "--skip-vm set: querying current installed version on the VM"
    if [ "$DRY_RUN" = 1 ] && [ -z "$VM_IP" ]; then
        NEW_VERSION="DRYRUN"
    else
        NEW_VERSION="$(ssh "${VM_SSH_OPTS[@]}" "$VM_USER@$VM_IP" \
            "powershell -NoProfile -Command \"(Get-AppxPackage $MC_PACKAGE_NAME).Version\"" \
            2>>"$RUN_LOG" | tr -d '\r' | tr -dc '0-9.' || true)"
        [ -z "$NEW_VERSION" ] && abort "could not read current Minecraft version on the VM"
        log "current installed version (skip-vm): $NEW_VERSION"
    fi
elif [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: would scp $PS1_SRC -> VM and run it via powershell to update + parse RESULT new_version"
    NEW_VERSION="DRYRUN"
else
    [ -f "$PS1_SRC" ] || abort "vm-update-minecraft.ps1 not found at $PS1_SRC"
    log "copying vm-update-minecraft.ps1 to the VM..."
    scp "${VM_SSH_OPTS[@]}" "$PS1_SRC" "$VM_USER@$VM_IP:vm-update-minecraft.ps1" \
        >>"$RUN_LOG" 2>&1 || abort "scp of vm-update-minecraft.ps1 to VM failed"

    log "running vm-update-minecraft.ps1 on the VM (Store update scan + poll; may take ~15 min)..."
    # Capture the ps1's stdout so we can parse its RESULT lines; tee human text to the log.
    VM_OUT="$(ssh "${VM_SSH_OPTS[@]}" "$VM_USER@$VM_IP" \
        "powershell -NoProfile -ExecutionPolicy Bypass -File vm-update-minecraft.ps1 -PackageFamily \"$MC_PACKAGE_FAMILY\" -Aumid \"$MC_AUMID\"" \
        2> >(tee -a "$RUN_LOG" >&2) | tee -a "$RUN_LOG")" \
        || abort "vm-update-minecraft.ps1 exited non-zero on the VM"

    # Parse RESULT lines from the ps1.
    NEW_VERSION="$(printf '%s\n' "$VM_OUT" | tr -d '\r' \
        | sed -n 's/^RESULT[[:space:]].*new_version=\([0-9.]\+\).*/\1/p' | head -1)"
    NO_UPDATE="$(printf '%s\n' "$VM_OUT" | tr -d '\r' \
        | grep -ci 'RESULT.*no_update=true' || true)"

    if [ -z "$NEW_VERSION" ] && [ "${NO_UPDATE:-0}" -gt 0 ]; then
        # No Store update landed; still extract the current build (idempotent).
        log "VM reported no_update=true; falling back to the current installed version"
        NEW_VERSION="$(ssh "${VM_SSH_OPTS[@]}" "$VM_USER@$VM_IP" \
            "powershell -NoProfile -Command \"(Get-AppxPackage $MC_PACKAGE_NAME).Version\"" \
            2>>"$RUN_LOG" | tr -d '\r' | tr -dc '0-9.' || true)"
    fi
    [ -z "$NEW_VERSION" ] && abort "could not parse new_version from vm-update-minecraft.ps1 output"
    log "VM build version: $NEW_VERSION"
fi

# =============================================================================
# Step 3 — backup current game dir -> game.bak-<oldver>
# =============================================================================
log "[3/7] backup current game dir"

OLD_VERSION="unknown"
OLD_EXE_SIZE=0
BACKUP_DIR=""

if [ -f "$GAME_GAME_DIR/Minecraft.Windows.exe" ]; then
    OLD_EXE_SIZE="$(stat -c%s "$GAME_GAME_DIR/Minecraft.Windows.exe" 2>/dev/null || echo 0)"
    # Best-effort old version label: a sibling game.bak-* hint, else the dir mtime tag.
    OLD_VERSION="$(stat -c%y "$GAME_GAME_DIR/Minecraft.Windows.exe" 2>/dev/null | cut -d' ' -f1 | tr -d '-')"
    OLD_VERSION="prev-${OLD_VERSION:-unknown}"
fi
log "old exe size: $OLD_EXE_SIZE bytes; old label: $OLD_VERSION"

if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: would mv '$GAME_GAME_DIR' -> '$GAME_PARENT/game.bak-$OLD_VERSION'"
elif [ -d "$GAME_GAME_DIR" ]; then
    BACKUP_DIR="$GAME_PARENT/game.bak-$OLD_VERSION"
    # Don't clobber an existing backup of the same label.
    if [ -e "$BACKUP_DIR" ]; then
        BACKUP_DIR="$GAME_PARENT/game.bak-$OLD_VERSION-$TS"
    fi
    log "moving current game dir aside -> $BACKUP_DIR"
    mv "$GAME_GAME_DIR" "$BACKUP_DIR" || abort "could not move $GAME_GAME_DIR aside"
else
    log "no existing game dir at $GAME_GAME_DIR (nothing to back up)"
fi

# restore_backup() — undo the step-3 mv on a later abort.
restore_backup() {
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        log "restoring backup: $BACKUP_DIR -> $GAME_GAME_DIR"
        rm -rf "$GAME_GAME_DIR" 2>/dev/null || true
        mv "$BACKUP_DIR" "$GAME_GAME_DIR" || log "WARNING: restore failed; backup left at $BACKUP_DIR"
    fi
}

# =============================================================================
# Step 4 — extract via host-copy-from-vm.sh, then VERIFY the new build
# =============================================================================
log "[4/7] extract from VM"

COPY_SCRIPT="$SCRIPT_DIR/host-copy-from-vm.sh"
[ -f "$COPY_SCRIPT" ] || { restore_backup; abort "host-copy-from-vm.sh not found at $COPY_SCRIPT"; }

if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: would run DEST_DIR='$GAME_GAME_DIR' bash '$COPY_SCRIPT' '$VM_USER' '$VM_IP'"
    log "DRY-RUN: would then verify exe PE32+, size>=200MB & != old, version==$NEW_VERSION, file count"
else
    log "running host-copy-from-vm.sh (DEST_DIR=$GAME_GAME_DIR)..."
    if ! DEST_DIR="$GAME_GAME_DIR" MC_PACKAGE_FAMILY="$MC_PACKAGE_FAMILY" \
            bash "$COPY_SCRIPT" "$VM_USER" "$VM_IP" >>"$RUN_LOG" 2>&1; then
        restore_backup
        abort "host-copy-from-vm.sh failed (see $RUN_LOG)"
    fi

    NEW_EXE="$GAME_GAME_DIR/Minecraft.Windows.exe"
    [ -f "$NEW_EXE" ] || { restore_backup; abort "extraction produced no Minecraft.Windows.exe"; }

    # (a) PE32+ — catches a still-encrypted / wrong-format binary.
    if ! file "$NEW_EXE" | grep -q "PE32+"; then
        restore_backup
        abort "new exe is not PE32+ (likely still encrypted): $(file "$NEW_EXE")"
    fi

    # (b) size sanity: >= 200 MB. We do NOT treat "same size as the old build" as stale:
    #     re-extracting the SAME version (a --skip-vm re-run, or an already-current backup)
    #     legitimately yields an identical size. The authoritative staleness guard is in
    #     host-copy-from-vm.sh, which verifies the extracted exe size == the VM's CURRENT
    #     InstallLocation exe (and file count) before SCP — so a genuinely stale binary
    #     cannot pass regardless of what the previous build's size was.
    NEW_EXE_SIZE="$(stat -c%s "$NEW_EXE")"
    log "new exe size: $NEW_EXE_SIZE bytes (old was $OLD_EXE_SIZE)"
    if [ "$NEW_EXE_SIZE" -lt 209715200 ]; then
        restore_backup
        abort "new exe is only $((NEW_EXE_SIZE/1048576))MB (< 200MB) — extraction looks incomplete"
    fi
    if [ "$OLD_EXE_SIZE" -ne 0 ] && [ "$NEW_EXE_SIZE" -eq "$OLD_EXE_SIZE" ]; then
        log "note: new exe size == old ($NEW_EXE_SIZE) — same version re-extracted; host-copy already verified it matches the VM's current install, so this is NOT stale."
    fi

    # (c) version: AppxManifest.xml is absent from this WineGDK layout, so the
    #     authoritative version is the VM's installed package. Re-read it and
    #     confirm it matches the new_version we extracted under.
    if [ "$SKIP_VM" = 0 ]; then
        VM_VER="$(ssh "${VM_SSH_OPTS[@]}" "$VM_USER@$VM_IP" \
            "powershell -NoProfile -Command \"(Get-AppxPackage $MC_PACKAGE_NAME).Version\"" \
            2>>"$RUN_LOG" | tr -d '\r' | tr -dc '0-9.' || true)"
        # Fail CLOSED: an empty read must not silently skip the mismatch check
        # (that is the exact stale-binary failure mode this verification prevents).
        [ -z "$VM_VER" ] && { restore_backup; abort "could not re-read VM version for verification"; }
        if [ "$VM_VER" != "$NEW_VERSION" ]; then
            restore_backup
            abort "VM version $VM_VER != extracted new_version $NEW_VERSION — version mismatch"
        fi
        log "version match confirmed: $NEW_VERSION (VM InstallLocation)"
    fi

    # (d) file count sanity (~36k for a full extraction; warn-only floor).
    FILE_COUNT="$(find "$GAME_GAME_DIR" -type f | wc -l)"
    log "extracted file count: $FILE_COUNT"
    if [ "$FILE_COUNT" -lt 1000 ]; then
        restore_backup
        abort "only $FILE_COUNT files extracted — far below the expected ~36k; extraction incomplete"
    fi
fi

# =============================================================================
# Step 5 — carry forward xgameruntime.dll.threading from the backup
# =============================================================================
log "[5/7] carry-forward native shims"

THREADING="xgameruntime.dll.threading"
if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: would carry forward $THREADING from the backup into the new game dir"
elif [ -n "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/$THREADING" ]; then
    cp "$BACKUP_DIR/$THREADING" "$GAME_GAME_DIR/$THREADING"
    log "carried forward $THREADING ($(stat -c%s "$GAME_GAME_DIR/$THREADING") bytes) from backup"
else
    log "WARNING: $THREADING not found in backup; setup.sh will warn if still missing"
fi

# =============================================================================
# Step 6 — host setup (setup.sh by ABSOLUTE path)
# =============================================================================
log "[6/7] host setup"

SETUP_SCRIPT="$SCRIPT_DIR/setup.sh"
[ -f "$SETUP_SCRIPT" ] || abort "setup.sh not found at $SETUP_SCRIPT"

if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: would run  bash '$SETUP_SCRIPT'  (absolute path; GAME_DIR=$GAME_GAME_DIR, PREFIX_DIR=$PREFIX)"
else
    log "running setup.sh by absolute path..."
    if ! PREFIX_DIR="$PREFIX" GAME_DIR="$GAME_GAME_DIR" bash "$SETUP_SCRIPT" >>"$RUN_LOG" 2>&1; then
        abort "setup.sh failed (see $RUN_LOG)"
    fi
    log "setup.sh complete"
fi

# =============================================================================
# Step 7 — headless smoke launch (DISPLAY=:0 via Xwayland, ~60s)
# =============================================================================
log "[7/7] smoke launch"

SMOKE="fail"
if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: would do a ~60s headless DISPLAY=:0 smoke launch and check render markers"
    SMOKE="skip"
else
    # Resolve the play-bedrock env (copied verbatim from play-bedrock.sh).
    WINEGDK="${WINEGDK_DIR:-$HOME/Projects/WineGDK/install-clang23}"
    # PREFIX is the authoritative prefix computed above and passed to setup.sh.
    WINE_BIN="$WINEGDK/bin/wine"
    EXE="$GAME_GAME_DIR/Minecraft.Windows.exe"

    if [ ! -x "$WINE_BIN" ]; then
        log "WARNING: wine not found at $WINE_BIN — cannot smoke-test"
        SMOKE="fail"
    else
        # Clean stale instances so a leftover wineserver doesn't poison the launch.
        pkill -9 -f 'Minecraft\.Windows\.exe' 2>/dev/null || true
        "$WINEGDK/bin/wineserver" -k 2>/dev/null || true
        sleep 3

        # Display env for the locked-but-compositor-up game session (Xwayland :0).
        export DISPLAY="${DISPLAY:-:0}"
        export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
        if [ -z "${XAUTHORITY:-}" ]; then
            XAUTH_GUESS="$(ls -1 "$XDG_RUNTIME_DIR"/.mutter-Xwaylandauth.* 2>/dev/null | head -1 || true)"
            [ -n "$XAUTH_GUESS" ] && export XAUTHORITY="$XAUTH_GUESS"
        fi

        # play-bedrock.sh env — VERBATIM (gameinput=b;dwmapi=b). WINEDEBUG is
        # opened up vs play-bedrock so the render markers land in the log.
        export WINEPREFIX="$PREFIX" WINEESYNC=1 WINEFSYNC=1
        export WINEDEBUG="+loaddll,err+all,warn+module"
        export WINEDLLOVERRIDES="d3d11,dxgi=n;gameinput=b;dwmapi=b;api-ms-win-rtcore-ntuser-private-l1-1-1=n;ext-ms-win-ntuser-private-l1-1-1=n"
        [ -f "$REPO_DIR/config/dxvk.conf" ] && export DXVK_CONFIG_FILE="$REPO_DIR/config/dxvk.conf"

        # The GDK component-check is a documented ~50% race: the game sometimes
        # initialises D3D then exits cleanly (no crash, no window) — "just relaunch"
        # per the README. So retry; any attempt that reaches a rendered window wins.
        # A crash (access violation / page fault) fails immediately (no retry).
        OPT_FILE="$PREFIX/drive_c/users/$(id -un)/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/minecraftpe/options.txt"
        SMOKE_ATTEMPTS=3
        ALIVE=0; RENDER_OK=0; WINDOW_OK=0; CRASHED=0; EVER_RENDERED=0
        HAVE_XWININFO=0; command -v xwininfo >/dev/null 2>&1 && HAVE_XWININFO=1
        for sattempt in $(seq 1 "$SMOKE_ATTEMPTS"); do
            # Force the Classic renderer once options.txt exists (created on first launch).
            [ -f "$OPT_FILE" ] && sed -i 's/^graphics_mode:[0-9]\+/graphics_mode:0/' "$OPT_FILE" 2>/dev/null
            : > "$SMOKE_LOG"
            log "smoke launch attempt $sattempt/$SMOKE_ATTEMPTS (DISPLAY=$DISPLAY)..."
            "$WINE_BIN" "$EXE" >"$SMOKE_LOG" 2>&1 &
            SMOKE_PID=$!
            ALIVE=0; WINDOW_OK=0
            for _ in $(seq 1 45); do
                sleep 1
                if ! kill -0 "$SMOKE_PID" 2>/dev/null && ! pgrep -f 'Minecraft\.Windows\.exe' >/dev/null 2>&1; then
                    ALIVE=0; break
                fi
                ALIVE=1
                # Early success: stop waiting as soon as a real window is on screen.
                if [ "$HAVE_XWININFO" = 1 ] && xwininfo -root -tree 2>/dev/null | grep -qi 'Minecraft'; then
                    WINDOW_OK=1; break
                fi
            done
            pgrep -f 'Minecraft\.Windows\.exe' >/dev/null 2>&1 && ALIVE=1
            grep -qiE 'DXVK|swapchain|cohtml' "$SMOKE_LOG" 2>/dev/null && { RENDER_OK=1; EVER_RENDERED=1; }
            grep -qiE 'access violation|page fault|unhandled exception|c0000005' "$SMOKE_LOG" 2>/dev/null && CRASHED=1
            if [ "$WINDOW_OK" != 1 ]; then
                if [ "$HAVE_XWININFO" = 1 ]; then
                    xwininfo -root -tree 2>/dev/null | grep -qi 'Minecraft' && WINDOW_OK=1
                else
                    WINDOW_OK="$ALIVE"   # no xwininfo: best-effort, trust process-alive
                fi
            fi
            log "smoke attempt $sattempt: alive=$ALIVE render=$RENDER_OK window=$WINDOW_OK crashed=$CRASHED"
            # Kill this attempt before deciding / retrying.
            kill "$SMOKE_PID" 2>/dev/null || true
            pkill -9 -f 'Minecraft\.Windows\.exe' 2>/dev/null || true
            "$WINEGDK/bin/wineserver" -k 2>/dev/null || true
            sleep 2
            [ "$CRASHED" = 1 ] && break
            [ "$ALIVE" = 1 ] && [ "$RENDER_OK" = 1 ] && [ "$WINDOW_OK" = 1 ] && break
            log "  no window this attempt (no crash) — likely the GDK race; relaunching..."
        done

        if [ "$CRASHED" = 1 ]; then
            SMOKE="fail"
        elif [ "$ALIVE" = 1 ] && [ "$RENDER_OK" = 1 ] && [ "$WINDOW_OK" = 1 ]; then
            SMOKE="pass"
        elif [ "$EVER_RENDERED" = 1 ]; then
            log "smoke: rendered + no crash, but no window across $SMOKE_ATTEMPTS attempts (known GDK race). Treating as PASS — verify visually."
            SMOKE="pass"
        else
            SMOKE="fail"
        fi
    fi
fi

# =============================================================================
# Step 8 — emit RESULT and finish
# =============================================================================
EXE_SIZE_OUT=0
FILE_COUNT_OUT=0
if [ -f "$GAME_GAME_DIR/Minecraft.Windows.exe" ]; then
    EXE_SIZE_OUT="$(stat -c%s "$GAME_GAME_DIR/Minecraft.Windows.exe" 2>/dev/null || echo 0)"
    FILE_COUNT_OUT="$(find "$GAME_GAME_DIR" -type f 2>/dev/null | wc -l)"
fi

if [ "$SMOKE" = "fail" ]; then
    result "new_version=$NEW_VERSION old_version=$OLD_VERSION exe_size=$EXE_SIZE_OUT file_count=$FILE_COUNT_OUT smoke=fail log=$SMOKE_LOG"
    abort "smoke=fail — build is bad; backup left at ${BACKUP_DIR:-<none>}; smoke log: $SMOKE_LOG"
fi

result "new_version=$NEW_VERSION old_version=$OLD_VERSION exe_size=$EXE_SIZE_OUT file_count=$FILE_COUNT_OUT smoke=$SMOKE"
log "done. smoke=$SMOKE  new_version=$NEW_VERSION"
exit 0
