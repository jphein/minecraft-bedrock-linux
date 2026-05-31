#!/usr/bin/env bash
# capture-game.sh <outdir> <total_seconds> [name_regex]
# WORKING capture on GNOME Wayland (verified 2026-05-31):
#   gnome-screenshot -w  grabs the ACTIVE window's surface (occlusion-proof). A fullscreen
#   Bedrock window holds focus, so -w captures the game even behind the terminal.
# What does NOT work on GNOME/mutter: grim (no wlr-screencopy), xwd -id (BadMatch on composited
#   XWayland windows), org.gnome.Shell.Screenshot D-Bus (AccessDenied), xdotool windowactivate
#   (no _NET_ACTIVE_WINDOW). Launchers must set gfx_fullscreen:1 so the game grabs focus.
# Game-window frames are the game's geometry (e.g. 1849x1040); 1920x1080 frames are the desktop
# (game wasn't focused that tick) — keep the game-sized ones.
set -uo pipefail
OUT="${1:?outdir}"; TOTAL="${2:-150}"; NAME="${3:-^Minecraft$}"
U=$(id -u)
export DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR="/run/user/$U" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$U/bus"
mkdir -p "$OUT"; : > "$OUT/windows-seen.txt"
found=NO; shots=0; t=0; STEP=12
while [ "$t" -lt "$TOTAL" ]; do
  wid=$(xdotool search --name "$NAME" 2>/dev/null | head -1)
  if [ -n "${wid:-}" ]; then
    found=YES
    xdotool windowfocus "$wid" 2>/dev/null; xdotool windowraise "$wid" 2>/dev/null; sleep 1
    f="$OUT/shot-$(printf '%03d' "$t")s.png"
    gnome-screenshot -w -f "$f" 2>/dev/null && shots=$((shots+1))
    dim=$(ffprobe -v error -select_streams v -show_entries stream=width,height -of csv=p=0 "$f" 2>/dev/null)
    echo "${t}s: win='$(xdotool getwindowname "$wid" 2>/dev/null)' geo=$(xdotool getwindowgeometry "$wid" 2>/dev/null | grep -o 'Geometry: [0-9x]*') shot=$dim" >> "$OUT/windows-seen.txt"
  fi
  # error/crash dialogs are usually inside the game (cohtml) now, captured by -w above
  sleep "$STEP"; t=$((t+STEP+1))
done
echo "capture: game-window=$found shots=$shots -> $OUT/ (see windows-seen.txt for per-shot dims)"
