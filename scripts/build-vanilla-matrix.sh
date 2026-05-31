#!/usr/bin/env bash
# Build the vanilla WineGDK matrix: fresh clone + clean clang-23 build of each
# upstream variant into its own install dir. Disk-safe: builds one at a time and
# deletes the source+build tree after `make install` (keeps only the ~950M install).
#
# Build config is held CONSTANT (matches the known-good build64-clang23):
#   CC=clang-23 --enable-win64 --disable-win32
# so source is the only variable across variants.
#
# Output: ~/Projects/winegdk-vanilla/install-vanilla-<name>
# Logs:   /tmp/vanilla-builds/<name>.log  (+ this script's stdout)
set -uo pipefail

ROOT=/home/jp/Projects/winegdk-vanilla
LOGDIR=/tmp/vanilla-builds
mkdir -p "$ROOT" "$LOGDIR"
J=$(nproc)
MIN_FREE_GB=5   # abort a build if less than this free

# variant: name|repo|branch
VARIANTS=(
  "weatheros|https://github.com/Weather-OS/WineGDK.git|master"
  "lukas|https://github.com/LukasPAH/WineGDK.git|minimal-xbl"
  "olivir|https://github.com/olivi-r/WineGDK.git|rebased-xuser"
  "christopherhx|https://github.com/ChristopherHX/WineGDK.git|xuser-via-xgameruntime"
)

free_gb() { df --output=avail -BG /home/jp | tail -1 | tr -dc '0-9'; }

echo "=== vanilla build matrix START $(date) — nproc=$J — free=$(free_gb)G ==="
for v in "${VARIANTS[@]}"; do
  IFS='|' read -r name repo branch <<<"$v"
  log="$LOGDIR/$name.log"
  inst="$ROOT/install-vanilla-$name"
  src="$ROOT/src-$name"
  bld="$ROOT/build-$name"
  echo; echo "############ $name ($repo @ $branch) ############ $(date)"

  if [ -x "$inst/bin/wine" ]; then echo "already built: $($inst/bin/wine --version 2>&1|head -1) — skipping"; continue; fi
  if [ "$(free_gb)" -lt "$MIN_FREE_GB" ]; then echo "ABORT $name: only $(free_gb)G free (<${MIN_FREE_GB}G)"; continue; fi

  rm -rf "$src" "$bld"
  echo "[$name] shallow clone..." | tee -a "$log"
  if ! git clone --depth 1 --branch "$branch" "$repo" "$src" >>"$log" 2>&1; then
    echo "[$name] CLONE FAILED (branch $branch missing?) — see $log"; continue
  fi
  mkdir -p "$bld"
  echo "[$name] configure (CC=clang-23 --enable-win64 --disable-win32)..." | tee -a "$log"
  ( cd "$bld" && "../src-$name/configure" --prefix="$inst" CC=clang-23 --enable-win64 --disable-win32 ) >>"$log" 2>&1
  if [ $? -ne 0 ]; then echo "[$name] CONFIGURE FAILED — see $log (tail below)"; tail -8 "$log"; rm -rf "$src" "$bld"; continue; fi
  echo "[$name] make -j$J ..." | tee -a "$log"
  ( cd "$bld" && make -j"$J" ) >>"$log" 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then echo "[$name] BUILD FAILED (rc=$rc) — see $log (tail below)"; tail -12 "$log"; rm -rf "$src" "$bld"; continue; fi
  echo "[$name] make install ..." | tee -a "$log"
  ( cd "$bld" && make install ) >>"$log" 2>&1
  echo "[$name] cleaning build tree to save disk..." | tee -a "$log"
  rm -rf "$src" "$bld"
  if [ -x "$inst/bin/wine" ]; then
    echo "[$name] OK -> $($inst/bin/wine --version 2>&1|head -1) — free now $(free_gb)G"
  else
    echo "[$name] INSTALL MISSING wine binary — check $log"
  fi
done

echo; echo "=== installed vanilla variants ==="
for d in "$ROOT"/install-vanilla-*/bin/wine; do [ -x "$d" ] && echo "$(dirname "$(dirname "$d")"): $("$d" --version 2>&1|head -1)"; done
echo "=== DONE-VANILLA-BUILDS $(date) — free=$(free_gb)G ==="
