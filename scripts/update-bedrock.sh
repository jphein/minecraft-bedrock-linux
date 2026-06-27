#!/usr/bin/env bash
#
# update-bedrock.sh — ONE-COMMAND Minecraft Bedrock update orchestrator (runs on katana).
#
# Collapses the whole recipe into a single command:
#   VM Store-update -> extract -> host-setup -> smoke-verify (on game)
#     -> back up + delta-rsync the build to katana
#     -> update the terra BDS servers to the matching protocol release
#     -> summary + "now launch and join a server" instruction.
#
# Authoritative contract: docs/superpowers/specs/2026-06-27-one-command-bedrock-update-design.md
# (this script is design §1). It NEVER declares success on a failed smoke and
# backs up before every overwrite. Bedrock requires client<->server protocol
# match, so the client and all BDS must end on the same release.
#
# Usage:
#   scripts/update-bedrock.sh [flags]
#
# Flags:
#   --client-only    Update only the client (game+katana); skip terra BDS servers.
#   --skip-vm        Re-extract the CURRENT VM build; skip the Windows Store update.
#   --skip-servers   Alias of --client-only (skip the terra BDS servers).
#   --dry-run        Print the plan and run only read-only probes; touch nothing.
#   --yes            Don't pause for interactive confirmation.
#   --help           Show this help and exit.
#
set -euo pipefail

# ---- locate the repo / self -------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF="$SCRIPT_DIR/update-targets.conf"
CONF_EXAMPLE="$SCRIPT_DIR/update-targets.conf.example"
LOG_DIR="$REPO_DIR/logs"

# Remote repo path (game runs the code we rsync there).
REMOTE_REPO="~/Projects/minecraft-bedrock-linux"

# ---- flags ------------------------------------------------------------------
CLIENT_ONLY=0
SKIP_VM=0
DRY_RUN=0
ASSUME_YES=0

usage() {
  sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
  case "$arg" in
    --client-only)  CLIENT_ONLY=1 ;;
    --skip-servers) CLIENT_ONLY=1 ;;
    --skip-vm)      SKIP_VM=1 ;;
    --dry-run)      DRY_RUN=1 ;;
    --yes|-y)       ASSUME_YES=1 ;;
    --help|-h)      usage; exit 0 ;;
    *)
      echo "update-bedrock: unknown flag: $arg" >&2
      echo "Try: scripts/update-bedrock.sh --help" >&2
      exit 2
      ;;
  esac
done

# ---- timestamp + log --------------------------------------------------------
# Allow the caller to pin the timestamp via the environment for consistency
# across composed runs; otherwise compute it once here.
TS="${UPDATE_TS:-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/update-$TS.log"
: > "$LOG"

# ---- logging helpers --------------------------------------------------------
# Human lines go to BOTH the console and the log. We never let log writing
# pollute machine-readable RESULT parsing (RESULT only comes from remote stdout).
log()  { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG"; }
info() { log "[*] $*"; }
ok()   { log "[ok] $*"; }
warn() { log "[warn] $*" >&2; }
step() { log ""; log "===== $* ====="; }

# Halt loud + safe. $1 = message. Reminds that nothing was pushed if we die
# before the katana push.
die() {
  log ""
  log "[FATAL] $*"
  log "[FATAL] Run halted. Log: $LOG"
  exit 1
}

# Run a command, echoing it; in --dry-run skip if it is destructive ($2=mutate).
# Usage: run "<description>" <mutate:0|1> -- cmd args...
run() {
  local desc="$1"; local mutate="$2"; shift 2
  [ "$1" = "--" ] && shift
  if [ "$DRY_RUN" = 1 ] && [ "$mutate" = 1 ]; then
    log "[dry-run] would: $desc"
    log "[dry-run]   \$ $*"
    return 0
  fi
  log "[run] $desc"
  "$@"
}

confirm() {
  local prompt="$1"
  [ "$ASSUME_YES" = 1 ] && return 0
  [ "$DRY_RUN" = 1 ] && return 0
  local ans
  read -r -p "$prompt [y/N] " ans
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) die "Aborted by user." ;;
  esac
}

