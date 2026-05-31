#!/usr/bin/env bash
# capture-game.sh <outdir> <total_seconds> [name_regex]
# Robust visual capture for the Minecraft window on GNOME Wayland (game = XWayland client).
# Polls for the window, RAISES it (so it's not hidden behind the terminal), and grabs a
# screenshot each interval. Also detects Wine/crash error dialogs. Writes:
#   <outdir>/shot-<NNN>s.png ...   game frames over time
#   <outdir>/error-<NNN>s.png      any error/crash dialog
#   <outdir>/windows-seen.txt      every top-level window title observed
set -uo pipefail
OUT="${1:?outdir}"; TOTAL="${2:-120}"; NAME="${3:-Minecraft}"
mkdir -p "$OUT"
export DISPLAY="${DISPLAY:-:0}"

shoot() { grim "$1" 2>/dev/null || gnome-screenshot -f "$1" 2>/dev/null; }

found=NO; shots=0; t=0; STEP=12
: > "$OUT/windows-seen.txt"
while [ "$t" -lt "$TOTAL" ]; do
  # record every visible window title (for the run log)
  for w in $(xdotool search --onlyvisible --name '.' 2>/dev/null); do
    nm=$(xdotool getwindowname "$w" 2>/dev/null); [ -n "$nm" ] && echo "${t}s: $nm" >> "$OUT/windows-seen.txt"
  done
  # the game window
  wid=$(xdotool search --name "$NAME" 2>/dev/null | tail -1)
  if [ -n "${wid:-}" ]; then
    found=YES
    xdotool windowactivate "$wid" 2>/dev/null
    xdotool windowraise   "$wid" 2>/dev/null
    sleep 1
    shoot "$OUT/shot-$(printf '%03d' "$t")s.png" && shots=$((shots+1))
  fi
  # crash / error dialogs
  ewid=$(xdotool search --name 'Program Error\|Wine\|required component\|has stopped\|Application Error' 2>/dev/null | tail -1)
  if [ -n "${ewid:-}" ]; then
    xdotool windowactivate "$ewid" 2>/dev/null; xdotool windowraise "$ewid" 2>/dev/null; sleep 1
    shoot "$OUT/error-$(printf '%03d' "$t")s.png"
    echo "${t}s: ERROR DIALOG: $(xdotool getwindowname "$ewid" 2>/dev/null)" >> "$OUT/windows-seen.txt"
  fi
  sleep "$STEP"; t=$((t+STEP+1))
done
sort -u "$OUT/windows-seen.txt" -o "$OUT/windows-seen.txt"
echo "capture: game-window=$found shots=$shots; titles -> $OUT/windows-seen.txt"
