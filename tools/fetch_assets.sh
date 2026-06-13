#!/usr/bin/env bash
# Fetch the CC0 binary assets (characters, weapons, sky, ground textures) and
# generate the procedural SFX. Run once from the repo root before import/export.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE=https://preview.myapping.com/godot-assets
TEX=https://preview.myapping.com/godot-textures
mkdir -p models skies textures audio

# Characters: hero soldier + 4 enemy types
for c in soldier infected alien cyber reaver; do
	[ -s "models/$c.glb" ] || curl -sfL "$BASE/realistic_characters/$c.glb" -o "models/$c.glb"
done
# Weapons: hero rifle + enforcer arm-cannon
for w in rifle armcannon; do
	[ -s "models/$w.glb" ] || curl -sfL "$BASE/realistic_weapons/$w.glb" -o "models/$w.glb"
done
# Cold blue panorama sky (LDR PNG -> PanoramaSkyMaterial)
[ -s skies/sb_cloudy_4.png ] || curl -sfL "$BASE/skies/sb_cloudy_4.png" -o skies/sb_cloudy_4.png
# Ground / structure textures (CDN-first; fall back to a self-contained generator
# so the build never breaks if the flat texture URLs move).
[ -s textures/snow.png ]        || curl -sfL "$TEX/snow.png"        -o textures/snow.png        || true
[ -s textures/metal_panel.png ] || curl -sfL "$TEX/metal_panel.png" -o textures/metal_panel.png || true
if [ ! -s textures/snow.png ] || [ ! -s textures/metal_panel.png ]; then
	python3 tools/gen_textures.py
fi

# Procedural SFX
python3 tools/gen_audio.py

echo "assets ready"