# Parse "RESULT key=value" lines out of a captured remote stdout file.
# Usage: result_get <file> <key>  -> prints the (last) value, empty if absent.
result_get() {
  local file="$1" key="$2"
  grep -E "^RESULT[[:space:]]" "$file" 2>/dev/null \
    | grep -oE "(^|[[:space:]])$key=[^[:space:]]+" \
    | tail -n1 \
    | sed -E "s/.*$key=//"
}

# =============================================================================
# PHASE 1 — PREFLIGHT
# =============================================================================
step "Phase 1: Preflight"

if [ ! -f "$CONF" ]; then
  log "[FATAL] Config not found: $CONF"
  log "        Copy the example and fill in your real (private) values:"
  log "          cp '$CONF_EXAMPLE' '$CONF'"
  log "        (update-targets.conf is gitignored; real Tailscale IPs live only there.)"
  exit 1
fi

# shellcheck disable=SC1090
# Collect repeated BDS_SERVER lines into an array while sourcing the conf.
BDS_SERVERS=()
# Re-read BDS_SERVER lines explicitly (sourcing keeps only the last assignment).
while IFS= read -r _line; do
  case "$_line" in
    BDS_SERVER=*)
      _val="${_line#BDS_SERVER=}"
      _val="${_val%%#*}"
      # strip surrounding quotes/space
      _val="$(printf '%s' "$_val" | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
      [ -n "$_val" ] && BDS_SERVERS+=("$_val")
      ;;
  esac
done < "$CONF"

# Source for the scalar values (GAME_SSH, paths, etc.).
set +u
# shellcheck source=/dev/null
source "$CONF"
set -u

# Validate required keys.
: "${GAME_SSH:?GAME_SSH not set in $CONF}"
: "${GAME_GAME_DIR:?GAME_GAME_DIR not set in $CONF}"
: "${KATANA_GAME_DIR:?KATANA_GAME_DIR not set in $CONF}"

info "Run timestamp : $TS"
info "Log file      : $LOG"
info "Repo          : $REPO_DIR"
info "game host     : $GAME_SSH"
info "katana game   : $KATANA_GAME_DIR"
if [ "$CLIENT_ONLY" = 1 ]; then
  info "servers       : SKIPPED (--client-only)"
else
  info "servers       : ${#BDS_SERVERS[@]} BDS on ${TERRA_SSH:-<unset>}"
fi
[ "$SKIP_VM"  = 1 ] && info "VM Store scan : SKIPPED (--skip-vm; re-extract current build)"
[ "$DRY_RUN"  = 1 ] && info "MODE          : DRY RUN (read-only probes; no mutations)"

# Confirm SSH to the game host (read-only).
info "Checking SSH reachability to game host..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$GAME_SSH" true 2>>"$LOG"; then
  die "Cannot SSH to game host '$GAME_SSH'. Check Tailscale / 'ssh $GAME_SSH'."
fi
ok "game host reachable."

if [ "$CLIENT_ONLY" != 1 ]; then
  if [ -z "${TERRA_SSH:-}" ]; then
    die "TERRA_SSH unset but servers requested. Set it in $CONF or pass --client-only."
  fi
  if [ "${#BDS_SERVERS[@]}" -eq 0 ]; then
    warn "No BDS_SERVER entries in $CONF; nothing to update on terra."
  else
    info "Checking SSH reachability to terra..."
    if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$TERRA_SSH" true 2>>"$LOG"; then
      die "Cannot SSH to terra '$TERRA_SSH'. Check Tailscale / pass --client-only."
    fi
    ok "terra reachable."
  fi
fi

confirm "Proceed with the Bedrock update?"

# =============================================================================
# PHASE 2 — DELIVER SCRIPTS TO GAME
# =============================================================================
step "Phase 2: Deliver current scripts to game"

# rsync (not git) so game runs the current, possibly-unpushed code.
DELIVER_DIRS=(scripts config stubs)
RSYNC_DELIVER=()
for d in "${DELIVER_DIRS[@]}"; do
  [ -d "$REPO_DIR/$d" ] && RSYNC_DELIVER+=("$REPO_DIR/$d")
done

# Ensure the remote repo dir exists.
run "ensure remote repo dir" 1 -- \
  ssh "$GAME_SSH" "mkdir -p $REMOTE_REPO"

