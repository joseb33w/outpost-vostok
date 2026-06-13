# Outpost Vostok

Wave-survival sci-fi shooter with a realistic military look, built in **Godot 4.6.3** and exported to the web (single-threaded `nothreads` build, Compatibility/WebGL2 renderer — runs in Safari, Chrome and Firefox on phone and desktop).

## Gameplay

- Third-person spec-ops combat on a grim industrial station exterior at dusk (HDRI sunset sky, fog, moody lighting).
- **Three operatives**, switchable between waves:
  - **Soldier** — balanced, full-auto rifle
  - **Vanguard** — heavy armored trooper, slow, hard-hitting pistol
  - **Specter** — fast, fragile stealth ninja with a plasma rifle
- Aim-down-sights, recoil + muzzle flash + tracers, limited ammo with an animated magazine reload, crouch (halves ranged damage taken) and a dodge roll with brief invulnerability.
- **Waves**: infected troopers and alien stalkers rush in melee early on; cyberpunk enforcers with arm cannons shoot back from wave 4; a huge mutant brute — the **Reaver** — is the wave-8 boss (and returns scaled-up every 8th wave).
- **Quartermaster**: Sgt. Volkov, an armored knight-like guardian by the armory. Walk up between waves and actually talk to him — he answers in character with tips about the station (LLM-powered via the shared NPC endpoint).
- HUD: health, ammo, wave, score, hostiles counter.
- On death your score goes to an **online top-10 leaderboard** (initials + score + wave), persisted in Supabase and shown on the start screen.

## Controls

| Action | Desktop | Phone |
|---|---|---|
| Move | WASD / arrows | left virtual stick |
| Look | mouse (click to capture) | drag right side of screen |
| Fire | left mouse button | FIRE button |
| Aim down sights | right mouse button (hold) | AIM toggle |
| Reload | R | RELOAD button |
| Crouch | C | CROUCH toggle |
| Dodge roll | Space | DODGE button |
| Talk to quartermaster | E (near armory, between waves) | TALK button |
| Start next wave | N | NEXT WAVE button |

## Stack

- Godot 4.6.3, GL Compatibility renderer, web `nothreads` export (no COOP/COEP needed).
- Characters/weapons: Meshy realistic roster (CC0) driven by the `MeshyCharacterRig` component (ADS, IK weapon grip, recoil, animated reload).
- Backend: Supabase (PostgREST REST called from GDScript `HTTPRequest` with the public anon key — no SDK needed). Leaderboard table `usr_nmexs7bytxq2_outpost_vostok_scores` with RLS: public SELECT/INSERT only, constraint-checked initials/score, no UPDATE/DELETE.
- NPC chat: `POST https://npc.myapping.com/chat` (shared hosted NPC brain).

## Develop / export

Binary assets (models, sky, texture, generated SFX) are not committed — fetch them first:

```sh
bash tools/fetch_assets.sh   # downloads CC0 .glb/.hdr/.png + generates SFX wavs
godot --headless --path . --import
godot --headless --path . --export-release "Web" out/index.html
```

Serve `out/` from any static host (no special headers required).

## Credits

Character/weapon models, sky and textures: CC0 assets from the MyApping Godot asset library (Meshy realistic roster, Poly Haven sky). All sounds generated procedurally.
