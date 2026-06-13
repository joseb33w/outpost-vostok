extends Node3D
## Outpost Vostok — main game orchestrator.

const ARENA_HALF := CFG.ARENA_HALF

var _state := "menu"               # menu | play | intermission | over
var _wave := 0
var _score := 0
var _kills := 0
var _best := 0
var _spawn_queue: Array = []
var _alive: Array[Enemy] = []
var _next_spawn := 0.0

var camera: Camera3D
var _cam_yaw := 0.0
var _cam_pitch := -0.42
var _cam_dist := 7.6
var _cam_height := 5.0
var _shake := 0.0

var player: Player
var hud: Hud
var audio: GameAudio
var board: Leaderboard
var _beacon_light: OmniLight3D
var _submitted := false

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _ready() -> void:
	randomize()
	var w := get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

	audio = GameAudio.new()
	add_child(audio)
	board = Leaderboard.new()
	add_child(board)
	board.top10_loaded.connect(_on_board_loaded)
	board.submit_done.connect(func(_ok: bool) -> void: board.fetch_top10())

	_build_environment()
	camera = Camera3D.new()
	camera.fov = 66.0
	camera.current = true
	add_child(camera)
	camera.global_position = Vector3(0, _cam_height, _cam_dist)
	camera.look_at(Vector3.UP, Vector3.UP)

	hud = Hud.new()
	add_child(hud)
	hud.start_pressed.connect(start_game)
	hud.restart_pressed.connect(start_game)
	hud.reload_pressed.connect(_on_reload)
	hud.dodge_pressed.connect(_on_dodge)
	hud.submit_pressed.connect(_on_submit)

	_best = _load_best()
	hud.show_menu([])
	board.fetch_top10()

# ── game flow ───────────────────────────────────────────────
func start_game() -> void:
	for e in _alive:
		if is_instance_valid(e):
			e.queue_free()
	_alive.clear()
	_spawn_queue.clear()
	if is_instance_valid(player):
		player.queue_free()
	player = Player.new()
	add_child(player)
	player.global_position = Vector3.ZERO
	player.setup(audio, self)
	player.health_changed.connect(func(c: float, m: float) -> void: hud.set_health(c, m))
	player.ammo_changed.connect(func(c: int, m: int) -> void: hud.set_ammo(c, m))
	player.died.connect(_on_player_died)
	_cam_yaw = 0.0
	_score = 0
	_kills = 0
	_wave = 0
	_submitted = false
	hud.set_score(0)
	hud.start_play()
	audio.start()
	_state = "play"
	_next_wave()

func _next_wave() -> void:
	_wave += 1
	_spawn_queue = CFG.wave_comp(_wave)
	_spawn_queue.shuffle()
	hud.set_wave(_wave)
	hud.set_hostiles(_spawn_queue.size())
	var boss := (_wave % 5 == 0)
	hud.show_message("WAVE %d" % _wave, "HOSTILES INBOUND" if not boss else "WARNING: HEAVY UNIT")
	hud.fade_message()
	audio.play("wave_start", -3.0)
	_next_spawn = _now() + 1.4
	_state = "play"

func _wave_cleared() -> void:
	if _state != "play":
		return
	_state = "intermission"
	hud.show_message("WAVE %d CLEARED" % _wave, "resupply...")
	hud.fade_message()
	if is_instance_valid(player) and not player.dead:
		player.hp = minf(player.max_hp, player.hp + 35.0)
		player.health_changed.emit(player.hp, player.max_hp)
		player.ammo = int(CFG.PLAYER["mag"])
		player.ammo_changed.emit(player.ammo, int(CFG.PLAYER["mag"]))
	var tw := create_tween()
	tw.tween_interval(3.6)
	tw.tween_callback(func() -> void:
		if _state == "intermission":
			_next_wave())

func _on_player_died() -> void:
	if _state == "over":
		return
	_state = "over"
	audio.play("hurt", 0.0)
	_best = maxi(_best, _score)
	_save_best(_best)
	hud.show_gameover(_score, _wave, _kills, _best, [])
	board.fetch_top10()

