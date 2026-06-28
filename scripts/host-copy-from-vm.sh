#!/usr/bin/env bash
# Copy Minecraft Bedrock files from a Windows 11 VM via SSH (runs ON the game host).
# Usage: ./host-copy-from-vm.sh <windows-user> <vm-ip>
#   env: DEST_DIR            — host dir to receive the extraction (default below)
#        MC_PACKAGE_FAMILY   — UWP package family name (default Microsoft.MinecraftUWP_8wekyb3d8bbwe)
#
# This script SSHs into the VM (one hop game->VM), runs extraction inside the Xbox
# package context (Invoke-CommandInDesktopPackage) so the at-rest-encrypted files are
# transparently decrypted, decrypts the DRM-protected primary exe directly into the
# staging dir, then SCPs the staged tree to the host.
#
# Contract: docs/superpowers/specs/2026-06-27-one-command-bedrock-update-design.md §5.
# This rewrite fixes the 2026-06-20 "silent stale-binary" failure (cirrus.md): it
#   (1) deletes the VM staging dir FIRST so the size-poll reflects the real copy;
#   (2) waits for growth-then-stability with a minimum elapsed time, and verifies the
#       staged file count + that Minecraft.Windows.exe is present and non-trivial;
#   (3) decrypts the exe DIRECTLY into staging (no C:\Users root intermediate);
#   (4) verifies the staged exe size == the VM InstallLocation exe size before SCP,
#       aborting loudly otherwise.
#
# Prerequisites:
#   - SSH access to the VM with key auth (run vm-setup-ssh.ps1 first)
#   - Minecraft Bedrock installed via Xbox App and launched at least once

set -euo pipefail

WIN_USER="${1:?Usage: $0 <windows-user> <vm-ip>}"
VM_IP="${2:?Usage: $0 <windows-user> <vm-ip>}"
DEST_DIR="${DEST_DIR:-$HOME/vmshare/minecraft-bedrock}"
MC_PACKAGE_FAMILY="${MC_PACKAGE_FAMILY:-Microsoft.MinecraftUWP_8wekyb3d8bbwe}"
SSH_TARGET="$WIN_USER@$VM_IP"
VM_STAGING="C:/Users/$WIN_USER/minecraft"
# Backslash form of the staging path for cmd.exe / Invoke-CommandInDesktopPackage args.
VM_STAGING_BS="C:\\Users\\$WIN_USER\\minecraft"

# Stability/poll tuning. The 2026-06-20 silent fail declared "done" in ~15s against
# stale data, so we require both a minimum elapsed wall-clock time AND that the size
# stopped growing for several consecutive polls before trusting the result.
POLL_INTERVAL=5          # seconds between size polls
STABLE_REQUIRED=4        # consecutive unchanged polls => "stable"
MIN_ELAPSED=60           # do not accept "complete" before this many seconds elapsed
MAX_ELAPSED=1800         # hard ceiling so a stuck copy aborts instead of hanging forever
MIN_STAGING_BYTES=1000000000   # >= ~1 GB; a real extraction is ~1.6 GB, an empty/partial one is far less
MIN_EXE_BYTES=200000000        # >= ~200 MB; the decrypted exe is ~290 MB

echo "=== Copying Minecraft from Windows VM ===" >&2
echo "VM:      $SSH_TARGET" >&2
echo "Dest:    $DEST_DIR" >&2
echo "Package: $MC_PACKAGE_FAMILY" >&2
echo "" >&2

# --- [1/7] SSH reachability -------------------------------------------------
echo "[1/7] Testing SSH connection..." >&2
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$SSH_TARGET" "echo SSH_OK" >/dev/null 2>&1; then
    echo "ERROR: Cannot SSH into $SSH_TARGET" >&2
    echo "Make sure:" >&2
    echo "  1. The VM is running" >&2
    echo "  2. OpenSSH is enabled (run vm-setup-ssh.ps1 in the VM)" >&2
    echo "  3. SSH key auth is set up (~/.ssh/authorized_keys on VM)" >&2
    echo "  4. The IP is correct (check: virsh domifaddr <vm-name>)" >&2
    exit 1
fi
echo "  Connected." >&2

# --- [2/7] Locate the install & capture source truth ------------------------
# We read the InstallLocation, its decrypted exe size, and its file count UP FRONT.
# These are the ground-truth values every later verification compares against, so a
# stale/partial staging copy can never masquerade as success.
echo "[2/7] Locating Minecraft install on the VM..." >&2
INSTALL_DIR=$(ssh "$SSH_TARGET" "powershell -NoProfile -Command \"(Get-AppxPackage ${MC_PACKAGE_FAMILY%_*} | Where-Object { \$_.IsFramework -eq \$false } | Select-Object -First 1).InstallLocation\"" 2>/dev/null | tr -d '\r')
if [ -z "$INSTALL_DIR" ]; then
    echo "ERROR: Minecraft Bedrock package not found on the VM (family $MC_PACKAGE_FAMILY)." >&2
    echo "Install it from the Xbox App and launch it at least once." >&2
    exit 1