if [ "${#RSYNC_DELIVER[@]}" -gt 0 ]; then
  # Deliver code only; never push the gitignored conf (private IPs) — game reads
  # its OWN copy of update-targets.conf. Exclude built artifacts/logs.
  run "rsync scripts/config/stubs -> game" 1 -- \
    rsync -a --delete \
      --exclude='*.log' \
      --exclude='__pycache__' \
      --exclude='update-targets.conf' \
      --exclude='servers.conf' \
      "${RSYNC_DELIVER[@]}" "$GAME_SSH:$REMOTE_REPO/"
  ok "scripts delivered to game."
else
  warn "No deliverable dirs found under $REPO_DIR (scripts/config/stubs)."
fi

# =============================================================================
# PHASE 3 — GAME-SIDE UPDATE (VM -> extract -> setup -> smoke)
# =============================================================================
step "Phase 3: Game-side update + smoke (one SSH hop)"

GAME_FLAGS=()
[ "$SKIP_VM"  = 1 ] && GAME_FLAGS+=(--skip-vm)
[ "$DRY_RUN"  = 1 ] && GAME_FLAGS+=(--dry-run)

GAME_OUT="$LOG_DIR/game-update-$TS.out"
: > "$GAME_OUT"

# Run game-update.sh over one hop. tee its combined output to the log AND to a
# RESULT-parse file. Capture the remote exit code through the pipe.
info "Running scripts/game-update.sh on game (this includes the ~8-15 min Store poll unless --skip-vm)..."
set +e
ssh "$GAME_SSH" "bash $REMOTE_REPO/scripts/game-update.sh ${GAME_FLAGS[*]}" \
  2>&1 | tee -a "$LOG" "$GAME_OUT"
GAME_RC=${PIPESTATUS[0]}
set -e

NEW_VERSION="$(result_get "$GAME_OUT" new_version)"
OLD_VERSION="$(result_get "$GAME_OUT" old_version)"
GAME_EXE_SIZE="$(result_get "$GAME_OUT" exe_size)"
GAME_FILE_COUNT="$(result_get "$GAME_OUT" file_count)"
SMOKE="$(result_get "$GAME_OUT" smoke)"

if [ "$DRY_RUN" = 1 ]; then
  info "[dry-run] game-update exit=$GAME_RC; not gating on smoke."
else
  if [ "$GAME_RC" -ne 0 ]; then
    die "game-update.sh exited $GAME_RC. Build is BAD; NOTHING pushed to katana; game.bak rollback intact. See $GAME_OUT."
  fi
  if [ "$SMOKE" != "pass" ]; then
    die "Smoke check did not pass (smoke='${SMOKE:-<none>}'). NOTHING pushed to katana; game.bak rollback intact. See $GAME_OUT."
  fi
  if [ -z "$NEW_VERSION" ]; then
    die "game-update.sh did not report RESULT new_version=. Refusing to push an unidentified build. See $GAME_OUT."
  fi
  ok "Game build verified + smoke=pass. new_version=$NEW_VERSION (was ${OLD_VERSION:-?}), exe_size=${GAME_EXE_SIZE:-?}."
fi

# =============================================================================
# PHASE 4 — PUSH TO KATANA (backup -> delta-rsync resume-retry -> verify)
# =============================================================================
step "Phase 4: Push verified build to katana"

if [ "$DRY_RUN" = 1 ]; then
  info "[dry-run] would back up '$KATANA_GAME_DIR' -> game.bak-<oldver> and delta-rsync from game."