# ── per-frame ──────────────────────────────────────────────
func _process(delta: float) -> void:
	_update_camera(delta)
	if _beacon_light != null:
		_beacon_light.light_energy = 2.2 + sin(_now() * 3.0) * 0.7
	if _state == "play":
		_drive_input()
		_spawn_tick()
	elif is_instance_valid(player) and not player.dead:
		player.move_dir = Vector3.ZERO
		player.want_fire = false

func _drive_input() -> void:
	if not is_instance_valid(player):
		return
	var stick := hud.move_vector
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var kb2 := Vector2(kb.x, -kb.y)
	if kb2.length() > stick.length():
		stick = kb2
	# camera-relative world direction (stick.y up = forward/into screen)
	var b := camera.global_transform.basis
	var fwd := -b.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := b.x
	right.y = 0.0
	right = right.normalized()
	var world := right * stick.x + fwd * stick.y
	player.move_dir = world
	player.want_fire = hud.firing or Input.is_action_pressed("fire")
	if Input.is_action_just_pressed("reload"):
		_on_reload()
	if Input.is_action_just_pressed("dodge"):
		_on_dodge()
	# camera look
	var look := hud.consume_look()
	_cam_yaw -= look.x * 0.006
	_cam_pitch = clampf(_cam_pitch - look.y * 0.004, -0.95, -0.12)

func _on_reload() -> void:
	if is_instance_valid(player):
		player.do_reload()

func _on_dodge() -> void:
	if is_instance_valid(player):
		player.do_dodge()

func _spawn_tick() -> void:
	if _spawn_queue.is_empty():
		if _alive.is_empty():
			_wave_cleared()
		return
	if _alive.size() >= CFG.MAX_ALIVE:
		return
	if _now() < _next_spawn:
		return
	_next_spawn = _now() + CFG.SPAWN_INTERVAL
	var kind: String = _spawn_queue.pop_back()
	_spawn_enemy(kind)

func _spawn_enemy(kind: String) -> void:
	var e := Enemy.new()
	add_child(e)
	var ang := randf() * TAU
	var r := CFG.SPAWN_RADIUS - randf() * 2.0
	e.global_position = Vector3(cos(ang) * r, 0.0, sin(ang) * r)
	e.setup(kind, CFG.wave_hp_scale(_wave), player, audio)
	e.killed.connect(_on_enemy_killed)
	_alive.append(e)
	hud.set_hostiles(_remaining())

func _on_enemy_killed(e: Enemy, score: int) -> void:
	_score += score
	_kills += 1
	_alive.erase(e)
	hud.set_score(_score)
	hud.set_hostiles(_remaining())
	if _state == "play" and _spawn_queue.is_empty() and _alive.is_empty():
		_wave_cleared()

func _remaining() -> int:
	return _alive.size() + _spawn_queue.size()

func on_player_hurt(_amount: float) -> void:
	hud.flash_damage()
	_shake = minf(1.0, _shake + 0.5)

func nearest_enemy(from: Vector3, max_range: float) -> Node:
	var best: Enemy = null
	var bd := max_range * max_range
	for e in _alive:
		if not is_instance_valid(e) or e.dead:
			continue
		var d := e.global_position.distance_squared_to(from)
		if d < bd:
			bd = d
			best = e
	return best

# ── camera ───────────────────────────────────────────────
func _update_camera(delta: float) -> void:
	var focus := Vector3.ZERO
	if is_instance_valid(player):
		focus = player.global_position + Vector3.UP * 1.5
	var offset := Vector3(0, _cam_height, _cam_dist).rotated(Vector3.UP, _cam_yaw)
	offset.y = _cam_dist * -sin(_cam_pitch) + 1.0
	var want := focus + offset
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(focus, want, 1)
	if is_instance_valid(player):
		q.exclude = [player]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		want = hit["position"] + (focus - want).normalized() * 0.4
	_shake = move_toward(_shake, 0.0, delta * 3.0)
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.35
	camera.global_position = camera.global_position.lerp(want, 1.0 - exp(-delta * 13.0)) + shake
	camera.look_at(focus, Vector3.UP)

