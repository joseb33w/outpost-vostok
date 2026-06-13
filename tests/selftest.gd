extends SceneTree
## Headless logic self-test (no GPU): input bindings, facing, combat delta + juice,
## enemy AI, clip resolution, leg animation + lower-body blend.
## Run: godot --headless -s tests/selftest.gd

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

	# ── INPUT BINDING: fire is Space / FIRE button only, no left-mouse auto-fire ──
	var fire_evts = InputMap.action_get_events("fire")
	var has_mouse = false
	var has_space = false
	for ev in fire_evts:
		if ev is InputEventMouseButton:
			has_mouse = true
		elif ev is InputEventKey and ev.physical_keycode == KEY_SPACE:
			has_space = true
	ok("fire action has NO mouse button (look/drag can't auto-fire)", not has_mouse)
	ok("fire action keeps Space", has_space)
	ok("emulate_mouse_from_touch is OFF (touch can't auto-fire)",
		ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true) == false)

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

	# ── LEGS animate (the downstream-of-auto-fire bug) ──
	# clear leftover foes + heal so nothing interrupts the locomotion checks
	for e in main.get("_alive"):
		if is_instance_valid(e):
			e.queue_free()
	main.get("_alive").clear()
	player.dead = false
	player.hp = player.max_hp
	var skel = player.rig.current_skel
	ok("player skeleton present", skel != null)

	# (c) moving WITHOUT firing plays walk/run -> legs animate
	player.want_fire = false
	player.move_dir = Vector3(0, 0, 1)
	await create_timer(0.45).timeout
	var legs_a = _leg_pose(skel)
	await create_timer(0.30).timeout
	var legs_b = _leg_pose(skel)
	var d_walk = _pose_delta(legs_a, legs_b)
	ok("legs animate walking, no fire (delta=%.3f)" % d_walk, d_walk > 0.02)
	ok("walk/run clip active, not frozen", not player.rig._frozen)

	# (blend) legs keep stepping while shooting on the move + aim overlay stays on
	var foe3 = Enemy.new()
	main.add_child(foe3)
	foe3.global_position = Vector3(0, 0, 9)
	foe3.setup("infected", 1.0, player, main.get("audio"))
	main.get("_alive").append(foe3)
	player.move_dir = Vector3(1, 0, 0)   # strafe so the body keeps moving
	player.want_fire = true
	await create_timer(0.45).timeout
	var blend_a = _leg_pose(skel)
	await create_timer(0.30).timeout
	var blend_b = _leg_pose(skel)
	var d_blend = _pose_delta(blend_a, blend_b)
	ok("legs step while shooting on the move (delta=%.3f)" % d_blend, d_blend > 0.02)
	ok("aim overlay active while moving+firing", player.rig.aiming == true)
	player.want_fire = false
	player.move_dir = Vector3.ZERO

	print("SELFTEST_DONE fails=%d" % _fails)
	quit(_fails)

func _find_bone(skel, want: String) -> int:
	for b in skel.get_bone_count():
		if skel.get_bone_name(b).findn(want) != -1:
			return b
	return -1

func _leg_pose(skel) -> Array:
	var out: Array = []
	for n in ["RightUpLeg", "LeftUpLeg", "RightLeg", "LeftLeg", "RightFoot", "LeftFoot"]:
		var b = _find_bone(skel, n)
		if b >= 0:
			out.append(skel.get_bone_pose_rotation(b))
	return out

func _pose_delta(a: Array, b: Array) -> float:
	var m = 0.0
	for i in range(min(a.size(), b.size())):
		m = maxf(m, a[i].angle_to(b[i]))
	return m
