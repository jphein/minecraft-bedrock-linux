#!/usr/bin/env bash
# Tune Bedrock in-game video settings for GTX 1650 4GB + i7-3770 under Wine/DXVK.
# Run with the game CLOSED (the game rewrites options.txt on exit). Idempotent;
# only rewrites keys that already exist. Makes a timestamped backup first.
set -euo pipefail
PFX="${PREFIX_DIR:-$HOME/Games/minecraft-bedrock/prefix}"
OPTS="$PFX/drive_c/users/$(whoami)/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/minecraftpe/options.txt"

if pgrep -fi 'Minecraft\.Windows' >/dev/null 2>&1; then
  echo "Minecraft is running — close it first (it overwrites options.txt on exit)." >&2; exit 1
fi
[ -f "$OPTS" ] || { echo "options.txt not found: $OPTS" >&2; exit 1; }
cp -p "$OPTS" "${OPTS}.bak.$(date +%Y%m%d-%H%M%S)"

# current -> recommended (rationale in PERFORMANCE.md). viewdistance must be a
# multiple of 16: 128=8ch(max fps), 192=12ch(recommended), 256=16ch.
sed -i \
  -e 's/^gfx_viewdistance:.*/gfx_viewdistance:192/' \
  -e 's/^gfx_particleviewdistance:.*/gfx_particleviewdistance:0/' \
  -e 's/^gfx_msaa:.*/gfx_msaa:0/' \
  -e 's/^gfx_texel_aa_2:.*/gfx_texel_aa_2:0/' \
  -e 's/^gfx_smoothlighting:.*/gfx_smoothlighting:0/' \
  -e 's/^gfx_fancyskies:.*/gfx_fancyskies:0/' \
  -e 's/^gfx_transparentleaves:.*/gfx_transparentleaves:0/' \
  -e 's/^gfx_vsync:.*/gfx_vsync:0/' \
  -e 's/^gfx_max_framerate:.*/gfx_max_framerate:60/' \
  -e 's/^gfx_multithreaded_renderer:.*/gfx_multithreaded_renderer:1/' \
  -e 's/^graphics_mode:.*/graphics_mode:0/' \
  "$OPTS"
echo "Applied perf video settings (backup saved). Changed:"
grep -E '^(gfx_viewdistance|gfx_msaa|gfx_smoothlighting|gfx_transparentleaves|gfx_fancyskies|gfx_vsync|gfx_max_framerate|graphics_mode):' "$OPTS"
