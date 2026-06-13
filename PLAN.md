# Goal

Build "Outpost Vostok" — a wave-survival sci-fi shooter with a realistic military look, as a Godot 4.6.3 web (nothreads, Compatibility) game:

- Third-person spec-ops soldier with rifle: ADS, recoil + muzzle flash, limited ammo + animated reload, crouch, dodge roll.
- Character switching between waves: Soldier (rifle), Vanguard (heavy, pistol), Specter (ninja, plasma).
- Waves: infected troopers + alien stalkers (melee) early; cyber enforcers (ranged) from wave 4; Reaver mutant brute boss at wave 8 (recurring every 8th wave, scaled).
- Quartermaster: warden (knight-like guardian, no gun) by the armory; LLM chat via npc.myapping.com between waves.
- Grim industrial station exterior at dusk: HDRI sunset sky, fog, warm low sun, emissive props.
- HUD: health, ammo, wave, score. Death -> initials entry -> online top-10 leaderboard (Supabase, public read/insert RLS table `usr_nmexs7bytxq2_outpost_vostok_scores`).
- Keyboard+mouse AND touch controls (virtual stick, drag-look, on-screen buttons), safe-area aware.

# Files to touch

- `project.godot`, `export_presets.cfg`, `main.tscn` — engine config (gl_compatibility, canvas_items/expand stretch, etc2_astc, nothreads Web preset).
- `meshy_character_rig.gd` — vendored rig component (drives realistic characters + weapons).
- `scripts/config.gd` — class/enemy/wave definitions, Supabase + NPC endpoints, persona.
- `scripts/main.gd` — world build (environment, arena, props, quartermaster), wave manager, game states.
- `scripts/player.gd` — movement, camera, fire/ADS/reload/crouch/dodge, aim assist, damage.
- `scripts/enemy.gd` — melee + ranged AI, hit feedback (flash + particles), death.
- `scripts/hud.gd` — HUD, touch controls, menu/intermission/game-over panels, chat UI, leaderboard UI.
- `scripts/leaderboard.gd`, `scripts/audio.gd` — Supabase REST client, procedural SFX playback.
- `shaders/hdri_sky.gdshader` — HDR panorama sky (web brightness fix).
- `models/*.glb`, `models/*.hdr`, `models/metal_panel.png`, `audio/*.wav` — assets.
- `tests/` — headless gameplay checks (excluded from export).

# Verification approach

- Static pre-import grep (Variant inference, member shadowing), headless `--import` + `--export-release`.
- Headless gameplay test script: clip resolution for every referenced animation, combat hp-delta through the real fire path with feedback nodes asserted, enemy AI engages (distance decreases, player hp drops), facing convention, trigger/talk radius, wave composition.
- Browser smoke verify (vetted verify.mjs): boot, clean console, frames at portrait + landscape; drive W/S and check facing; critique frames vs art direction.
- Supabase: real REST positive (anon select/insert) + negative (bad initials, delete) tests; cleanup of test rows via service role.
- Deploy `out/` to R2 preview; PR to main with merge.

# Out of scope

- Multiplayer (single-player game; leaderboard is the only shared state).
- Account-based auth (arcade-style initials leaderboard is public read/insert by design).
- Custom soundtrack (procedural SFX + ambient wind only).
