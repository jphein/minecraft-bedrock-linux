#!/usr/bin/env bash
# Update terra Bedrock Dedicated Servers (BDS) to match a client marketing version.
#
# RUNS ON terra (the orchestrator scp-s this script there and runs it over SSH).
# Contract: docs/superpowers/specs/2026-06-27-one-command-bedrock-update-design.md §4.
# Proven recipe: scratch/mc-bedrock-update/somnia.md (the 1.26.21.1 -> 1.26.31.1 run).
#
# Usage:
#   update-bds-servers.sh --target <marketing version> <service:user:port:name> [...]
#
#   --target   marketing version like "1.26.40" (orchestrator derives from client).
#              Each BDS triple is "systemd_service:linux_user:udp_port:display_name".
#
# For each server: read current version -> resolve exact BDS zip by HEAD-probing
# https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server-<v>.zip
# for candidates matching the target marketing version (abort that server if none
# exists yet) -> download once and reuse -> back up worlds/ + the 4 config files
# (as the server's user; a user's home may be 0700 so we use `sudo -u <user> bash -c`)
# -> systemctl stop -> unzip -o EXCLUDING configs + worlds/* -> systemctl start ->
# verify the startup log shows the new Version + "Server started".
#
# NEVER touches a Java/mcfabric service. Emits one RESULT line per server:
#   RESULT server=<name> old=<v> new=<v> status=up|fail
#
# Human progress goes to stderr / the log file; RESULT lines go to stdout.

set -euo pipefail

# --- constants ---------------------------------------------------------------
BDS_BASE_URL="https://www.minecraft.net/bedrockdedicatedserver/bin-linux"
# minecraft.net's CDN rejects default curl HTTP/2 HEAD/GET (resets the stream -> code 000);
# force HTTP/1.1 + a browser User-Agent, which it serves normally (confirmed 2026-06-28).
BDS_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
BDS_CURL_OPTS=(--http1.1 -A "$BDS_UA")
INSTALL_SUBDIR="minecraft_bedrock"      # /home/<user>/minecraft_bedrock (per somnia.md)
# Files/dirs never clobbered by the unzip (preserve player/world state).
UNZIP_EXCLUDES=( "server.properties" "permissions.json" "allowlist.json" "whitelist.json" "worlds/*" )
# Config files backed up alongside worlds/. (whitelist.json is the legacy name for
# allowlist.json; back up whichever exists.)
BACKUP_CONFIGS=( "server.properties" "permissions.json" "allowlist.json" "whitelist.json" )

# --- logging -----------------------------------------------------------------
# All run logs under the repo logs/ dir, never /tmp. This script lives in
# <repo>/scripts/ when checked out, but the orchestrator scp-s it to a standalone
# path on terra; fall back to a logs/ next to the script (or the cwd) in that case.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/../logs" || "$(basename "$SCRIPT_DIR")" == "scripts" ]]; then
    LOG_DIR="$SCRIPT_DIR/../logs"
else
    LOG_DIR="$SCRIPT_DIR/logs"
fi
mkdir -p "$LOG_DIR"
TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/update-bds-servers-$TS.log"

# log() -> stderr + log file (human-readable progress, never stdout).
log() {
    printf '%s %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG_FILE" >&2
}
# result() -> stdout (machine-readable, parsed by the orchestrator).
result() {
    printf 'RESULT %s\n' "$*"
    printf '%s RESULT %s\n' "$(date +%H:%M:%S)" "$*" >> "$LOG_FILE"
}
die() {
    log "FATAL: $*"
    exit 1
}

# --- arg parsing -------------------------------------------------------------
TARGET=""
SERVERS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET="${2:-}"
            [[ -n "$TARGET" ]] || die "--target requires a marketing version (e.g. 1.26.40)"
            shift 2
            ;;
        --target=*)
            TARGET="${1#--target=}"
            shift
            ;;
        -h|--help)
            sed -n '2,30p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        --*)
            die "unknown flag: $1"
            ;;
        *)
            SERVERS+=( "$1" )
            shift
            ;;
    esac
done