else
  # Resolve katana paths.
  KATANA_PARENT="$(dirname "$KATANA_GAME_DIR")"
  mkdir -p "$KATANA_PARENT"

  # 4a. Backup current katana build before overwrite (only if it exists).
  if [ -d "$KATANA_GAME_DIR" ]; then
    BAK_VER="${OLD_VERSION:-$(date +%s)}"
    BAK_DIR="$KATANA_GAME_DIR.bak-$BAK_VER"
    # If a backup with this version already exists, suffix the timestamp so we
    # never clobber an existing rollback point.
    [ -e "$BAK_DIR" ] && BAK_DIR="$KATANA_GAME_DIR.bak-$BAK_VER-$TS"
    info "Backing up katana build -> $BAK_DIR (CoW reflink if supported)..."
    if cp -a --reflink=auto "$KATANA_GAME_DIR" "$BAK_DIR" 2>>"$LOG"; then
      ok "Backup created (reflink): $BAK_DIR"
    else
      warn "reflink cp failed; falling back to mv (instant, but removes the live dir until rsync repopulates it)."
      mv "$KATANA_GAME_DIR" "$BAK_DIR"
      ok "Backup created (mv): $BAK_DIR"
    fi
  else
    warn "No existing katana build at '$KATANA_GAME_DIR' (first install?); nothing to back up."
    BAK_DIR=""
  fi

  mkdir -p "$KATANA_GAME_DIR"

  # Resolve the rsync SOURCE path on GAME, not from katana's $HOME. GAME_GAME_DIR
  # was sourced from katana's conf where "$HOME/..." expanded to KATANA's home;
  # using it as the remote source is only correct because game and katana happen
  # to share /home/jp. Re-resolve game's OWN conf value in game's shell so the
  # source is host-correct even if game's user/home differs.
  GAME_GAME_DIR_REMOTE="$(ssh "$GAME_SSH" \
    "set -a; . $REMOTE_REPO/scripts/update-targets.conf 2>/dev/null; eval echo \"\$GAME_GAME_DIR\"" \
    2>>"$LOG")"
  if [ -z "$GAME_GAME_DIR_REMOTE" ]; then
    warn "Could not resolve GAME_GAME_DIR on game from its conf; falling back to katana-expanded path '$GAME_GAME_DIR'."
    GAME_GAME_DIR_REMOTE="$GAME_GAME_DIR"
  else
    info "Resolved game-side source dir: $GAME_GAME_DIR_REMOTE"
  fi

  # 4b. Delta-rsync game -> katana with resume-retry. Files change IN PLACE so
  # NEVER use --append-verify (per echo.md). game wifi can drop mid-transfer.
  RSYNC_TRIES=5
  RSYNC_OK=0
  for try in $(seq 1 "$RSYNC_TRIES"); do
    info "rsync game -> katana (attempt $try/$RSYNC_TRIES)..."
    set +e
    rsync -a --partial --delete \
      --info=progress2 \
      "$GAME_SSH:$GAME_GAME_DIR_REMOTE/" "$KATANA_GAME_DIR/" 2>&1 | tee -a "$LOG"
    rc=${PIPESTATUS[0]}
    set -e
    if [ "$rc" -eq 0 ]; then
      RSYNC_OK=1
      ok "rsync completed clean on attempt $try."
      break
    fi
    warn "rsync attempt $try failed (rc=$rc); retrying with --partial resume..."
    sleep 5
  done

  if [ "$RSYNC_OK" != 1 ]; then
    die "rsync game->katana failed after $RSYNC_TRIES attempts. Rollback: rm -rf '$KATANA_GAME_DIR' && mv '$BAK_DIR' '$KATANA_GAME_DIR'"
  fi

  # 4c. Verify the katana exe (catch the silent stale-binary failure mode).
  KATANA_EXE="$KATANA_GAME_DIR/Minecraft.Windows.exe"
  [ -f "$KATANA_EXE" ] || die "katana exe missing after rsync: $KATANA_EXE"

  EXE_TYPE="$(file -b "$KATANA_EXE")"
  case "$EXE_TYPE" in
    *PE32+*) ok "katana exe is PE32+ ($EXE_TYPE)." ;;
    *) die "katana exe is not PE32+ (got: $EXE_TYPE). Build looks corrupt." ;;
  esac

  KATANA_EXE_SIZE="$(stat -c '%s' "$KATANA_EXE")"
  if [ -n "$GAME_EXE_SIZE" ] && [ "$KATANA_EXE_SIZE" != "$GAME_EXE_SIZE" ]; then
    die "katana exe size ($KATANA_EXE_SIZE) != game exe size ($GAME_EXE_SIZE). rsync did not land the new binary."
  fi
  ok "katana exe size = ${KATANA_EXE_SIZE} (matches game)."

  # Version cross-check against AppxManifest if present.
  KATANA_MANIFEST="$KATANA_GAME_DIR/AppxManifest.xml"
  if [ -n "$NEW_VERSION" ] && [ -f "$KATANA_MANIFEST" ]; then
    if grep -qF "$NEW_VERSION" "$KATANA_MANIFEST" 2>/dev/null; then
      ok "katana AppxManifest reports version $NEW_VERSION."
    else
      warn "katana AppxManifest does not contain '$NEW_VERSION' verbatim (marketing vs package version differ?). Size/PE checks passed."
    fi
  fi

  ok "Client pushed + verified on katana."
