class_name CFG
extends RefCounted
## Static game configuration for Outpost Vostok.

const SUPABASE_URL := "https://xhhmxabftbyxrirvvihn.supabase.co"
const SUPABASE_ANON_KEY := "sb_publishable_NZHoIxqqpSvVBP8MrLHCYA_gmg1AbN-"
const SCORES_TABLE := "usr_nmexs7bytxq2_outpost_vostok_scores"

const ARENA_HALF := 20.0          # arena is 2*ARENA_HALF across
const SPAWN_RADIUS := 18.0
const MAX_ALIVE := 12             # on-screen enemy cap (mobile perf)
const SPAWN_INTERVAL := 0.7

# ── Player (single operative: spec-ops Soldier with a full-auto rifle) ──────────
const PLAYER := {
	"model": "res://models/soldier.glb",
	"weapon": "res://models/rifle.glb",
	"hp": 100.0,
	"speed": 6.6,
	"fire_speed": 1.8,            # movement while planting a burst
	"mag": 30,
	"dmg": 12.0,                  # per round
	"burst": 6,                   # rounds per trigger pull
	"burst_cd": 0.5,             # seconds between bursts
	"round_gap": 0.07,           # seconds between rounds in a burst
	"reload_time": 1.9,
	"range": 46.0,
	"dodge_speed": 17.0,
	"dodge_time": 0.30,
	"dodge_iframe": 0.36,
	"dodge_cd": 1.1,
}

# ── Enemies ───────────────────────────────────────────────────
const ENEMIES := {
	"infected": {
		"model": "res://models/infected.glb",
		"hp": 40.0, "speed": 3.4, "dmg": 9.0, "score": 100,
		"attack_range": 2.0, "attack_cd": 1.3, "scale": 1.0, "ranged": false,
	},
	"alien": {
		"model": "res://models/alien.glb",
		"hp": 30.0, "speed": 5.4, "dmg": 8.0, "score": 150,
		"attack_range": 1.9, "attack_cd": 1.0, "scale": 1.0, "ranged": false,
	},
	"cyber": {
		"model": "res://models/cyber.glb",
		"weapon": "res://models/armcannon.glb",
		"hp": 70.0, "speed": 3.6, "dmg": 7.0, "score": 250,
		"attack_range": 14.0, "attack_cd": 2.4, "scale": 1.0, "ranged": true,
	},
	"reaver": {
		"model": "res://models/reaver.glb",
		"hp": 620.0, "speed": 2.9, "dmg": 30.0, "score": 1500,
		"attack_range": 3.2, "attack_cd": 1.8, "scale": 1.9, "ranged": false,
	},
}

# Reaver brute is the boss on every 5th wave (scaled up afterwards).
static func wave_comp(n: int) -> Array:
	var comp: Array = []
	var cycle: int = (n - 1) / 5            # 0 for waves 1-5, 1 for 6-10, ...
	var infected: int = mini(3 + n, 11)
	var aliens: int = 0 if n < 2 else mini(n - 1, 8)
	var cybers: int = 0 if n < 3 else mini(n - 2, 6)
	for _i in infected:
		comp.append("infected")
	for _i in aliens:
		comp.append("alien")
	for _i in cybers:
		comp.append("cyber")
	if n % 5 == 0:
		comp.append("reaver")
		for _i in cycle:
			comp.append("alien")
	return comp

static func wave_hp_scale(n: int) -> float:
	return 1.0 + 0.12 * float(n - 1)
