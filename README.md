# Outpost Vostok

A **wave-survival sci-fi shooter** built in **Godot 4.6.3** and exported to the web as a single-threaded
`nothreads` build on the **Compatibility (WebGL2)** renderer — it runs in Safari, Chrome and Firefox on
both phone and desktop, no special COOP/COEP headers required.

You are a lone spec-ops operative holding a frozen research outpost against escalating waves of hostiles.
Third-person, auto-aim gunplay tuned for touch first.

## Gameplay

- Defend the central landing pad on a snow-blasted station under a cold blue sky.
- **Auto-aim rifle:** hold FIRE to lock the nearest hostile and loose recoiling bursts (muzzle flash +
  tracers via the rig). Line-of-sight matters — crates and walls block shots.
- **Dodge roll** with brief invulnerability to break away when you get swarmed.
- **30-round magazine** with an animated reload (auto-reloads when dry; tap RELOAD to top up early).
- **Enemies:**
  - *Infected* — basic melee rusher.
  - *Stalker* (alien) — fast, fragile melee.
  - *Enforcer* (cyber) — ranged arm-cannon, appears from wave 3.
  - *Reaver* — a huge mutant brute boss on every 5th wave (and it gets tougher each cycle).
- Survive a wave to auto-resupply (armor + ammo) before the next one. Difficulty and hostile counts scale
  every wave; on-screen hostile count is capped so it stays smooth on a phone.
- **Online leaderboard:** on death, log a 3-letter callsign to a global top-10 (score + wave). Your personal
  best is also kept locally and shown on the start screen.

## Controls

| Action | Desktop | Phone |
|---|---|---|
| Move | WASD / arrows | left virtual stick (floating) |
| Fire | Space (hold) / FIRE button | FIRE button (hold) |
| Reload | R | RLD button |
| Dodge roll | Shift | DASH button |
| Orbit camera | drag right side (mouse) | drag right side of screen |

> Firing is **only** Space or the FIRE button — the left mouse button orbits the camera (drag the
> right side of the screen) and never fires, so holding the mouse to look around won't shoot.

Tap **DEPLOY** to start (the first tap also unlocks audio on mobile).

## Stack

- Godot 4.6.3, GL Compatibility renderer, web `nothreads` export.
- Characters/weapons: the **Meshy realistic roster** (CC0) driven by the `MeshyCharacterRig` component
  (aim-down-sights, IK weapon grip, recoil firing with flash + tracer, animated reload).
- Environment is built in code (snow ground, metal landing pad, perimeter wall, cover, beacon, floodlights,
  drifting snow) with PBR materials + an LDR panorama sky + depth fog.
- Backend: **Supabase PostgREST**, called directly from a GDScript `HTTPRequest` with the public anon key
  (no SDK, no bridge). The leaderboard table `usr_nmexs7bytxq2_outpost_vostok_scores` is a genuinely-public
  arcade scoreboard — RLS on, anon `SELECT`/`INSERT` only (no `UPDATE`/`DELETE`), scores immutable.
- Procedurally generated SFX (`tools/gen_audio.py`).

## Develop / export

Binary assets (CC0 models, sky, textures) and the generated SFX are **not** committed — fetch them first:

```sh
bash tools/fetch_assets.sh                 # CC0 .glb/.png + generated SFX wavs (snow/metal textures
                                           # fall back to tools/gen_textures.py if the CDN is down)
godot --headless --path . --import
godot --headless --path . --export-release "Web" out/index.html
# serve out/ from any static host (no special headers needed)
```

Run the headless logic self-test (input bindings, facing, combat, AI, leg animation — no GPU required):

```sh
godot --headless -s tests/selftest.gd
```

## Credits

Character/weapon models, sky and ground textures are CC0 assets from the MyApping Godot asset library
(Meshy realistic roster; Screaming Brain Studios sky; seamless textures). All sound effects are generated
procedurally.
