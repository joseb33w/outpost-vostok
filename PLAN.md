# Goal
Build **Outpost Vostok** — a wave-survival sci-fi shooter (Godot 4.6.3, single-threaded WebGL2/Compatibility web export) that runs in mobile + desktop browsers. The player is a spec-ops soldier defending a frozen alien outpost against escalating waves of melee + ranged enemies. Third-person, fully playable with touch (floating joystick + fire/reload buttons + drag-to-orbit camera) and keyboard/mouse (WASD + Space/LMB + R).

# Files to touch
- `project.godot` — Compatibility renderer (mobile+web), canvas_items/expand stretch, touch-mouse emulation, input map (move/fire/reload/dodge), MSAA 2x.
- `export_presets.cfg` — `Web` preset, `thread_support=false` (nothreads), mobile `head_include` (viewport-fit=cover meta, full-screen CSS, touch-action:none).
- `meshy_character_rig.gd` — vendored MeshyCharacterRig component (drives realistic chars: ADS aim, recoil fire w/ flash+tracer, reload).
- `scripts/main.gd` — Main orchestrator: builds the lit environment (LDR panorama cold blue sky, snow ground, perimeter wall, cover, beacon, floodlights, fog), follow-camera, wave system, score, routing, game-state.
- `scripts/player.gd` — CharacterBody3D: camera-relative movement, auto-aim facing, hitscan fire w/ impact FX, health, damage flash + screen shake.
- `scripts/enemy.gd` — CharacterBody3D: chase AI, melee + ranged (cyber/armcannon) attacks, hit-flash, death.
- `scripts/hud.gd` — CanvasLayer UI: HP bar, wave/score/kills, floating joystick, fire/reload/dodge buttons, drag-look, tap-to-deploy start overlay (audio unlock), game-over overlay. Responsive relayout (portrait+landscape).
- `scripts/{config,audio,leaderboard}.gd` — tuning data, procedural SFX playback, public Supabase leaderboard via HTTPRequest.
- `tools/gen_audio.py` — procedurally generated arcade SFX (shot/hit/hurt/wave/gameover/...).
- CC0 assets fetched via `tools/fetch_assets.sh` (soldier/infected/alien/cyber/reaver + rifle/armcannon, sb_cloudy_4 sky, snow/metal textures).

# Verification approach
- Headless logic self-test (`tests/selftest.gd`, no GPU): clip resolution, facing (W=back / S=face, no +Z moonwalk), enemy AI chase + melee damage, combat fire delta + juice particles, kill scoring.
- Headless smoke verify via the vetted `verify.mjs` (engine boots, canvas, clean console, frames) + screenshot critique vs the committed cold sci-fi art style; mobile fill at portrait + landscape.
- Backend: the public leaderboard table already exists — verified anon SELECT (200) + INSERT (201) via REST.

# Out of scope
- Multiplayer (single-player survival).
- Per-account cloud saves (anon auth disabled on the shared project; the leaderboard is a genuinely-public arcade table + a localStorage personal best).
- Real-device audio/GPU/touch-feel, which the sandbox structurally cannot exercise (documented in the PR).