fi

# =============================================================================
# PHASE 5 — TERRA BDS SERVERS
# =============================================================================
SERVER_RESULTS=()
if [ "$CLIENT_ONLY" = 1 ]; then
  step "Phase 5: Servers SKIPPED (--client-only)"
elif [ "${#BDS_SERVERS[@]}" -eq 0 ]; then
  step "Phase 5: No BDS_SERVER entries configured; skipping servers"
else
  step "Phase 5: Update terra BDS servers"

  # Derive the BDS marketing target from the client package version.
  # Package version is like 1.26.4001.0 (4 parts) -> marketing 1.26.40.
  # update-bds-servers.sh probes the exact BDS zip (e.g. 1.26.40.NN) from this.
  BDS_TARGET=""
  if [ -n "$NEW_VERSION" ]; then
    # Take the first three dotted numeric groups; if the 3rd group is a 4-digit
    # build (e.g. 4001), reduce it to its leading marketing digits (40).
    IFS='.' read -r v1 v2 v3 _rest <<< "$NEW_VERSION"
    # Only the known 4-digit MMnn package scheme (e.g. 4001->40, 3101->31) carries
    # a trailing build pair to drop. Genuine 2- or 3-digit marketing minors
    # (e.g. 1.27.100 / 1.26.305 in older Bedrock schemes) are left untouched so we
    # don't mis-aim at the wrong marketing line; update-bds-servers.sh HEAD-probes
    # and fails safe if no matching zip exists.
    if [ -n "${v3:-}" ] && [ "${#v3}" -eq 4 ]; then
      # 4001 -> 40 ; 3101 -> 31 (drop trailing build pair)
      v3="${v3:0:2}"
    fi
    BDS_TARGET="${v1}.${v2}.${v3}"
  fi

  if [ -z "$BDS_TARGET" ]; then
    if [ "$DRY_RUN" = 1 ]; then
      BDS_TARGET="<derived-from-new_version>"
    else
      die "Cannot derive BDS target (no new_version). Re-run, or use --client-only."
    fi
  fi
  info "Derived BDS marketing target: $BDS_TARGET"

  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] would scp scripts/update-bds-servers.sh -> $TERRA_SSH:/tmp/ and run with target $BDS_TARGET for:"
    for s in "${BDS_SERVERS[@]}"; do log "[dry-run]   server: $s"; done
  else
    BDS_SCRIPT="$SCRIPT_DIR/update-bds-servers.sh"
    [ -f "$BDS_SCRIPT" ] || die "Missing $BDS_SCRIPT (needed for the servers phase)."

    info "Copying update-bds-servers.sh to terra..."
    scp -q "$BDS_SCRIPT" "$TERRA_SSH:/tmp/update-bds-servers.sh" 2>>"$LOG" \
      || die "scp of update-bds-servers.sh to terra failed."

    SRV_OUT="$LOG_DIR/bds-update-$TS.out"
    : > "$SRV_OUT"

    # Quote each server triple so display names with spaces survive the hop.
    QUOTED_SERVERS=()
    for s in "${BDS_SERVERS[@]}"; do
      QUOTED_SERVERS+=("$(printf '%q' "$s")")
    done

    info "Running update-bds-servers.sh on terra (target $BDS_TARGET)..."
    set +e
    ssh "$TERRA_SSH" \
      "bash /tmp/update-bds-servers.sh --target $(printf '%q' "$BDS_TARGET") ${QUOTED_SERVERS[*]}" \
      2>&1 | tee -a "$LOG" "$SRV_OUT"
    SRV_RC=${PIPESTATUS[0]}
    set -e

    # Parse one RESULT line per server: RESULT server=<name> old=<v> new=<v> status=up|fail
    # The BDS contract emits server= FIRST, then the single-token fields old/new/
    # status (versions + up|fail never contain spaces). So old/new/status are safe
    # to capture with their own [^space]+ patterns, but the DISPLAY NAME may contain
    # spaces (e.g. "Mellody Ann Brown") — capture it as everything from after
    # server= up to the next known key ( old=/ new=/ status=) or end of line, so a
    # space-bearing name survives instead of being truncated at the first space.
    ANY_FAIL=0
    while IFS= read -r rline; do
      sname="$(printf '%s' "$rline" \
        | sed -E 's/.*server=//; s/[[:space:]]+(old|new|status)=.*//')"
      sold="$(printf '%s'  "$rline" | grep -oE 'old=[^[:space:]]+'    | sed 's/old=//')"
      snew="$(printf '%s'  "$rline" | grep -oE 'new=[^[:space:]]+'    | sed 's/new=//')"
      sstat="$(printf '%s' "$rline" | grep -oE 'status=[^[:space:]]+' | sed 's/status=//')"
      [ -z "$sname" ] && continue
      SERVER_RESULTS+=("$sname|${sold:-?}|${snew:-?}|${sstat:-?}")
      [ "$sstat" = "up" ] || ANY_FAIL=1
    done < <(grep -E '^RESULT[[:space:]].*server=' "$SRV_OUT" 2>/dev/null)

    if [ "$SRV_RC" -ne 0 ] || [ "$ANY_FAIL" = 1 ]; then
      log ""
      log "[FATAL] One or more terra BDS servers failed to come up (rc=$SRV_RC)."
      log "[FATAL] The katana client was already updated; servers are out of protocol-sync."
      log "[FATAL] See $SRV_OUT. Fix the failing server(s) before joining."
      # Still print the summary below so JP sees which servers are which state.
      SERVERS_FATAL=1
    else
      ok "All ${#SERVER_RESULTS[@]} terra BDS servers updated and up."
      SERVERS_FATAL=0
    fi
  fi
