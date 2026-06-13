extends SceneTree
## Headless logic self-test (no GPU): facing, combat delta + juice, enemy AI,
## clip resolution. Run: godot --headless -s tests/selftest.gd

var main: Node
var _fails := 0

func ok(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		_fails += 1

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	_run()

func _run() -> void:
	await create_timer(0.3).timeout
	main.call("start_game")
	await create_timer(0.6).timeout
	var player = main.get("player")
	ok("player spawned", player != null)
	ok("player has rig + anim", player != null and player.rig != null and player.rig.current_anim != null)

	# clip resolution
	if player != null and player.rig != null and player.rig.current_anim != null:
		var ap = player.rig.current_anim
		for clip in ["idle", "walk", "run", "fire", "reload", "dodge", "death"]:
			ok("player clip '%s'" % clip, ap.has_animation(clip))

	# freeze main input so we control the player directly
	main.set_process(false)

	# ── FACING (catch +Z moonwalk) ──
	player.want_fire = false
	player.move_dir = Vector3(0, 0, -1)   # forward = away from +Z camera -> expect back (yaw ~ PI)
	await create_timer(0.6).timeout
	var yaw_back = wrapf(player.rig.rotation.y, -PI, PI)
	player.move_dir = Vector3(0, 0, 1)    # toward camera -> expect face (yaw ~ 0)
	await create_timer(0.6).timeout
	var yaw_face = wrapf(player.rig.rotation.y, -PI, PI)
	ok("facing: W shows back (|yaw|~PI=%.2f)" % yaw_back, absf(absf(yaw_back) - PI) < 0.5)
	ok("facing: S shows face (yaw~0=%.2f)" % yaw_face, absf(yaw_face) < 0.5)

	# ── ENEMY AI: chase + deal damage ──
	player.move_dir = Vector3.ZERO
	var Enemy = load("res://scripts/enemy.gd")
	var foe = Enemy.new()
	main.add_child(foe)
	foe.global_position = Vector3(0, 0, 12)
	foe.setup("infected", 1.0, player, main.get("audio"))
	main.get("_alive").append(foe)
	var d0 = foe.global_position.distance_to(player.global_position)
	await create_timer(1.2).timeout
	var d1 = foe.global_position.distance_to(player.global_position)
	ok("enemy chases (%.1f -> %.1f)" % [d0, d1], d1 < d0 - 1.0)
	var hp0_player = player.hp
	# let it reach melee + attack
	var t = 0.0
	while t < 6.0 and player.hp >= hp0_player and not foe.dead:
		await create_timer(0.3).timeout
		t += 0.3
	ok("enemy melee reduces player HP (%.0f -> %.0f)" % [hp0_player, player.hp], player.hp < hp0_player)

	# ── COMBAT: real fire path drops enemy HP + spawns juice ──
	var foe2 = Enemy.new()
	main.add_child(foe2)
	foe2.global_position = Vector3(0, 0, 6)
	foe2.setup("infected", 1.0, player, main.get("audio"))
	foe2.killed.connect(main._on_enemy_killed)
	main.get("_alive").append(foe2)
	player.move_dir = Vector3.ZERO
	player.want_fire = true
	var ehp0 = foe2.hp
	await create_timer(0.7).timeout
	var ehp1 = foe2.hp
	ok("fire drops enemy HP (%.0f -> %.0f)" % [ehp0, ehp1], ehp1 < ehp0)
	var fx = foe2.find_children("*", "CPUParticles3D", true, false)
	ok("impact particles spawn (juice)", fx.size() > 0)
	# keep firing until dead
	var t2 = 0.0
	while t2 < 4.0 and not foe2.dead:
		await create_timer(0.3).timeout
		t2 += 0.3
	ok("sustained fire kills enemy", foe2.dead)
	player.want_fire = false

	# ── score wired ──
	ok("score increased on kill", int(main.get("_score")) > 0)

	print("SELFTEST_DONE fails=%d" % _fails)
	quit(_fails)