# ── environment ───────────────────────────────────────────
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://skies/sb_cloudy_4.png")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 1.0
	env.background_energy_multiplier = 0.42
	env.fog_enabled = true
	env.fog_light_color = Color(0.58, 0.67, 0.82)
	env.fog_density = 0.045
	env.fog_sky_affect = 0.7
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, 38, 0)
	sun.light_color = Color(0.82, 0.89, 1.0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -150, 0)
	fill.light_color = Color(0.55, 0.65, 0.85)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	add_child(fill)

	_build_ground()
	_build_perimeter()
	_build_cover()
	_build_beacon()
	_build_floodlights()
	_build_snow()

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.64, 0.71, 0.83)
	mat.albedo_texture = load("res://textures/snow.png")
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
	mat.roughness = 0.92
	mat.metallic = 0.0
	mi.set_surface_override_material(0, mat)
	ground.add_child(mi)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 0.4, 120)
	col.shape = box
	col.position = Vector3(0, -0.2, 0)
	ground.add_child(col)

	# central metal landing pad
	var pad := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 7.5
	cyl.bottom_radius = 7.5
	cyl.height = 0.16
	pad.mesh = cyl
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.30, 0.34, 0.40)
	pm.albedo_texture = load("res://textures/metal_panel.png")
	pm.uv1_triplanar = true
	pm.uv1_scale = Vector3(0.2, 0.2, 0.2)
	pm.metallic = 0.7
	pm.roughness = 0.45
	pad.set_surface_override_material(0, pm)
	pad.position = Vector3(0, 0.08, 0)
	add_child(pad)
	# emissive ring around pad
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 7.3
	tor.outer_radius = 7.7
	ring.mesh = tor
	ring.set_surface_override_material(0, _emissive(Color(0.2, 0.8, 1.0), 3.5))
	ring.position = Vector3(0, 0.14, 0)
	add_child(ring)

func _build_perimeter() -> void:
	var segs := 16
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.22, 0.25, 0.30)
	wmat.albedo_texture = load("res://textures/metal_panel.png")
	wmat.uv1_triplanar = true
	wmat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	wmat.metallic = 0.6
	wmat.roughness = 0.5
	var strip := _emissive(Color(0.9, 0.25, 0.2), 2.4)
	for i in segs:
		var a := TAU * float(i) / float(segs)
		var pos := Vector3(cos(a) * ARENA_HALF, 0, sin(a) * ARENA_HALF)
		var seg := StaticBody3D.new()
		seg.collision_layer = 1
		seg.collision_mask = 0
		add_child(seg)
		seg.global_position = pos
		seg.rotation.y = -a
		var seg_len := ARENA_HALF * TAU / float(segs) + 0.4
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(seg_len, 2.6, 0.5)
		mi.mesh = bm
		mi.set_surface_override_material(0, wmat)
		mi.position = Vector3(0, 1.3, 0)
		seg.add_child(mi)
		var top := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(seg_len, 0.12, 0.56)
		top.mesh = tb
		top.set_surface_override_material(0, strip)
		top.position = Vector3(0, 2.62, 0)
		seg.add_child(top)
		var col := CollisionShape3D.new()
		var cs := BoxShape3D.new()
		cs.size = Vector3(seg_len, 2.6, 0.5)
		col.shape = cs
		col.position = Vector3(0, 1.3, 0)
		seg.add_child(col)

func _build_cover() -> void:
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.33, 0.37, 0.42)
	cmat.albedo_texture = load("res://textures/metal_panel.png")
	cmat.uv1_triplanar = true
	cmat.uv1_scale = Vector3(0.4, 0.4, 0.4)
	cmat.metallic = 0.5
	cmat.roughness = 0.55
	var rng := RandomNumberGenerator.new()
	rng.seed = 9921
	var count := 9
	for i in count:
		var a := TAU * float(i) / float(count) + rng.randf_range(-0.3, 0.3)
		var rad := rng.randf_range(8.0, 14.5)
		var pos := Vector3(cos(a) * rad, 0, sin(a) * rad)
		var sz := Vector3(rng.randf_range(1.4, 2.6), rng.randf_range(1.0, 2.0), rng.randf_range(1.4, 2.6))
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
		body.global_position = pos
		body.rotation.y = rng.randf_range(0, TAU)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.set_surface_override_material(0, cmat)
		mi.position = Vector3(0, sz.y * 0.5, 0)
		body.add_child(mi)
		# emissive accent strip on top edge
		var acc := MeshInstance3D.new()
		var ab := BoxMesh.new()
		ab.size = Vector3(sz.x * 0.9, 0.08, 0.12)
		acc.mesh = ab
		acc.set_surface_override_material(0, _emissive(Color(0.25, 0.85, 1.0), 2.2))
		acc.position = Vector3(0, sz.y + 0.02, sz.z * 0.5 - 0.1)
		body.add_child(acc)
		var col := CollisionShape3D.new()
		var cs := BoxShape3D.new()
		cs.size = sz
		col.shape = cs
		col.position = Vector3(0, sz.y * 0.5, 0)
		body.add_child(col)