fi

# =============================================================================
# PHASE 6 — SUMMARY
# =============================================================================
step "Phase 6: Summary"

{
  echo ""
  echo "================ BEDROCK UPDATE SUMMARY ================"
  echo "Timestamp : $TS"
  echo "Log       : $LOG"
  if [ "$DRY_RUN" = 1 ]; then
    echo "Mode      : DRY RUN (no changes made)"
  fi
  echo ""
  printf '%-22s %-14s -> %-14s %s\n' "TARGET" "OLD" "NEW" "STATUS"
  printf '%-22s %-14s -> %-14s %s\n' "----------------------" "--------------" "--------------" "------"
  printf '%-22s %-14s -> %-14s %s\n' \
    "client (game)" "${OLD_VERSION:-?}" "${NEW_VERSION:-?}" "smoke=${SMOKE:-?}"
  if [ "$DRY_RUN" != 1 ]; then
    printf '%-22s %-14s -> %-14s %s\n' \
      "client (katana)" "${OLD_VERSION:-?}" "${NEW_VERSION:-?}" "size=${KATANA_EXE_SIZE:-?}"
  fi
  if [ "$CLIENT_ONLY" = 1 ]; then
    printf '%-22s %s\n' "servers" "SKIPPED (--client-only)"
  elif [ "${#SERVER_RESULTS[@]}" -gt 0 ]; then
    for r in "${SERVER_RESULTS[@]}"; do
      IFS='|' read -r rn ro rnw rs <<< "$r"
      printf '%-22s %-14s -> %-14s %s\n' "server: $rn" "$ro" "$rnw" "status=$rs"
    done
  elif [ "$DRY_RUN" = 1 ]; then
    printf '%-22s %s\n' "servers" "(dry-run: not contacted)"
  fi
  echo "======================================================="
  echo ""
} | tee -a "$LOG"

# Final fatal gate for servers (after printing the table so state is visible).
if [ "${SERVERS_FATAL:-0}" = 1 ]; then
  die "Update finished with FAILED server(s). Client is on $NEW_VERSION; sync the server(s) before joining."
fi

if [ "$DRY_RUN" = 1 ]; then
  info "Dry run complete. No changes were made."
  exit 0
fi

{
  echo "NEXT STEP — launch and join (no headless launch on katana; it would pop a window on your desktop):"
  echo "  cd \"$REPO_DIR\""
  echo "  ./scripts/play-bedrock.sh"
  echo "Then open the Servers tab / LAN Games and join one of your servers to confirm the protocol match."
} | tee -a "$LOG"

ok "Bedrock update complete: client on $NEW_VERSION."
exit 0