[[ -n "$TARGET" ]] || die "missing --target <marketing version> (e.g. 1.26.40)"
[[ ${#SERVERS[@]} -gt 0 ]] || die "no BDS servers given (expected one or more service:user:port:name)"

log "=== terra BDS update: target marketing version $TARGET ==="
log "servers: ${SERVERS[*]}"
log "log file: $LOG_FILE"

# --- helpers -----------------------------------------------------------------

# run_as_user <user> <command-string> — run a command as the server user.
# a server user's home may be mode 0700, so we cannot `cd` there as the login user;
# instead we exec inside a login-ish shell owned by the target user.
run_as_user() {
    local user="$1"; shift
    sudo -u "$user" bash -c "$1"
}

# read_console <user> <service> — capture the live server console from its screen
# session and echo it on stdout. start_server.sh launches the server via
# `screen -dmS <service>` (the screen session name IS the systemd service name),
# with console output going to the screen session, NOT to any *.log file (screen
# logging is OFF by default on terra). So we ask screen to dump its scrollback
# buffer with `hardcopy -h` to a temp file, then cat it back. Runs as the server
# user (the session is owned by that user; install/home may be 0700).
read_console() {
    local user="$1" service="$2"
    run_as_user "$user" "
        hc=\"\$(mktemp \"/home/$user/.bds-console.XXXXXX\")\" || exit 0
        trap 'rm -f \"\$hc\"' EXIT
        screen -S '$service' -X hardcopy -h \"\$hc\" 2>/dev/null || exit 0
        # -h dumps the full scrollback; give screen a moment to flush, then read.
        sleep 1
        cat \"\$hc\" 2>/dev/null || true
    " 2>/dev/null || true
}

# url_exists <url> — HEAD probe; returns 0 only on HTTP 200.
url_exists() {
    local url="$1" code
    code="$(curl -fsS "${BDS_CURL_OPTS[@]}" -o /dev/null -I -w '%{http_code}' --max-time 30 "$url" 2>/dev/null || true)"
    [[ "$code" == "200" ]]
}

# read_current_version <user> <install_dir> — print the live binary's version
# WITHOUT touching live state. We copy bedrock_server into a throwaway scratch
# dir under the server user's home and run it there (cwd has no server.properties
# and no worlds/), with LD_LIBRARY_PATH pointing at the live dir for the .so libs.
# Because the scratch cwd lacks server.properties, the binary prints its startup
# banner ("Version: x.y.z.w") and then quits on its own *before* binding the UDP
# port or opening the live worlds/ LevelDB — so there is no port/LOCK contention
# with the still-running production server (proven on terra 2026-06-27).
# Echoes the version (or "unknown") on stdout. Runs as the server user because
# the install dir may live under a 0700 home.
read_current_version() {
    local user="$1" dir="$2" ver=""
    if run_as_user "$user" "test -x '$dir/bedrock_server'"; then
        ver="$(run_as_user "$user" "
            scratch=\"\$(mktemp -d \"/home/$user/.bds-verread.XXXXXX\")\" || exit 0
            trap 'rm -rf \"\$scratch\"' EXIT
            cp '$dir/bedrock_server' \"\$scratch/\" 2>/dev/null || exit 0
            cd \"\$scratch\" || exit 0
            LD_LIBRARY_PATH='$dir' timeout 8 ./bedrock_server 2>/dev/null \
              | grep -m1 -oE 'Version: [0-9.]+' \
              | awk '{print \$2}'
        " 2>/dev/null || true)"
    fi
    printf '%s' "${ver:-unknown}"
}

# resolve_zip <marketing> — find the exact bedrock-server-<v>.zip whose version
# matches the target marketing version, HEAD-probing candidates newest-first.
# Echoes the resolved full version on stdout, or nothing (caller treats as abort).
resolve_zip_version() {
    local marketing="$1" v
    # Candidate full versions for a 3-part marketing version (e.g. 1.26.40):
    #   1.26.40, then 1.26.40.NN for NN = high..low (newest patch first).
    # If the caller already passed a full 4-part version, try it verbatim first.
    local -a candidates=()
    local dots
    dots="$(awk -F. '{print NF}' <<<"$marketing")"
    if [[ "$dots" -ge 4 ]]; then
        candidates+=( "$marketing" )
    fi
    # 4-part patch candidates, newest patch first (BDS patch numbers are small).
    local nn
    for nn in 30 25 20 15 12 11 10 9 8 7 6 5 4 3 2 1; do
        candidates+=( "${marketing%.*}.${marketing##*.}.${nn}" )
    done
    # The bare 3-part form (some releases publish e.g. 1.26.40.zip-equivalent).
    candidates+=( "$marketing" )
    # Also try a leading-zero patch form some releases use (1.26.40.01).
    for nn in 05 04 03 02 01; do
        candidates+=( "${marketing%.*}.${marketing##*.}.${nn}" )
    done

    for v in "${candidates[@]}"; do
        if url_exists "$BDS_BASE_URL/bedrock-server-$v.zip"; then
            printf '%s' "$v"
            return 0
        fi
    done
    return 1
}

# --- resolve & download the BDS zip ONCE (reused across all servers) ---------
log "resolving BDS zip for marketing version $TARGET ..."
RESOLVED_VERSION="$(resolve_zip_version "$TARGET" || true)"
if [[ -z "$RESOLVED_VERSION" ]]; then
    log "ABORT: no published bedrock-server zip matches target $TARGET yet."
    log "       (HEAD-probed $BDS_BASE_URL/bedrock-server-<candidates>.zip — all 404)"
    # No download possible; emit a fail RESULT for every requested server so the
    # orchestrator sees per-server status, then exit non-zero.
    for spec in "${SERVERS[@]}"; do
        IFS=: read -r _svc _user _port name <<<"$spec"
        result "server=${name:-$spec} old=unknown new=unknown status=fail"
    done
    die "no BDS release for $TARGET"
fi
log "resolved full BDS version: $RESOLVED_VERSION"

ZIP_NAME="bedrock-server-$RESOLVED_VERSION.zip"
ZIP_PATH="$LOG_DIR/$ZIP_NAME"
ZIP_URL="$BDS_BASE_URL/$ZIP_NAME"

if [[ -s "$ZIP_PATH" ]]; then
    log "reusing already-downloaded $ZIP_PATH"
else
    log "downloading $ZIP_URL -> $ZIP_PATH"
    curl -fSL "${BDS_CURL_OPTS[@]}" --max-time 600 -o "$ZIP_PATH.partial" "$ZIP_URL" \
        || die "download failed: $ZIP_URL"
    mv -f "$ZIP_PATH.partial" "$ZIP_PATH"
fi
# Sanity: must be a real zip containing the binary. Capture the listing once and grep
# the captured text — `unzip -l | grep -q` trips `set -o pipefail`: grep -q exits on the
# first match, unzip gets SIGPIPE (141), and the pipeline reports failure even though the
# match WAS found (this false-failed a perfectly valid 9761-file BDS zip on 2026-06-28).
ZIP_LIST="$(unzip -l "$ZIP_PATH" 2>/dev/null)" || die "downloaded file is not a valid zip: $ZIP_PATH"
grep -q 'bedrock_server' <<<"$ZIP_LIST" || die "zip $ZIP_PATH does not contain bedrock_server"
log "zip verified ($(du -h "$ZIP_PATH" | awk '{print $1}'))"

# Unique per-run backup stamp (reuse the run timestamp $TS = YYYYmmdd-HHMMSS) so a
# second run on the same day never merges into / overwrites an earlier run's
# known-good backup. One fresh restore point per execution.
BACKUP_STAMP="$TS"

# --- per-server update -------------------------------------------------------
OVERALL_RC=0

update_one() {
    local spec="$1"
    local service user port name
    IFS=: read -r service user port name <<<"$spec"
    : "$port"   # port is part of the triple contract; not used directly here

    if [[ -z "$service" || -z "$user" || -z "$name" ]]; then
        log "[$spec] malformed server spec (need service:user:port:name) — skipping"
        result "server=${name:-$spec} old=unknown new=unknown status=fail"
        return 1
    fi

    # Hard guard: never touch a Java / fabric service.
    case "$service" in
        *fabric*|*java*)
            log "[$name] REFUSING to touch Java/fabric service '$service' — skipping"
            result "server=$name old=unknown new=unknown status=fail"
            return 1
            ;;
    esac

    local install_dir="/home/$user/$INSTALL_SUBDIR"
    log "--- [$name] service=$service user=$user dir=$install_dir ---"

    if ! run_as_user "$user" "test -f '$install_dir/bedrock_server'"; then
        log "[$name] no bedrock_server at $install_dir — skipping"
        result "server=$name old=unknown new=unknown status=fail"
        return 1
    fi

    # 1. current version
    local old_ver
    old_ver="$(read_current_version "$user" "$install_dir")"
    log "[$name] current version: $old_ver"

    if [[ "$old_ver" == "$RESOLVED_VERSION" ]]; then
        log "[$name] already at $RESOLVED_VERSION — re-applying to ensure consistency"
    fi

    # 2. backup worlds/ + config files (run as the server user; home may be 0700)
    local backup_dir="/home/$user/worlds_backup_$BACKUP_STAMP"
    log "[$name] backing up worlds/ + configs -> $backup_dir"
    local cfg_list="${BACKUP_CONFIGS[*]}"
    if ! run_as_user "$user" "
        set -e
        cd '$install_dir'
        mkdir -p '$backup_dir'
        if [ -d worlds ]; then
            cp -a worlds '$backup_dir/'
        fi
        for f in $cfg_list; do
            # Tolerate ONLY the missing-file case; a real cp failure (perms, disk)
            # must abort under set -e so the outer `if !` catches it. Using
            # `&& ... || true` here would also swallow a genuine cp error.
            if [ -f \"\$f\" ]; then
                cp -a \"\$f\" '$backup_dir/'
            fi
        done
    "; then
        log "[$name] backup FAILED — aborting this server (no changes made)"
        result "server=$name old=$old_ver new=$old_ver status=fail"
        return 1
    fi
    log "[$name] backup complete ($(sudo -u "$user" du -sh "$backup_dir" 2>/dev/null | awk '{print $1}'))"

    # 3. stop the service (clean; ExecStop sends `stop`)
    log "[$name] systemctl stop $service"
    if ! sudo systemctl stop "$service"; then
        log "[$name] systemctl stop failed — aborting this server"
        result "server=$name old=$old_ver new=$old_ver status=fail"
        return 1
    fi
    # brief settle so the binary releases file locks
    local i
    for i in 1 2 3 4 5; do
        sudo systemctl is-active --quiet "$service" || break
        sleep 1
    done

    # 4. unzip -o over the install, EXCLUDING configs + worlds/* (and never
    #    touching start_server.sh, which is not in the zip). Run as the server
    #    user so files land with correct ownership inside a 0700 home.
    log "[$name] unzip -o $ZIP_NAME over $install_dir (excluding configs + worlds)"
    # Copy the zip somewhere the server user can read it (LOG_DIR may be under
    # the login user's home / repo and unreadable to the server user). Stage in
    # the user's home, then clean up.
    local staged_zip="/home/$user/.bds-update-$RESOLVED_VERSION.zip"
    if ! run_as_user "$user" "cat > '$staged_zip'" < "$ZIP_PATH"; then
        log "[$name] failed to stage zip for $user — restarting service, aborting"
        sudo systemctl start "$service" || true
        result "server=$name old=$old_ver new=$old_ver status=fail"
        return 1
    fi

    local exclude_args=""
    local ex
    for ex in "${UNZIP_EXCLUDES[@]}"; do
        exclude_args+=" -x '$ex'"
    done

    if ! run_as_user "$user" "
        set -e
        cd '$install_dir'
        unzip -o '$staged_zip' $exclude_args
        rm -f '$staged_zip'
        chmod +x bedrock_server
    "; then
        log "[$name] unzip FAILED — restarting service, aborting (worlds intact, backup at $backup_dir)"
        run_as_user "$user" "rm -f '$staged_zip'" || true
        sudo systemctl start "$service" || true
        result "server=$name old=$old_ver new=$old_ver status=fail"
        return 1
    fi

    # 5. start the service
    log "[$name] systemctl start $service"
    if ! sudo systemctl start "$service"; then
        log "[$name] systemctl start FAILED — aborting (backup at $backup_dir)"
        result "server=$name old=$old_ver new=$old_ver status=fail"
        return 1
    fi

    # 6. verify the fresh server console shows the new Version + "Server started".
    #    The forking unit launches start_server.sh -> `screen -dmS <service>`;
    #    the banner goes to the screen session (no *.log file exists on terra).
    #    We read the session scrollback via `hardcopy -h` (see read_console).
    #    Right after a fresh start the buffer is near-empty, so the banner is
    #    captured reliably. Poll for up to ~60s.
    log "[$name] verifying startup (Version: $RESOLVED_VERSION + 'Server started') ..."
    local saw_version="" saw_started="" attempt
    for attempt in $(seq 1 30); do
        local console
        console="$(read_console "$user" "$service")"
        if grep -q "Version: $RESOLVED_VERSION" <<<"$console"; then
            saw_version=1
        fi
        if grep -q "Server started" <<<"$console"; then
            saw_started=1
        fi
        if [[ -n "$saw_version" && -n "$saw_started" ]]; then
            break
        fi
        sleep 2
    done

    # Confirm service is actually active too.
    local active=""
    sudo systemctl is-active --quiet "$service" && active=1

    if [[ -n "$saw_version" && -n "$saw_started" && -n "$active" ]]; then
        log "[$name] UP at $RESOLVED_VERSION (verified: Version banner + Server started + active)"
        result "server=$name old=$old_ver new=$RESOLVED_VERSION status=up"
        return 0
    fi

    log "[$name] VERIFY FAILED (version_seen=${saw_version:-0} started_seen=${saw_started:-0} active=${active:-0})"
    log "[$name]   backup preserved at $backup_dir"
    result "server=$name old=$old_ver new=$RESOLVED_VERSION status=fail"
    return 1
}

for spec in "${SERVERS[@]}"; do
    if ! update_one "$spec"; then
        OVERALL_RC=1
    fi
done

log "=== done (exit $OVERALL_RC); log: $LOG_FILE ==="
exit "$OVERALL_RC"