fi
# Guard against multiple installed packages (release + Preview/Beta) yielding a
# multi-line InstallLocation that would garble every downstream path.
if [ "$(printf '%s\n' "$INSTALL_DIR" | wc -l | tr -d ' ')" -ne 1 ]; then
    echo "ERROR: InstallLocation resolved to multiple lines (more than one Minecraft package installed?):" >&2
    printf '%s\n' "$INSTALL_DIR" >&2
    echo "Refusing to proceed with an ambiguous install path." >&2
    exit 1
fi
echo "  InstallLocation: $INSTALL_DIR" >&2

# Source exe size (the InstallLocation exe is encrypted at rest but Get-Item reports
# its true on-disk length; the decrypted copy must match this byte-for-byte).
SRC_EXE_SIZE=$(ssh "$SSH_TARGET" "powershell -NoProfile -Command \"(Get-Item '$INSTALL_DIR\\Minecraft.Windows.exe').Length\"" 2>/dev/null | tr -d '\r ')
if ! [[ "$SRC_EXE_SIZE" =~ ^[0-9]+$ ]] || [ "$SRC_EXE_SIZE" -lt "$MIN_EXE_BYTES" ]; then
    echo "ERROR: Could not read a sane InstallLocation exe size (got '${SRC_EXE_SIZE:-<empty>}')." >&2
    echo "Expected >= $MIN_EXE_BYTES bytes. Aborting before any copy." >&2
    exit 1
fi

# Source file count (robocopy from package context copies everything EXCEPT the DRM
# exe, which it skips; we decrypt that separately, so the final staged count should
# equal the InstallLocation count).
SRC_FILE_COUNT=$(ssh "$SSH_TARGET" "powershell -NoProfile -Command \"(Get-ChildItem '$INSTALL_DIR' -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count\"" 2>/dev/null | tr -d '\r ')
if ! [[ "$SRC_FILE_COUNT" =~ ^[0-9]+$ ]] || [ "$SRC_FILE_COUNT" -lt 1000 ]; then
    echo "ERROR: Could not read a sane InstallLocation file count (got '${SRC_FILE_COUNT:-<empty>}')." >&2
    exit 1
fi
echo "  Source exe size:   $SRC_EXE_SIZE bytes" >&2
echo "  Source file count: $SRC_FILE_COUNT files" >&2

# --- [3/7] staging is cleaned by robocopy /MIR (next step) ------------------
# The 2026-06-20 fail shipped a STALE build because the staging dir held an old copy.
# The obvious fix — Remove-Item the staging first — does NOT work: the tree was created
# INSIDE the package sandbox (robocopy via Invoke-CommandInDesktopPackage) and carries
# sandbox ACLs that a NORMAL-context Remove-Item cannot delete (observed 2026-06-27:
# 36047 files survived the wipe). Instead, the robocopy below uses /MIR (mirror), which
# runs IN the package context (matching ACLs) and deletes any stale extras while it
# copies — so the staged tree always equals the current install. The post-copy file-
# count and exe-size checks then verify completeness, catching any partial mirror.
echo "[3/7] (staging is mirrored by robocopy /MIR below — no separate normal-context clean)" >&2

# --- [4/7] robocopy inside the package context ------------------------------
# Xbox/MS Store games are encrypted at rest — a plain copy fails with access denied.
# Invoke-CommandInDesktopPackage runs inside the package sandbox where the tree is
# transparently decrypted. robocopy copies every file EXCEPT the DRM-protected primary
# exe (it skips that); the exe is handled by the dedicated decrypt step below.
echo "[4/7] robocopy inside package context (async)..." >&2
# Build the cmd command line in a PowerShell variable using [char]34 (a literal ")
# concatenated around single-quoted path literals. This avoids nested double-quotes
# inside the -Command string (which would terminate it early) AND avoids bash
# command-substituting a bare $([char]34). The only " in the source are the two
# -Command delimiters; cmd's path quotes are produced at PowerShell runtime.
ssh "$SSH_TARGET" "powershell -NoProfile -Command \"\$q=[char]34; \$cl='/C robocopy '+\$q+'$INSTALL_DIR'+\$q+' '+\$q+'$VM_STAGING_BS'+\$q+' /MIR /R:1 /W:1 /NP'; Invoke-CommandInDesktopPackage -PackageFamilyName '$MC_PACKAGE_FAMILY' -AppId 'Game' -Command 'cmd.exe' -Args \$cl\"" >&2

