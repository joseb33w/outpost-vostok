# Goal

Fix two input/animation bugs in Outpost Vostok (no model changes):

1. **Auto-fire:** the soldier fired just from holding the mouse to look or moving on
   mobile, because the `fire` action was bound to the left mouse button and
   `emulate_mouse_from_touch=true` turned every touch into a click.
2. **Frozen legs:** downstream of bug 1 — while "firing", the rig froze the
   AnimationPlayer in the ADS pose and the player skipped walk/run, so the soldier slid
   with frozen legs.

Plus a new feature: **blend a lower-body walk/run UNDER the upper-body aim pose** so the
legs keep stepping while shooting on the move, with the arm/weapon IK aim intact.

# Files to touch

- `project.godot` — remove the `InputEventMouseButton` from the `fire` action (keep Space);
  set `input_devices/pointing/emulate_mouse_from_touch=false`.
- `meshy_character_rig.gd` — drive the AnimationMixer in MANUAL mode and `advance()` it in
  `_process` so procedural arm IK runs AFTER the clip poses the skeleton; add a layered
  base/overlay model (`set_locomotion` / `set_aiming` / `_refresh_base`) so a walk/run clip
  plays under the aim IK.
- `scripts/player.gd` — `_update_anim` always feeds the rig the lower-body locomotion state
  (so legs step while moving, including while firing).
- `scripts/hud.gd` — because `emulate_mouse_from_touch=false` stops native Buttons from
  pressing on touch, route menu/game-over taps (DEPLOY / SUBMIT / REDEPLOY / callsign field)
  to the buttons via explicit touch hit-testing so the game stays startable on a phone.
- `README.md` — controls: desktop Fire = Space / FIRE button (not Left Mouse).
- `tests/selftest.gd` — assert the fire binding has no mouse button + emulation off, and that
  legs animate when moving (no fire) and keep stepping while moving + firing (aim intact).
- `tools/gen_textures.py` (new) + `tools/fetch_assets.sh` — the flat texture CDN URLs went
  dead; generate seamless snow/metal textures locally so the build is self-contained.

# Verification approach

- Headless logic self-test (`godot --headless -s tests/selftest.gd`): input bindings, leg
  bone-pose deltas (walk-no-fire and walk-while-firing), aim overlay active, plus the existing
  facing / combat / AI / scoring checks.
- Web `nothreads` export + headless smoke verifier (engine boots, canvas, clean console,
  screenshots) on the software-GL sandbox.
- Deploy the web build to the preview origin for the play link.

# Out of scope

- Character/weapon meshes (explicitly untouched).
- The Supabase leaderboard backend (already exists; unchanged).
- Gameplay tuning (damage, waves, speeds).