func _build_beacon() -> void:
	# off-centre so it reads as a landmark, never blocking the player at spawn
	var bp := Vector3(-9.0, 0, -12.5)
	var mast := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.35
	cyl.height = 7.5
	mast.mesh = cyl
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.2, 0.23, 0.27)
	mm.metallic = 0.8
	mm.roughness = 0.4
	mast.set_surface_override_material(0, mm)
	mast.position = bp + Vector3(0, 3.75, 0)
	add_child(mast)
	var orb := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	orb.mesh = sph
	orb.set_surface_override_material(0, _emissive(Color(0.3, 0.85, 1.0), 5.0))
	orb.position = bp + Vector3(0, 7.7, 0)
	add_child(orb)
	_beacon_light = OmniLight3D.new()
	_beacon_light.light_color = Color(0.4, 0.85, 1.0)
	_beacon_light.light_energy = 2.4
	_beacon_light.omni_range = 24.0
	_beacon_light.position = bp + Vector3(0, 7.7, 0)
	add_child(_beacon_light)

func _build_floodlights() -> void:
	var n := 4
	for i in n:
		var a := TAU * float(i) / float(n) + PI / 4.0
		var pos := Vector3(cos(a) * (ARENA_HALF - 1.5), 0, sin(a) * (ARENA_HALF - 1.5))
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.12
		cyl.bottom_radius = 0.16
		cyl.height = 5.0
		pole.mesh = cyl
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.18, 0.2, 0.24)
		pm.metallic = 0.7
		pm.roughness = 0.5
		pole.set_surface_override_material(0, pm)
		pole.position = pos + Vector3(0, 2.5, 0)
		add_child(pole)
		var head := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.7, 0.4, 0.4)
		head.mesh = bm
		head.set_surface_override_material(0, _emissive(Color(1.0, 0.95, 0.8), 3.0))
		add_child(head)
		head.global_position = pos + Vector3(0, 5.0, 0)
		head.look_at(Vector3(0, 1.5, 0), Vector3.UP)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(0.95, 0.95, 0.85)
		lamp.light_energy = 1.6
		lamp.omni_range = 18.0
		lamp.position = pos + Vector3(0, 5.0, 0)
		add_child(lamp)

func _build_snow() -> void:
	var p := CPUParticles3D.new()
	p.amount = 240
	p.lifetime = 7.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(ARENA_HALF, 1, ARENA_HALF)
	p.direction = Vector3(0.3, -1, 0.2)
	p.gravity = Vector3(0.4, -1.6, 0.3)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.09
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 5
	sph.rings = 3
	p.mesh = sph
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sph.material = m
	p.position = Vector3(0, 9, 0)
	add_child(p)

func _emissive(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m

# ── leaderboard + best ───────────────────────────────────────
func _on_board_loaded(rows: Array) -> void:
	hud.update_board(rows)

func _on_submit(initials: String) -> void:
	if _submitted:
		return
	_submitted = true
	board.submit_score(initials, _score, _wave)

func _load_best() -> int:
	if OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("parseInt(window.localStorage.getItem('ov_best')||'0',10)", true)
		return int(v) if v != null else 0
	var f := FileAccess.open("user://best.save", FileAccess.READ)
	if f != null:
		return f.get_32()
	return 0

func _save_best(v: int) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.localStorage.setItem('ov_best','%d')" % v, true)
		return
	var f := FileAccess.open("user://best.save", FileAccess.WRITE)
	if f != null:
		f.store_32(v)