# --- FIX #2: wait for growth-THEN-stability, with a minimum elapsed time ----
echo "  Waiting for robocopy to grow then stabilise (min ${MIN_ELAPSED}s)..." >&2
PREV_SIZE=-1
STABLE=0
SAW_GROWTH=0
ELAPSED=0
CURR_SIZE=0
while :; do
    sleep "$POLL_INTERVAL"
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
    CURR_SIZE=$(ssh "$SSH_TARGET" "powershell -NoProfile -Command \"(Get-ChildItem '$VM_STAGING' -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum\"" 2>/dev/null | tr -d '\r ')
    [[ "$CURR_SIZE" =~ ^[0-9]+$ ]] || CURR_SIZE=0
    CURR_MB=$((CURR_SIZE / 1048576))
    echo "  [${ELAPSED}s] staged: ${CURR_MB} MB (stable ${STABLE}/${STABLE_REQUIRED})" >&2

    # Track that we actually saw the copy grow from empty — guards against declaring an
    # empty/zero staging "stable" forever.
    if [ "$CURR_SIZE" -gt 0 ]; then SAW_GROWTH=1; fi

    if [ "$CURR_SIZE" -eq "$PREV_SIZE" ] && [ "$CURR_SIZE" -gt 0 ]; then
        STABLE=$((STABLE + 1))
    else
        STABLE=0
    fi
    PREV_SIZE="$CURR_SIZE"

    # Accept only when: we saw growth, size held steady long enough, the staged tree is
    # plausibly large, AND the minimum wall-clock elapsed time has passed.
    if [ "$SAW_GROWTH" -eq 1 ] \
        && [ "$STABLE" -ge "$STABLE_REQUIRED" ] \
        && [ "$CURR_SIZE" -ge "$MIN_STAGING_BYTES" ] \
        && [ "$ELAPSED" -ge "$MIN_ELAPSED" ]; then
        echo "  robocopy stable at ${CURR_MB} MB after ${ELAPSED}s." >&2
        break
    fi

    if [ "$ELAPSED" -ge "$MAX_ELAPSED" ]; then
        echo "ERROR: robocopy did not stabilise within ${MAX_ELAPSED}s (last ${CURR_MB} MB)." >&2
        echo "Staging may be incomplete; aborting rather than shipping a partial build." >&2
        exit 1
    fi
done

# Verify the staged file count is sane (exe not yet present, so allow it to be one
# short of the source until the decrypt step fills it in).
STAGE_FILE_COUNT=$(ssh "$SSH_TARGET" "powershell -NoProfile -Command \"(Get-ChildItem '$VM_STAGING' -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count\"" 2>/dev/null | tr -d '\r ')
[[ "$STAGE_FILE_COUNT" =~ ^[0-9]+$ ]] || STAGE_FILE_COUNT=0
echo "  Staged file count: $STAGE_FILE_COUNT (source: $SRC_FILE_COUNT)" >&2
# robocopy skips only the DRM exe, so staging should be within 1 file of the source.
MIN_OK_COUNT=$((SRC_FILE_COUNT - 1))
if [ "$STAGE_FILE_COUNT" -lt "$MIN_OK_COUNT" ]; then
    echo "ERROR: staged file count $STAGE_FILE_COUNT is below source-minus-one ($MIN_OK_COUNT)." >&2
    echo "robocopy did not copy the full tree; aborting." >&2
    exit 1
fi

# --- [5/7] FIX #3: decrypt the exe DIRECTLY into staging --------------------
# The DRM exe is skipped by robocopy. Decrypt it inside the package context straight
# into the staging dir (NOT via a C:\Users root intermediate, which was the path that
# silently missed in 2026-06-20).
echo "[5/7] Decrypting Minecraft.Windows.exe directly into staging..." >&2
# Same [char]34-concatenation pattern as robocopy above (no nested double-quotes).
ssh "$SSH_TARGET" "powershell -NoProfile -Command \"\$q=[char]34; \$cl='/C copy /Y '+\$q+'$INSTALL_DIR\\Minecraft.Windows.exe'+\$q+' '+\$q+'$VM_STAGING_BS\\Minecraft.Windows.exe'+\$q; Invoke-CommandInDesktopPackage -PackageFamilyName '$MC_PACKAGE_FAMILY' -AppId 'Game' -Command 'cmd.exe' -Args \$cl\"" >&2

