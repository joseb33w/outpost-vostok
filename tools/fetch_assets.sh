#!/usr/bin/env bash
# Fetches the CC0 binary assets (characters, weapons, sky, texture) and generates
# the procedural SFX. Run once from the repo root before importing/exporting.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE=https://preview.myapping.com/godot-assets
mkdir -p models audio

for c in soldier vanguard specter warden cyber alien infected reaver; do
  [ -s "models/$c.glb" ] || curl -sfL "$BASE/realistic_characters/$c.glb" -o "models/$c.glb"
done
for w in rifle pistol plasma armcannon; do
  [ -s "models/$w.glb" ] || curl -sfL "$BASE/realistic_weapons/$w.glb" -o "models/$w.glb"
done
[ -s models/sky_industrial_sunset.hdr ] || curl -sfL "$BASE/skies/ph_industrial_sunset_puresky.hdr" -o models/sky_industrial_sunset.hdr
[ -s models/metal_panel.png ] || curl -sfL "https://preview.myapping.com/godot-textures/metal_panel.png" -o models/metal_panel.png

python3 tools/gen_audio.py
echo "assets ready"
