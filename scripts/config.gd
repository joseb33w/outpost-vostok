class_name CFG
extends RefCounted

const SUPABASE_URL := "https://xhhmxabftbyxrirvvihn.supabase.co"
const SUPABASE_ANON_KEY := "sb_publishable_NZHoIxqqpSvVBP8MrLHCYA_gmg1AbN-"
const SCORES_TABLE := "usr_nmexs7bytxq2_outpost_vostok_scores"
const NPC_URL := "https://npc.myapping.com/chat"

const ARENA_HALF := 27.0

const CLASSES := {
	"soldier": {
		"label": "SOLDIER",
		"model": "res://models/soldier.glb",
		"weapon": "res://models/rifle.glb",
		"cfg": "RIFLE",
		"hp": 100, "speed": 6.0,
		"mag": 30, "reserve": 150,
		"dmg": 14, "rate": 0.13, "rng": 45.0,
		"sfx": "shot_rifle",
		"desc": "Spec-ops rifleman.\nBalanced speed + armor.\nFull-auto rifle.",
	},
	"vanguard": {
		"label": "VANGUARD",
		"model": "res://models/vanguard.glb",
		"weapon": "res://models/pistol.glb",
		"cfg": "PISTOL",
		"hp": 170, "speed": 4.6,
		"mag": 12, "reserve": 72,
		"dmg": 34, "rate": 0.38, "rng": 35.0,
		"sfx": "shot_pistol",
		"desc": "Heavy assault trooper.\nThick armor, slower.\nHard-hitting pistol.",
	},
	"specter": {
		"label": "SPECTER",
		"model": "res://models/specter.glb",
		"weapon": "res://models/plasma.glb",
		"cfg": "PLASMA",
		"hp": 75, "speed": 7.4,
		"mag": 20, "reserve": 120,
		"dmg": 19, "rate": 0.17, "rng": 42.0,
		"sfx": "shot_plasma",
		"desc": "Stealth operative.\nFast but fragile.\nPlasma rifle.",
	},
}

const ENEMIES := {
	"infected": {
		"model": "res://models/infected.glb",
		"hp": 42.0, "speed": 3.4, "dmg": 10.0, "score": 100,
		"attack_range": 1.9, "attack_cd": 1.3, "scale": 1.0, "ranged": false,
	},
	"alien": {
		"model": "res://models/alien.glb",
		"hp": 32.0, "speed": 5.2, "dmg": 8.0, "score": 150,
		"attack_range": 1.8, "attack_cd": 1.0, "scale": 1.0, "ranged": false,
	},
	"cyber": {
		"model": "res://models/cyber.glb",
		"weapon": "res://models/armcannon.glb",
		"cfg": "ARMCANNON",
		"hp": 72.0, "speed": 3.8, "dmg": 7.0, "score": 250,
		"attack_range": 13.0, "attack_cd": 2.6, "scale": 1.0, "ranged": true,
	},
	"reaver": {
		"model": "res://models/reaver.glb",
		"hp": 680.0, "speed": 2.8, "dmg": 32.0, "score": 1500,
		"attack_range": 3.0, "attack_cd": 1.8, "scale": 2.0, "ranged": false,
	},
}

const QM_PERSONA := "You are Sergeant Dmitri 'Volkov' Karev, the armored quartermaster of Outpost Vostok, a grim industrial station under siege at dusk. You stand by the armory in heavy guardian plate, no gun, between enemy waves. Speak tersely, gruff military tone, dry dark humor, stay in character always. You know: enemies come in waves; infected troopers and alien stalkers rush in with claws and melee early on; from wave 4 cyberpunk enforcers appear and SHOOT back - tell the operative to crouch (crouching halves ranged damage) and keep moving; wave 8 brings a huge mutant brute, the Reaver - dodge its swings, never let it corner you. Three operatives can deploy between waves: SOLDIER (balanced, full-auto rifle), VANGUARD (heavy armor, slow, hard-hitting pistol), SPECTER (fast, fragile, plasma rifle). The dodge roll gives a brief moment of invulnerability. Reloading takes about two seconds - do it between fights, never mid-charge. Ammo and health resupply automatically at the armory between waves. Replies under 50 words. ASCII only, no emoji."

static func wave_comp(n: int) -> Array:
	var comp: Array = []
	if n % 8 == 0:
		comp.append("reaver")
		comp.append("infected")
		comp.append("infected")
		if n > 8:
			comp.append("alien")
			comp.append("cyber")
		return comp
	var cycle := (n - 1) / 8
	var k := ((n - 1) % 8) + 1
	for _i in mini(2 + k, 8) + cycle:
		comp.append("infected")
	if k >= 2:
		for _i in mini(k - 1, 6) + cycle:
			comp.append("alien")
	if k >= 4:
		for _i in mini(k - 3, 4) + cycle:
			comp.append("cyber")
	return comp

static func wave_hp_scale(n: int) -> float:
	return 1.0 + 0.45 * float((n - 1) / 8)