# Invoke-CommandInDesktopPackage returns before the spawned cmd finishes; poll the
# staged exe until it reaches the expected size (or time out loudly).
echo "  Waiting for the decrypted exe to land in staging..." >&2
EXE_WAIT=0
STAGE_EXE_SIZE=0
while [ "$EXE_WAIT" -lt 120 ]; do
    sleep "$POLL_INTERVAL"
    EXE_WAIT=$((EXE_WAIT + POLL_INTERVAL))
    STAGE_EXE_SIZE=$(ssh "$SSH_TARGET" "powershell -NoProfile -Command \"if (Test-Path '$VM_STAGING/Minecraft.Windows.exe') { (Get-Item '$VM_STAGING/Minecraft.Windows.exe').Length } else { 0 }\"" 2>/dev/null | tr -d '\r ')
    [[ "$STAGE_EXE_SIZE" =~ ^[0-9]+$ ]] || STAGE_EXE_SIZE=0
    echo "  [${EXE_WAIT}s] staged exe: $STAGE_EXE_SIZE bytes" >&2
    if [ "$STAGE_EXE_SIZE" -eq "$SRC_EXE_SIZE" ]; then
        break
    fi
done

# --- FIX #4: verify staged exe size == InstallLocation exe size -------------
if [ "$STAGE_EXE_SIZE" -lt "$MIN_EXE_BYTES" ]; then
    echo "ERROR: staged Minecraft.Windows.exe is missing or too small ($STAGE_EXE_SIZE bytes)." >&2
    echo "The decrypt-into-staging step did not produce a usable exe. Aborting." >&2
    exit 1
fi
if [ "$STAGE_EXE_SIZE" -ne "$SRC_EXE_SIZE" ]; then
    echo "ERROR: staged exe size ($STAGE_EXE_SIZE) != InstallLocation exe size ($SRC_EXE_SIZE)." >&2
    echo "This is the silent stale-binary failure mode. Refusing to SCP a mismatched exe." >&2
    exit 1
fi
echo "  Staged exe size matches source ($STAGE_EXE_SIZE bytes). OK." >&2

# --- [6/7] SCP staging -> host ----------------------------------------------
echo "[6/7] Downloading staged tree to host via SCP..." >&2
mkdir -p "$DEST_DIR"
# Clear any prior contents at the destination so we don't blend old + new files.
# (The caller backs up the live game dir; DEST_DIR here is the extraction target.)
if [ -n "$(ls -A "$DEST_DIR" 2>/dev/null)" ]; then
    echo "  Clearing existing contents of $DEST_DIR..." >&2
    rm -rf -- "${DEST_DIR:?}"/*
fi
scp -rq "$SSH_TARGET:$VM_STAGING/*" "$DEST_DIR/"
echo "  SCP complete." >&2

# --- [7/7] Host-side verification -------------------------------------------
echo "[7/7] Verifying on the host..." >&2
HOST_EXE="$DEST_DIR/Minecraft.Windows.exe"
if [ ! -f "$HOST_EXE" ]; then
    echo "ERROR: $HOST_EXE missing after SCP." >&2
    exit 1
fi
if ! file "$HOST_EXE" | grep -q "PE32+"; then
    echo "ERROR: $HOST_EXE is not a PE32+ executable (still encrypted?)." >&2
    echo "  $(file "$HOST_EXE")" >&2
    exit 1
fi
HOST_EXE_SIZE=$(stat -c%s "$HOST_EXE")
if [ "$HOST_EXE_SIZE" -ne "$SRC_EXE_SIZE" ]; then
    echo "ERROR: host exe size ($HOST_EXE_SIZE) != source exe size ($SRC_EXE_SIZE) after SCP." >&2
    exit 1
fi
HOST_FILE_COUNT=$(find "$DEST_DIR" -type f | wc -l | tr -d ' ')
# Defense-in-depth: the host should hold the SRC-1 staged files plus the decrypted
# exe == SRC. A short tree means the SCP landed a partial copy; abort loudly.
if [ "$HOST_FILE_COUNT" -lt "$SRC_FILE_COUNT" ]; then
    echo "ERROR: host file count ($HOST_FILE_COUNT) is below source ($SRC_FILE_COUNT) after SCP." >&2
    echo "The copied tree is short; refusing to declare success on a partial extraction." >&2
    exit 1
fi
TOTAL_SIZE=$(du -sh "$DEST_DIR" | cut -f1)
echo "  Minecraft.Windows.exe: PE32+, $HOST_EXE_SIZE bytes (matches source)." >&2
echo "  Host tree: $HOST_FILE_COUNT files, $TOTAL_SIZE." >&2

# --- Clean up VM staging ----------------------------------------------------
echo "  Cleaning up VM staging directory..." >&2
ssh "$SSH_TARGET" "powershell -NoProfile -Command \"Remove-Item '$VM_STAGING' -Recurse -Force -ErrorAction SilentlyContinue\"" >&2 2>&1 || true

echo "" >&2
echo "=== Done ===" >&2
echo "Next: run scripts/setup.sh" >&2

# Machine-readable result for the caller (game-update.sh).
echo "RESULT exe_size=$HOST_EXE_SIZE file_count=$HOST_FILE_COUNT install_location=$INSTALL_DIR"
